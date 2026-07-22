// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TicketModel _$TicketModelFromJson(Map<String, dynamic> json) => TicketModel(
  id: (json['id'] as num?)?.toInt(),
  userId: (json['user_id'] as num?)?.toInt(),
  subject: json['subject'] as String?,
  level: (json['level'] as num?)?.toInt(),
  status: (json['status'] as num?)?.toInt(),
  replyStatus: (json['reply_status'] as num?)?.toInt(),
  createdAt: (json['created_at'] as num?)?.toInt(),
  updatedAt: (json['updated_at'] as num?)?.toInt(),
  message: (json['message'] as List<dynamic>?)
      ?.map((e) => TicketMessageModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$TicketModelToJson(TicketModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'subject': instance.subject,
      'level': instance.level,
      'status': instance.status,
      'reply_status': instance.replyStatus,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'message': instance.message,
    };

TicketMessageModel _$TicketMessageModelFromJson(Map<String, dynamic> json) =>
    TicketMessageModel(
      id: (json['id'] as num?)?.toInt(),
      userId: (json['user_id'] as num?)?.toInt(),
      ticketId: (json['ticket_id'] as num?)?.toInt(),
      message: json['message'] as String?,
      isMe: json['is_me'] as bool?,
      createdAt: (json['created_at'] as num?)?.toInt(),
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$TicketMessageModelToJson(TicketMessageModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'ticket_id': instance.ticketId,
      'message': instance.message,
      'is_me': instance.isMe,
      'created_at': instance.createdAt,
      'images': instance.images,
    };

CreateTicketRequest _$CreateTicketRequestFromJson(Map<String, dynamic> json) =>
    CreateTicketRequest(
      subject: json['subject'] as String,
      message: json['message'] as String,
      level: (json['level'] as num?)?.toInt(),
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$CreateTicketRequestToJson(
  CreateTicketRequest instance,
) => <String, dynamic>{
  'subject': instance.subject,
  'message': instance.message,
  'level': instance.level,
  'images': instance.images,
};

ReplyTicketRequest _$ReplyTicketRequestFromJson(Map<String, dynamic> json) =>
    ReplyTicketRequest(
      id: (json['id'] as num).toInt(),
      message: json['message'] as String,
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ReplyTicketRequestToJson(ReplyTicketRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'message': instance.message,
      'images': instance.images,
    };
