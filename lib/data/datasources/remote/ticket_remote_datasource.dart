import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/error_message_mapper.dart';
import '../../models/ticket_model.dart';
import '../../models/knowledge_model.dart';

abstract class TicketRemoteDataSource {
  /// 获取工单列表
  Future<List<TicketModel>> getTicketList();

  /// 获取工单详情（包含完整对话）
  Future<TicketModel> getTicketDetail(int ticketId);

  /// 创建工单
  Future<void> createTicket(CreateTicketRequest request);

  /// 回复工单
  Future<void> replyTicket(ReplyTicketRequest request);

  /// 关闭工单
  Future<void> closeTicket(int ticketId);

  /// 获取知识库列表
  Future<List<KnowledgeModel>> getKnowledgeList();

  /// 上传图片，返回 base64url 编码的图片标识
  Future<String> uploadImage(String base64DataUri, String filename);
}

class TicketRemoteDataSourceImpl implements TicketRemoteDataSource {
  final ApiClient _apiClient;

  TicketRemoteDataSourceImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<List<TicketModel>> getTicketList() async {
    final response = await _apiClient.get(ApiConstants.ticketList);

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) {
        if (json is List) {
          return json
              .map((e) => TicketModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return <TicketModel>[];
      },
    );

    if (!apiResponse.isSuccess) {
      throw Exception(
        ErrorMessageMapper.map(apiResponse.message ?? 'Failed to get tickets'),
      );
    }

    return apiResponse.data ?? [];
  }

