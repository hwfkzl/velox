part of 'user_bloc.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

class UserLoadRequested extends UserEvent {}

class UserRefreshRequested extends UserEvent {}

/// 退出账号时清理 BLoC 状态，回到初始态。
/// 避免账号 A 的缓存 user/subscribe 留到账号 B 的 UI 里。
class UserAuthCleared extends UserEvent {}
