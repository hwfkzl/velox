part of 'subscription_bloc.dart';

abstract class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

/// 请求加载订阅数据
class SubscriptionLoadRequested extends SubscriptionEvent {
  const SubscriptionLoadRequested();
}

/// 请求刷新订阅数据
class SubscriptionRefreshRequested extends SubscriptionEvent {
  const SubscriptionRefreshRequested();
}

/// 计费周期变更
class SubscriptionBillingCycleChanged extends SubscriptionEvent {
  final BillingCycle cycle;

  const SubscriptionBillingCycleChanged(this.cycle);

  @override
  List<Object?> get props => [cycle];
}

/// 套餐选择变更
class SubscriptionPlanSelected extends SubscriptionEvent {
  final PlanModel plan;

  const SubscriptionPlanSelected(this.plan);

  @override
  List<Object?> get props => [plan];
}
