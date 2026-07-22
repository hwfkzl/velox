import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/errors/exceptions.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/subscribe_model.dart';
import '../../../domain/repositories/user_repository.dart';

part 'user_event.dart';
part 'user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository _userRepository;

  UserBloc({required UserRepository userRepository})
      : _userRepository = userRepository,
        super(UserInitial()) {
    on<UserLoadRequested>(_onLoadRequested);
    on<UserRefreshRequested>(_onRefreshRequested);
    on<UserAuthCleared>((event, emit) => emit(UserInitial()));
  }

  Future<void> _onLoadRequested(
    UserLoadRequested event,
    Emitter<UserState> emit,
  ) async {
    // 先尝试加载缓存
    final cachedUser = _userRepository.getCachedUserInfo();
    final cachedSubscribe = _userRepository.getCachedSubscribeInfo();

    if (cachedUser != null) {
      emit(UserLoaded(user: cachedUser, subscribe: cachedSubscribe));
    } else {
      emit(UserLoading());
    }

    // 从网络加载
    try {
      final user = await _userRepository.getUserInfo();
      final subscribe = await _userRepository.getSubscribeInfo();
      emit(UserLoaded(user: user, subscribe: subscribe));
    } catch (e) {
      if (cachedUser == null) {
        emit(UserError(message: extractErrorMessage(e)));
      }
    }
  }

  Future<void> _onRefreshRequested(
    UserRefreshRequested event,
    Emitter<UserState> emit,
  ) async {
    try {
      final user = await _userRepository.getUserInfo();
      final subscribe = await _userRepository.getSubscribeInfo();
      emit(UserLoaded(user: user, subscribe: subscribe));
    } catch (e) {
      emit(UserError(message: extractErrorMessage(e)));
    }
  }
}
