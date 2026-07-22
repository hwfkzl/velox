// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderModel _$OrderModelFromJson(Map<String, dynamic> json) => OrderModel(
  tradeNo: json['trade_no'] as String?,
  callbackNo: json['callback_no'] as String?,
  totalAmount: (json['total_amount'] as num?)?.toInt(),
  discountAmount: (json['discount_amount'] as num?)?.toInt(),
  surplusAmount: (json['surplus_amount'] as num?)?.toInt(),
  refundAmount: (json['refund_amount'] as num?)?.toInt(),
  balance: (json['balance'] as num?)?.toInt(),
  status: (json['status'] as num?)?.toInt(),
  commission: (json['commission'] as num?)?.toInt(),
  commissionStatus: (json['commission_status'] as num?)?.toInt(),
  commissionBalance: (json['commission_balance'] as num?)?.toInt(),
  userId: (json['user_id'] as num?)?.toInt(),
  planId: (json['plan_id'] as num?)?.toInt(),
  period: json['period'] as String?,
  type: (json['type'] as num?)?.toInt(),
  couponId: (json['coupon_id'] as num?)?.toInt(),
  paidAt: (json['paid_at'] as num?)?.toInt(),
  createdAt: (json['created_at'] as num?)?.toInt(),
  updatedAt: (json['updated_at'] as num?)?.toInt(),
  plan: json['plan'] == null
      ? null
      : OrderPlanModel.fromJson(json['plan'] as Map<String, dynamic>),
);

Map<String, dynamic> _$OrderModelToJson(OrderModel instance) =>
    <String, dynamic>{
      'trade_no': instance.tradeNo,
      'callback_no': instance.callbackNo,
      'total_amount': instance.totalAmount,
      'discount_amount': instance.discountAmount,
      'surplus_amount': instance.surplusAmount,
      'refund_amount': instance.refundAmount,
      'balance': instance.balance,
      'status': instance.status,
      'commission': instance.commission,
      'commission_status': instance.commissionStatus,
      'commission_balance': instance.commissionBalance,
      'user_id': instance.userId,
      'plan_id': instance.planId,
      'period': instance.period,
      'type': instance.type,
      'coupon_id': instance.couponId,
      'paid_at': instance.paidAt,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'plan': instance.plan,
    };

OrderPlanModel _$OrderPlanModelFromJson(Map<String, dynamic> json) =>
    OrderPlanModel(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      content: json['content'] as String?,
      transferEnable: (json['transfer_enable'] as num?)?.toInt(),
    );

Map<String, dynamic> _$OrderPlanModelToJson(OrderPlanModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'content': instance.content,
      'transfer_enable': instance.transferEnable,
    };

CreateOrderRequest _$CreateOrderRequestFromJson(Map<String, dynamic> json) =>
    CreateOrderRequest(
      planId: (json['plan_id'] as num).toInt(),
      period: json['period'] as String,
      couponCode: json['coupon_code'] as String?,
    );

Map<String, dynamic> _$CreateOrderRequestToJson(CreateOrderRequest instance) =>
    <String, dynamic>{
      'plan_id': instance.planId,
      'period': instance.period,
      'coupon_code': ?instance.couponCode,
    };

CheckoutResponse _$CheckoutResponseFromJson(Map<String, dynamic> json) =>
    CheckoutResponse(
      type: json['type'] as String?,
      data: json['data'] as String?,
    );

Map<String, dynamic> _$CheckoutResponseToJson(CheckoutResponse instance) =>
    <String, dynamic>{'type': instance.type, 'data': instance.data};

PaymentMethodModel _$PaymentMethodModelFromJson(Map<String, dynamic> json) =>
    PaymentMethodModel(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String?,
      payment: json['payment'] as String?,
      icon: json['icon'] as String?,
      handlingFeeFixed: (json['handling_fee_fixed'] as num?)?.toInt(),
      handlingFeePercent: (json['handling_fee_percent'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$PaymentMethodModelToJson(PaymentMethodModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'payment': instance.payment,
      'icon': instance.icon,
      'handling_fee_fixed': instance.handlingFeeFixed,
      'handling_fee_percent': instance.handlingFeePercent,
    };

OrderDetailResponse _$OrderDetailResponseFromJson(Map<String, dynamic> json) =>
    OrderDetailResponse(
      order: json['order'] == null
          ? null
          : OrderModel.fromJson(json['order'] as Map<String, dynamic>),
      paymentMethods: (json['payment_methods'] as List<dynamic>?)
          ?.map((e) => PaymentMethodModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OrderDetailResponseToJson(
  OrderDetailResponse instance,
) => <String, dynamic>{
  'order': instance.order,
  'payment_methods': instance.paymentMethods,
};
