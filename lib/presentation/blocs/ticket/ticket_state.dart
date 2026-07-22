part of 'ticket_bloc.dart';

abstract class TicketState extends Equatable {
  const TicketState();

  @override
  List<Object?> get props => [];
}

class TicketInitial extends TicketState {}

class TicketLoading extends TicketState {}

class TicketSubmitting extends TicketState {}

class TicketListLoaded extends TicketState {
  final List<TicketModel> tickets;

  const TicketListLoaded({required this.tickets});

  @override
  List<Object> get props => [tickets];

  List<TicketModel> get openTickets =>
      tickets.where((t) => t.isOpen).toList();

  List<TicketModel> get closedTickets =>
      tickets.where((t) => t.isClosed).toList();
}

class TicketCreated extends TicketState {}

class TicketReplied extends TicketState {}

class TicketClosed extends TicketState {}

class KnowledgeListLoaded extends TicketState {
  final List<KnowledgeModel> articles;

  const KnowledgeListLoaded({required this.articles});

  @override
  List<Object> get props => [articles];
}

class TicketError extends TicketState {
  final String message;

  const TicketError({required this.message});

  @override
  List<Object> get props => [message];
}
