// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: (json['id'] as num?)?.toInt(),
  email: json['email'] as String?,
  uuid: json['uuid'] as String?,
  transferEnable: (json['transfer_enable'] as num?)?.toInt(),
  lastLoginAt: (json['last_login_at'] as num?)?.toInt(),
  createdAt: (json['created_at'] as num?)?.toInt(),
  banned: (json['banned'] as num?)?.toInt(),
  remindExpire: (json['remind_expire'] as num?)?.toInt(),
  remindTraffic: (json['remind_traffic'] as num?)?.toInt(),
  u: (json['u'] as num?)?.toInt(),
  d: (json['d'] as num?)?.toInt(),
  expiredAt: (json['expired_at'] as num?)?.toInt(),
  planId: (json['plan_id'] as num?)?.toInt(),
  balance: (json['balance'] as num?)?.toDouble(),
  commission: (json['commission'] as num?)?.toDouble(),
  commissionBalance: (json['commission_balance'] as num?)?.toDouble(),
  inviteUserId: (json['invite_user_id'] as num?)?.toInt(),
  telegramId: (json['telegram_id'] as num?)?.toInt(),
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'uuid': instance.uuid,
  'transfer_enable': instance.transferEnable,
  'last_login_at': instance.lastLoginAt,
  'created_at': instance.createdAt,
  'banned': instance.banned,
  'remind_expire': instance.remindExpire,
  'remind_traffic': instance.remindTraffic,
  'u': instance.u,
  'd': instance.d,
  'expired_at': instance.expiredAt,
  'plan_id': instance.planId,
  'balance': instance.balance,
  'commission': instance.commission,
  'commission_balance': instance.commissionBalance,
  'invite_user_id': instance.inviteUserId,
  'telegram_id': instance.telegramId,
};
