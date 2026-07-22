part of 'ticket_bloc.dart';

abstract class TicketEvent extends Equatable {
  const TicketEvent();

  @override
  List<Object?> get props => [];
}

class TicketListRequested extends TicketEvent {}

class TicketCreateRequested extends TicketEvent {
  final String subject;
  final String message;
  final int? level;
  final List<String>? images;

  const TicketCreateRequested({
    required this.subject,
    required this.message,
    this.level,
    this.images,
  });

  @override
  List<Object?> get props => [subject, message, level, images];
}

class TicketReplyRequested extends TicketEvent {
  final int ticketId;
  final String message;
  final List<String>? images;

  const TicketReplyRequested({
    required this.ticketId,
    required this.message,
    this.images,
  });

  @override
  List<Object?> get props => [ticketId, message, images];
}

class TicketCloseRequested extends TicketEvent {
  final int ticketId;

  const TicketCloseRequested({required this.ticketId});

  @override
  List<Object> get props => [ticketId];
}

class KnowledgeListRequested extends TicketEvent {}
