// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InviteModel _$InviteModelFromJson(Map<String, dynamic> json) => InviteModel(
  codes: (json['codes'] as List<dynamic>?)
      ?.map((e) => InviteCodeModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  stat: InviteModel._statFromJson(json['stat']),
);

Map<String, dynamic> _$InviteModelToJson(InviteModel instance) =>
    <String, dynamic>{'codes': instance.codes, 'stat': instance.stat};

InviteCodeModel _$InviteCodeModelFromJson(Map<String, dynamic> json) =>
    InviteCodeModel(
      id: (json['id'] as num?)?.toInt(),
      userId: (json['user_id'] as num?)?.toInt(),
      code: json['code'] as String?,
      status: (json['status'] as num?)?.toInt(),
      pageViews: (json['pv'] as num?)?.toInt(),
      createdAt: _parseUnixTs(json['created_at']),
      updatedAt: _parseUnixTs(json['updated_at']),
    );

Map<String, dynamic> _$InviteCodeModelToJson(InviteCodeModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'code': instance.code,
      'status': instance.status,
      'pv': instance.pageViews,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

InviteStatModel _$InviteStatModelFromJson(Map<String, dynamic> json) =>
    InviteStatModel(
      registeredCount: (json['registered_count'] as num?)?.toInt(),
      commissionEarned: (json['commission_earned'] as num?)?.toInt(),
      commissionPending: (json['commission_pending'] as num?)?.toInt(),
      commissionRate: (json['commission_rate'] as num?)?.toInt(),
      commissionBalance: (json['commission_balance'] as num?)?.toInt(),
    );

Map<String, dynamic> _$InviteStatModelToJson(InviteStatModel instance) =>
    <String, dynamic>{
      'registered_count': instance.registeredCount,
      'commission_earned': instance.commissionEarned,
      'commission_pending': instance.commissionPending,
      'commission_rate': instance.commissionRate,
      'commission_balance': instance.commissionBalance,
    };

InviteRecordModel _$InviteRecordModelFromJson(Map<String, dynamic> json) =>
    InviteRecordModel(
      id: (json['id'] as num?)?.toInt(),
      tradeNo: json['trade_no'] as String?,
      orderAmount: (json['order_amount'] as num?)?.toInt(),
      getAmount: (json['get_amount'] as num?)?.toInt(),
      createdAt: _parseUnixTs(json['created_at']),
    );

Map<String, dynamic> _$InviteRecordModelToJson(InviteRecordModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'trade_no': instance.tradeNo,
      'order_amount': instance.orderAmount,
      'get_amount': instance.getAmount,
      'created_at': instance.createdAt,
    };
