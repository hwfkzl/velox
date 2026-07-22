import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/errors/exceptions.dart';
import '../../../data/models/invite_model.dart';
import '../../../domain/repositories/invite_repository.dart';

part 'invite_event.dart';
part 'invite_state.dart';

class InviteBloc extends Bloc<InviteEvent, InviteState> {
  final InviteRepository _inviteRepository;

  InviteBloc({required InviteRepository inviteRepository})
      : _inviteRepository = inviteRepository,
        super(InviteInitial()) {
    on<InviteLoadRequested>(_onLoadRequested);
    on<InviteGenerateCodeRequested>(_onGenerateCodeRequested);
  }

  Future<void> _onLoadRequested(
    InviteLoadRequested event,
    Emitter<InviteState> emit,
  ) async {
    emit(InviteLoading());
    try {
      var inviteInfo = await _inviteRepository.getInviteInfo();
      // 如果没有邀请码，自动生成一个
      if (inviteInfo.availableCode == null) {
        await _inviteRepository.generateInviteCode();
        inviteInfo = await _inviteRepository.getInviteInfo();
      }
      emit(InviteLoaded(inviteInfo: inviteInfo));
    } catch (e) {
      emit(InviteError(message: extractErrorMessage(e)));
    }
  }

  Future<void> _onGenerateCodeRequested(
    InviteGenerateCodeRequested event,
    Emitter<InviteState> emit,
  ) async {
    emit(InviteGenerating());
    try {
      await _inviteRepository.generateInviteCode();
      // 重新加载邀请信息
      final inviteInfo = await _inviteRepository.getInviteInfo();
      emit(InviteLoaded(inviteInfo: inviteInfo));
    } catch (e) {
      emit(InviteError(message: extractErrorMessage(e)));
    }
  }
}
