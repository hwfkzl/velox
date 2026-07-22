import 'package:json_annotation/json_annotation.dart';

part 'ticket_model.g.dart';

/// 工单状态
enum TicketStatus {
  @JsonValue(0)
  open, // 开放
  @JsonValue(1)
  closed, // 已关闭
}

@JsonSerializable()
class TicketModel {
  final int? id;
  @JsonKey(name: 'user_id')
  final int? userId;
  final String? subject;
  final int? level; // 优先级 0-低 1-中 2-高
  final int? status;
  @JsonKey(name: 'reply_status')
  final int? replyStatus;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @JsonKey(name: 'updated_at')
  final int? updatedAt;
  final List<TicketMessageModel>? message;

  TicketModel({
    this.id,
    this.userId,
    this.subject,
    this.level,
    this.status,
    this.replyStatus,
    this.createdAt,
    this.updatedAt,
    this.message,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) =>
      _$TicketModelFromJson(json);

  Map<String, dynamic> toJson() => _$TicketModelToJson(this);

  /// 是否开放
  bool get isOpen => status == 0;

  /// 是否已关闭
  bool get isClosed => status == 1;

  /// 是否有新回复
  bool get hasNewReply => replyStatus == 1;

  /// 工单状态
  TicketStatus get ticketStatus {
    return status == 0 ? TicketStatus.open : TicketStatus.closed;
  }

  /// 优先级显示
  String get levelDisplay {
    switch (level) {
      case 0:
        return 'Low';
      case 1:
        return 'Medium';
      case 2:
        return 'High';
      default:
        return 'Unknown';
    }
  }

  /// 创建时间
  DateTime? get createDate {
    if (createdAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(createdAt! * 1000);
  }

  /// 更新时间
  DateTime? get updateDate {
    if (updatedAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(updatedAt! * 1000);
  }
}

@JsonSerializable()
class TicketMessageModel {
  final int? id;
  @JsonKey(name: 'user_id')
  final int? userId;
  @JsonKey(name: 'ticket_id')
  final int? ticketId;
  final String? message;
  @JsonKey(name: 'is_me')
  final bool? isMe;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  final List<String>? images;

  TicketMessageModel({
    this.id,
    this.userId,
    this.ticketId,
    this.message,
    this.isMe,
    this.createdAt,
    this.images,
  });

  factory TicketMessageModel.fromJson(Map<String, dynamic> json) =>
      _$TicketMessageModelFromJson(json);

  Map<String, dynamic> toJson() => _$TicketMessageModelToJson(this);

  /// 是否是用户发送的消息
  bool get isUserMessage => isMe == true;

  /// 创建时间
  DateTime? get createDate {
    if (createdAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(createdAt! * 1000);
  }
}

@JsonSerializable()
class CreateTicketRequest {
  final String subject;
  final String message;
  final int? level;
  final List<String>? images;

  CreateTicketRequest({
    required this.subject,
    required this.message,
    this.level,
    this.images,
  });

  factory CreateTicketRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateTicketRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateTicketRequestToJson(this);
}

@JsonSerializable()
class ReplyTicketRequest {
  final int id;
  final String message;
  final List<String>? images;

  ReplyTicketRequest({
    required this.id,
    required this.message,
    this.images,
  });

  factory ReplyTicketRequest.fromJson(Map<String, dynamic> json) =>
      _$ReplyTicketRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ReplyTicketRequestToJson(this);
}
