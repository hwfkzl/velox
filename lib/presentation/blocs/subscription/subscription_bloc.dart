import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/errors/exceptions.dart';
import '../../../data/models/subscribe_model.dart';
import '../../../data/models/notice_model.dart';
import '../../../data/models/knowledge_model.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/repositories/ticket_repository.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../di/injection.dart';

part 'subscription_event.dart';
part 'subscription_state.dart';

/// 订阅页面 BLoC
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final UserRepository userRepository;
  final TicketRepository? ticketRepository;

  SubscriptionBloc({
    required this.userRepository,
    this.ticketRepository,
  }) : super(const SubscriptionState()) {
    on<SubscriptionLoadRequested>(_onLoadRequested);
    on<SubscriptionRefreshRequested>(_onRefreshRequested);
    on<SubscriptionBillingCycleChanged>(_onBillingCycleChanged);
    on<SubscriptionPlanSelected>(_onPlanSelected);
  }

  Future<void> _onLoadRequested(
    SubscriptionLoadRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(state.copyWith(status: SubscriptionStatus.loading));

    try {
      // 并行加载数据
      final results = await Future.wait([
        userRepository.getPlanList(),
        _loadNotices(),
        _loadKnowledge(),
      ]);

      final plans = results[0] as List<PlanModel>;
      final notices = results[1] as List<NoticeModel>;
      final knowledge = results[2] as List<KnowledgeCategoryModel>;

      emit(state.copyWith(
        status: SubscriptionStatus.loaded,
        plans: plans,
        notices: notices,
        knowledge: knowledge,
        selectedPlan: plans.isNotEmpty ? plans.first : null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SubscriptionStatus.error,
        errorMessage: extractErrorMessage(e),
      ));
    }
  }

  Future<void> _onRefreshRequested(
    SubscriptionRefreshRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    // 保持当前数据，只刷新
    try {
      final results = await Future.wait([
        userRepository.getPlanList(),
        _loadNotices(),
        _loadKnowledge(),
      ]);

      final plans = results[0] as List<PlanModel>;
      final notices = results[1] as List<NoticeModel>;
      final knowledge = results[2] as List<KnowledgeCategoryModel>;

      // 保持选中的套餐
      PlanModel? selectedPlan = state.selectedPlan;
      if (selectedPlan != null) {
        selectedPlan = plans.where((p) => p.id == selectedPlan?.id).firstOrNull;
      }
      selectedPlan ??= plans.isNotEmpty ? plans.first : null;

      emit(state.copyWith(
        status: SubscriptionStatus.loaded,
        plans: plans,
        notices: notices,
        knowledge: knowledge,
        selectedPlan: selectedPlan,
      ));
    } catch (e) {
      // 刷新失败不改变状态
    }
  }

  void _onBillingCycleChanged(
    SubscriptionBillingCycleChanged event,
    Emitter<SubscriptionState> emit,
  ) {
    emit(state.copyWith(selectedCycle: event.cycle));
  }

  void _onPlanSelected(
    SubscriptionPlanSelected event,
    Emitter<SubscriptionState> emit,
  ) {
    emit(state.copyWith(selectedPlan: event.plan));
  }

  /// 加载公告
  Future<List<NoticeModel>> _loadNotices() async {
    try {
      final apiClient = getIt<ApiClient>();
      final response = await apiClient.get(ApiConstants.noticeList);

      if (response.data['data'] != null) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => NoticeModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 加载帮助中心
  Future<List<KnowledgeCategoryModel>> _loadKnowledge() async {
    try {
      if (ticketRepository != null) {
        final articles = await ticketRepository!.getKnowledgeList();
        // 将文章按分类分组
        final Map<String, List<KnowledgeModel>> grouped = {};
        for (final article in articles) {
          final category = article.category ?? 'General';
          grouped.putIfAbsent(category, () => []);
          grouped[category]!.add(article);
        }
        return grouped.entries
            .map((e) => KnowledgeCategoryModel(category: e.key, articles: e.value))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 获取选中套餐的价格 (分为单位)
  int? getSelectedPrice() {
    final plan = state.selectedPlan;
    if (plan == null) return null;

    switch (state.selectedCycle) {
      case BillingCycle.monthly:
        return plan.monthPrice;
      case BillingCycle.quarterly:
        return plan.quarterPrice;
      case BillingCycle.halfYearly:
        return plan.halfYearPrice;
      case BillingCycle.yearly:
        return plan.yearPrice;
      case BillingCycle.oneTime:
        return plan.onetimePrice;
    }
  }
}
