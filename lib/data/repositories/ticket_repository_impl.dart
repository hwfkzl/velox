import '../../domain/repositories/ticket_repository.dart';
import '../datasources/remote/ticket_remote_datasource.dart';
import '../models/ticket_model.dart';
import '../models/knowledge_model.dart';

class TicketRepositoryImpl implements TicketRepository {
  final TicketRemoteDataSource _remoteDataSource;

  TicketRepositoryImpl({required TicketRemoteDataSource remoteDataSource})
    : _remoteDataSource = remoteDataSource;

  @override
  Future<List<TicketModel>> getTicketList() async {
    return await _remoteDataSource.getTicketList();
  }

  @override
  Future<TicketModel> getTicketDetail(int ticketId) async {
    return await _remoteDataSource.getTicketDetail(ticketId);
  }

  @override
  Future<void> createTicket({
    required String subject,
    required String message,
    int? level,
    List<String>? images,
  }) async {
    final request = CreateTicketRequest(
      subject: subject,
      message: message,
      level: level,
      images: images,
    );
    await _remoteDataSource.createTicket(request);
  }

  @override
  Future<void> replyTicket({
    required int ticketId,
    required String message,
    List<String>? images,
  }) async {
    final request = ReplyTicketRequest(
      id: ticketId,
      message: message,
      images: images,
    );
    await _remoteDataSource.replyTicket(request);
  }

  @override
  Future<void> closeTicket(int ticketId) async {
    await _remoteDataSource.closeTicket(ticketId);
  }

  @override
  Future<List<KnowledgeModel>> getKnowledgeList() async {
    return await _remoteDataSource.getKnowledgeList();
  }

  @override
  Future<String> uploadImage(String base64DataUri, String filename) async {
    return await _remoteDataSource.uploadImage(base64DataUri, filename);
  }
}
