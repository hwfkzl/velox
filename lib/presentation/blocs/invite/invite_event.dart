part of 'invite_bloc.dart';

abstract class InviteEvent extends Equatable {
  const InviteEvent();

  @override
  List<Object?> get props => [];
}

class InviteLoadRequested extends InviteEvent {}

class InviteGenerateCodeRequested extends InviteEvent {}
