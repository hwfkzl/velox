part of 'invite_bloc.dart';

abstract class InviteState extends Equatable {
  const InviteState();

  @override
  List<Object?> get props => [];
}

class InviteInitial extends InviteState {}

class InviteLoading extends InviteState {}

class InviteGenerating extends InviteState {}

class InviteLoaded extends InviteState {
  final InviteModel inviteInfo;

  const InviteLoaded({required this.inviteInfo});

  @override
  List<Object> get props => [inviteInfo];

  String? get inviteCode => inviteInfo.availableCode;

  int get registeredCount => inviteInfo.stat?.registeredCount ?? 0;

  /// 已结算佣金（元）
  double get commissionEarnedYuan =>
      inviteInfo.stat?.commissionEarnedYuan ?? 0;

  /// 待结算佣金（元）
  double get commissionPendingYuan =>
      inviteInfo.stat?.commissionPendingYuan ?? 0;

  /// 当前可用佣金（元）
  double get commissionBalanceYuan =>
      inviteInfo.stat?.commissionBalanceYuan ?? 0;

  /// 佣金比例（%）
  int get commissionRate => inviteInfo.stat?.commissionRate ?? 0;
}

class InviteError extends InviteState {
  final String message;

  const InviteError({required this.message});

  @override
  List<Object> get props => [message];
}
