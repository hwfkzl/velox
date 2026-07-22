// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscribe_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscribeModel _$SubscribeModelFromJson(Map<String, dynamic> json) =>
    SubscribeModel(
      planId: (json['plan_id'] as num?)?.toInt(),
      token: json['token'] as String?,
      expiredAt: (json['expired_at'] as num?)?.toInt(),
      u: (json['u'] as num?)?.toInt(),
      d: (json['d'] as num?)?.toInt(),
      transferEnable: (json['transfer_enable'] as num?)?.toInt(),
      resetDay: (json['reset_day'] as num?)?.toInt(),
      subscribeUrl: json['subscribe_url'] as String?,
      plan: json['plan'] == null
          ? null
          : PlanModel.fromJson(json['plan'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SubscribeModelToJson(SubscribeModel instance) =>
    <String, dynamic>{
      'plan_id': instance.planId,
      'token': instance.token,
      'expired_at': instance.expiredAt,
      'u': instance.u,
      'd': instance.d,
      'transfer_enable': instance.transferEnable,
      'reset_day': instance.resetDay,
      'subscribe_url': instance.subscribeUrl,
      'plan': instance.plan,
    };

PlanModel _$PlanModelFromJson(Map<String, dynamic> json) => PlanModel(
  id: (json['id'] as num?)?.toInt(),
  groupId: (json['group_id'] as num?)?.toInt(),
  transferEnable: (json['transfer_enable'] as num?)?.toInt(),
  name: json['name'] as String?,
  speedLimit: (json['speed_limit'] as num?)?.toInt(),
  show: (json['show'] as num?)?.toInt(),
  sort: (json['sort'] as num?)?.toInt(),
  renew: (json['renew'] as num?)?.toInt(),
  content: json['content'] as String?,
  monthPrice: (json['month_price'] as num?)?.toInt(),
  quarterPrice: (json['quarter_price'] as num?)?.toInt(),
  halfYearPrice: (json['half_year_price'] as num?)?.toInt(),
  yearPrice: (json['year_price'] as num?)?.toInt(),
  twoYearPrice: (json['two_year_price'] as num?)?.toInt(),
  threeYearPrice: (json['three_year_price'] as num?)?.toInt(),
  onetimePrice: (json['onetime_price'] as num?)?.toInt(),
  resetPrice: (json['reset_price'] as num?)?.toInt(),
  resetTrafficMethod: (json['reset_traffic_method'] as num?)?.toInt(),
  capacityLimit: (json['capacity_limit'] as num?)?.toInt(),
  createdAt: (json['created_at'] as num?)?.toInt(),
  updatedAt: (json['updated_at'] as num?)?.toInt(),
);

Map<String, dynamic> _$PlanModelToJson(PlanModel instance) => <String, dynamic>{
  'id': instance.id,
  'group_id': instance.groupId,
  'transfer_enable': instance.transferEnable,
  'name': instance.name,
  'speed_limit': instance.speedLimit,
  'show': instance.show,
  'sort': instance.sort,
  'renew': instance.renew,
  'content': instance.content,
  'month_price': instance.monthPrice,
  'quarter_price': instance.quarterPrice,
  'half_year_price': instance.halfYearPrice,
  'year_price': instance.yearPrice,
  'two_year_price': instance.twoYearPrice,
  'three_year_price': instance.threeYearPrice,
  'onetime_price': instance.onetimePrice,
  'reset_price': instance.resetPrice,
  'reset_traffic_method': instance.resetTrafficMethod,
  'capacity_limit': instance.capacityLimit,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};
