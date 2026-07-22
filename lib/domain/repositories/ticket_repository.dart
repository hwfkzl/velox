import '../../data/models/ticket_model.dart';
import '../../data/models/knowledge_model.dart';

abstract class TicketRepository {
  /// 获取工单列表
  Future<List<TicketModel>> getTicketList();

  /// 获取工单详情（包含完整对话记录）
  Future<TicketModel> getTicketDetail(int ticketId);

  /// 创建工单
  Future<void> createTicket({
    required String subject,
    required String message,
    int? level,
    List<String>? images,
  });

  /// 回复工单
  Future<void> replyTicket({
    required int ticketId,
    required String message,
    List<String>? images,
  });

  /// 关闭工单
  Future<void> closeTicket(int ticketId);

  /// 获取知识库列表
  Future<List<KnowledgeModel>> getKnowledgeList();

  /// 上传图片，返回 base64url 编码的图片标识
  Future<String> uploadImage(String base64DataUri, String filename);
}