  @override
  Future<TicketModel> getTicketDetail(int ticketId) async {
    final response = await _apiClient.get(
      ApiConstants.ticketDetail,
      queryParameters: {'id': ticketId},
    );

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) => _parseTicketDetail(json, ticketId),
    );

    if (!apiResponse.isSuccess || apiResponse.data == null) {
      throw Exception(
        ErrorMessageMapper.map(
          apiResponse.message ?? 'Failed to get ticket detail',
        ),
      );
    }

    return apiResponse.data!;
  }

  TicketModel _parseTicketDetail(dynamic json, int ticketId) {
    if (json is Map<String, dynamic>) {
      // Some backends wrap the actual payload again in `data`.
      final nested = json['data'];
      if (nested is Map<String, dynamic>) {
        return TicketModel.fromJson(
          _normalizeTicketMap(nested, fallbackTicketId: ticketId),
        );
      }

      if (nested is List) {
        return _parseTicketDetail(nested, ticketId);
      }

      return TicketModel.fromJson(
        _normalizeTicketMap(json, fallbackTicketId: ticketId),
      );
    }

    if (json is List) {
      final mapItems = json.whereType<Map>().toList();

      // 先检查是否有一项的 id 等于 ticketId（说明是工单对象列表）
      final ticketMatch = mapItems.cast<Map>().where(
        (item) => _asInt(item['id']) == ticketId && item.containsKey('subject'),
      );

      if (ticketMatch.isNotEmpty) {
        return TicketModel.fromJson(
          _normalizeTicketMap(
            Map<String, dynamic>.from(ticketMatch.first),
            fallbackTicketId: ticketId,
          ),
        );
      }

      // 否则视为消息列表（V2Board xiao 的典型返回格式）
      final messages = mapItems
          .map(
            (m) => _normalizeMessageMap(
              Map<String, dynamic>.from(m),
              fallbackTicketId: ticketId,
            ),
          )
          .toList();

      return TicketModel(
        id: ticketId,
        message: messages
            .map((m) => TicketMessageModel.fromJson(m))
            .toList(),
      );
    }

    // 降级兜底，至少保证页面不崩
    return TicketModel(id: ticketId, message: const []);
  }

  Map<String, dynamic> _normalizeTicketMap(
    Map<String, dynamic> raw, {
    required int fallbackTicketId,
  }) {
    final ticket = <String, dynamic>{...raw};

    if (ticket['id'] == null) {
      ticket['id'] = fallbackTicketId;
    }

    // 有些后端把主体放在 ticket 字段里
    if (ticket['ticket'] is Map) {
      ticket.addAll(Map<String, dynamic>.from(ticket['ticket'] as Map));
    }

    dynamic messages = ticket['message'];
    messages ??= ticket['messages'];
    messages ??= ticket['reply'];
    messages ??= ticket['replies'];

    if (messages is List) {
      ticket['message'] = messages
          .whereType<Map>()
          .map(
            (m) => _normalizeMessageMap(
              Map<String, dynamic>.from(m),
              fallbackTicketId: fallbackTicketId,
            ),
          )
          .toList();
    } else {
      ticket['message'] = <Map<String, dynamic>>[];
    }

    return ticket;
  }

  Map<String, dynamic> _normalizeMessageMap(
    Map<String, dynamic> raw, {
    required int fallbackTicketId,
  }) {
    final message = <String, dynamic>{...raw};

    message['ticket_id'] ??= _asInt(message['ticketId']) ?? fallbackTicketId;
    message['created_at'] ??=
        _asInt(message['createdAt']) ?? _asInt(message['created']);
    message['message'] ??=
        message['content'] ?? message['body'] ?? message['text'] ?? '';

    final isMeRaw = message.containsKey('is_me')
        ? message['is_me']
        : (message['isMe'] ?? message['is_user']);
    final isAdminRaw = message['is_admin'] ?? message['isAdmin'];

    if (isMeRaw != null) {
      message['is_me'] = _asBool(isMeRaw);
    } else if (isAdminRaw != null) {
      message['is_me'] = !_asBool(isAdminRaw);
    }

    return message;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lowered = value.toLowerCase();
      return lowered == '1' || lowered == 'true' || lowered == 'yes';
    }
    return false;
  }

  @override
  Future<void> createTicket(CreateTicketRequest request) async {
    final response = await _apiClient.post(
      ApiConstants.ticketSave,
      data: request.toJson(),
    );

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      null,
    );

    if (!apiResponse.isSuccess) {
      throw Exception(
        ErrorMessageMapper.map(
          apiResponse.message ?? 'Failed to create ticket',
        ),
      );
    }
  }

  @override
  Future<void> replyTicket(ReplyTicketRequest request) async {
    final response = await _apiClient.post(
      ApiConstants.ticketReply,
      data: request.toJson(),
    );

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      null,
    );

    if (!apiResponse.isSuccess) {
      throw Exception(
        ErrorMessageMapper.map(apiResponse.message ?? 'Failed to reply ticket'),
      );
    }
  }

  @override
  Future<void> closeTicket(int ticketId) async {
    final response = await _apiClient.post(
      ApiConstants.ticketClose,
      data: {'id': ticketId},
    );

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      null,
    );

    if (!apiResponse.isSuccess) {
      throw Exception(
        ErrorMessageMapper.map(apiResponse.message ?? 'Failed to close ticket'),
      );
    }
  }

  @override
  Future<String> uploadImage(String base64DataUri, String filename) async {
    final response = await _apiClient.post(
      ApiConstants.ticketUpload,
      data: {'image': base64DataUri, 'name': filename},
    );

    final data = response.data;
    if (data is Map) {
      final payload = data['data'];
      if (payload is List && payload.isNotEmpty) {
        return payload.first.toString();
      }
    }
    throw Exception('上传图片失败');
  }

  @override
  Future<List<KnowledgeModel>> getKnowledgeList() async {
    final response = await _apiClient.get(ApiConstants.knowledgeList);

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) {
        if (json is List) {
          return json
              .map((e) => KnowledgeModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return <KnowledgeModel>[];
      },
    );

    if (!apiResponse.isSuccess) {
      throw Exception(
        ErrorMessageMapper.map(
          apiResponse.message ?? 'Failed to get knowledge',
        ),
      );
    }

    return apiResponse.data ?? [];
  }
}
