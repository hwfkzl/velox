part of 'subscription_bloc.dart';

/// 订阅状态
enum SubscriptionStatus { initial, loading, loaded, error }

/// 计费周期
enum BillingCycle { monthly, quarterly, halfYearly, yearly, oneTime }

class SubscriptionState extends Equatable {
  final SubscriptionStatus status;
  final List<PlanModel> plans;
  final List<NoticeModel> notices;
  final List<KnowledgeCategoryModel> knowledge;
  final PlanModel? selectedPlan;
  final BillingCycle selectedCycle;
  final String? errorMessage;

  const SubscriptionState({
    this.status = SubscriptionStatus.initial,
    this.plans = const [],
    this.notices = const [],
    this.knowledge = const [],
    this.selectedPlan,
    this.selectedCycle = BillingCycle.monthly,
    this.errorMessage,
  });

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    List<PlanModel>? plans,
    List<NoticeModel>? notices,
    List<KnowledgeCategoryModel>? knowledge,
    PlanModel? selectedPlan,
    BillingCycle? selectedCycle,
    String? errorMessage,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      plans: plans ?? this.plans,
      notices: notices ?? this.notices,
      knowledge: knowledge ?? this.knowledge,
      selectedPlan: selectedPlan ?? this.selectedPlan,
      selectedCycle: selectedCycle ?? this.selectedCycle,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        plans,
        notices,
        knowledge,
        selectedPlan,
        selectedCycle,
        errorMessage,
      ];
}
