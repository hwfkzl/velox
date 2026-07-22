import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/errors/exceptions.dart';
import '../../../data/models/ticket_model.dart';
import '../../../data/models/knowledge_model.dart';
import '../../../domain/repositories/ticket_repository.dart';

part 'ticket_event.dart';
part 'ticket_state.dart';

class TicketBloc extends Bloc<TicketEvent, TicketState> {
  final TicketRepository _ticketRepository;

  TicketBloc({required TicketRepository ticketRepository})
      : _ticketRepository = ticketRepository,
        super(TicketInitial()) {
    on<TicketListRequested>(_onListRequested);
    on<TicketCreateRequested>(_onCreateRequested);
    on<TicketReplyRequested>(_onReplyRequested);
    on<TicketCloseRequested>(_onCloseRequested);
    on<KnowledgeListRequested>(_onKnowledgeListRequested);
  }

  Future<void> _onListRequested(
    TicketListRequested event,
    Emitter<TicketState> emit,
  ) async {
    emit(TicketLoading());
    try {
      final tickets = await _ticketRepository.getTicketList();
      emit(TicketListLoaded(tickets: tickets));
    } catch (e) {
      emit(TicketError(message: extractErrorMessage(e)));
    }
  }

  Future<void> _onCreateRequested(
    TicketCreateRequested event,
    Emitter<TicketState> emit,
  ) async {
    emit(TicketSubmitting());
    try {
      await _ticketRepository.createTicket(
        subject: event.subject,
        message: event.message,
        level: event.level,
        images: event.images,
      );
      emit(TicketCreated());
      // 重新加载列表
      add(TicketListRequested());
    } catch (e) {
      emit(TicketError(message: extractErrorMessage(e)));
    }
  }

  Future<void> _onReplyRequested(
    TicketReplyRequested event,
    Emitter<TicketState> emit,
  ) async {
    emit(TicketSubmitting());
    try {
      await _ticketRepository.replyTicket(
        ticketId: event.ticketId,
        message: event.message,
        images: event.images,
      );
      emit(TicketReplied());
      // 重新加载列表
      add(TicketListRequested());
    } catch (e) {
      emit(TicketError(message: extractErrorMessage(e)));
    }
  }

  Future<void> _onCloseRequested(
    TicketCloseRequested event,
    Emitter<TicketState> emit,
  ) async {
    emit(TicketLoading());
    try {
      await _ticketRepository.closeTicket(event.ticketId);
      emit(TicketClosed());
      // 重新加载列表
      add(TicketListRequested());
    } catch (e) {
      emit(TicketError(message: extractErrorMessage(e)));
    }
  }

  Future<void> _onKnowledgeListRequested(
    KnowledgeListRequested event,
    Emitter<TicketState> emit,
  ) async {
    emit(TicketLoading());
    try {
      final knowledge = await _ticketRepository.getKnowledgeList();
      emit(KnowledgeListLoaded(articles: knowledge));
    } catch (e) {
      emit(TicketError(message: extractErrorMessage(e)));
    }
  }
}
