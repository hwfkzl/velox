import 'package:json_annotation/json_annotation.dart';

part 'order_model.g.dart';

/// 订单状态
enum OrderStatus {
  @JsonValue(0)
  pending, // 待支付
  @JsonValue(1)
  paid, // 已支付
  @JsonValue(2)
  cancelled, // 已取消
  @JsonValue(3)
  completed, // 已完成
}

@JsonSerializable()
class OrderModel {
  @JsonKey(name: 'trade_no')
  final String? tradeNo;
  @JsonKey(name: 'callback_no')
  final String? callbackNo;
  @JsonKey(name: 'total_amount')
  final int? totalAmount; // 分
  @JsonKey(name: 'discount_amount')
  final int? discountAmount;
  @JsonKey(name: 'surplus_amount')
  final int? surplusAmount;
  @JsonKey(name: 'refund_amount')
  final int? refundAmount;
  final int? balance; // 使用余额
  final int? status;
  final int? commission; // 佣金
  @JsonKey(name: 'commission_status')
  final int? commissionStatus;
  @JsonKey(name: 'commission_balance')
  final int? commissionBalance;
  @JsonKey(name: 'user_id')
  final int? userId;
  @JsonKey(name: 'plan_id')
  final int? planId;
  final String? period; // month_price, quarter_price, half_year_price, year_price
  final int? type; // 1: new_purchase, 2: renewal, 3: upgrade
  @JsonKey(name: 'coupon_id')
  final int? couponId;
  @JsonKey(name: 'paid_at')
  final int? paidAt;
  @JsonKey(name: 'created_at')
  final int? createdAt;
  @JsonKey(name: 'updated_at')
  final int? updatedAt;
  final OrderPlanModel? plan;

  OrderModel({
    this.tradeNo,
    this.callbackNo,
    this.totalAmount,
    this.discountAmount,
    this.surplusAmount,
    this.refundAmount,
    this.balance,
    this.status,
    this.commission,
    this.commissionStatus,
    this.commissionBalance,
    this.userId,
    this.planId,
    this.period,
    this.type,
    this.couponId,
    this.paidAt,
    this.createdAt,
    this.updatedAt,
    this.plan,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);

  Map<String, dynamic> toJson() => _$OrderModelToJson(this);

  /// 订单状态
  OrderStatus get orderStatus {
    switch (status) {
      case 0:
        return OrderStatus.pending;
      case 1:
        return OrderStatus.paid;
      case 2:
        return OrderStatus.cancelled;
      case 3:
        return OrderStatus.completed;
      default:
        return OrderStatus.pending;
    }
  }

  /// 是否待支付
  bool get isPending => status == 0;

  /// 是否已支付
  bool get isPaid => status == 1;

  /// 总金额 (元)
  double get totalAmountYuan => (totalAmount ?? 0) / 100;

  /// 创建时间
  DateTime? get createDate {
    if (createdAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(createdAt! * 1000);
  }

  /// 支付时间
  DateTime? get paidDate {
    if (paidAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(paidAt! * 1000);
  }

  /// 格式化日期
  String get formattedDate {
    final date = createDate;
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 周期显示名称
  String get periodDisplay {
    switch (period) {
      case 'month':
      case 'month_price':
        return 'Monthly';
      case 'quarter':
      case 'quarter_price':
        return 'Quarterly';
      case 'half_year':
      case 'half_year_price':
        return 'Half Year';
      case 'year':
      case 'year_price':
        return 'Yearly';
      case 'two_year':
      case 'two_year_price':
        return '2 Years';
      case 'three_year':
      case 'three_year_price':
        return '3 Years';
      case 'onetime':
      case 'onetime_price':
        return 'One Time';
      default:
        return period ?? 'Unknown';
    }
  }
}

@JsonSerializable()
class OrderPlanModel {
  final int? id;
  final String? name;
  final String? content;
  @JsonKey(name: 'transfer_enable')
  final int? transferEnable;

  OrderPlanModel({
    this.id,
    this.name,
    this.content,
    this.transferEnable,
  });

  factory OrderPlanModel.fromJson(Map<String, dynamic> json) =>
      _$OrderPlanModelFromJson(json);

  Map<String, dynamic> toJson() => _$OrderPlanModelToJson(this);
}

@JsonSerializable()
class CreateOrderRequest {
  @JsonKey(name: 'plan_id')
  final int planId;
  final String period;
  @JsonKey(name: 'coupon_code', includeIfNull: false)
  final String? couponCode;

  CreateOrderRequest({
    required this.planId,
    required this.period,
    this.couponCode,
  });

  factory CreateOrderRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateOrderRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateOrderRequestToJson(this);
}

@JsonSerializable()
class CheckoutResponse {
  final String? type;
  final String? data; // 支付链接或二维码数据

  CheckoutResponse({
    this.type,
    this.data,
  });

  factory CheckoutResponse.fromJson(Map<String, dynamic> json) =>
      _$CheckoutResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CheckoutResponseToJson(this);
}

/// 支付方式模型
@JsonSerializable()
class PaymentMethodModel {
  final int? id;
  final String? name;
  final String? payment; // 支付标识，用于 checkout
  final String? icon;
  @JsonKey(name: 'handling_fee_fixed')
  final int? handlingFeeFixed;
  @JsonKey(name: 'handling_fee_percent')
  final double? handlingFeePercent;

  PaymentMethodModel({
    this.id,
    this.name,
    this.payment,
    this.icon,
    this.handlingFeeFixed,
    this.handlingFeePercent,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodModelFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentMethodModelToJson(this);
}

/// 订单详情响应（包含支付方式）
@JsonSerializable()
class OrderDetailResponse {
  final OrderModel? order;
  @JsonKey(name: 'payment_methods')
  final List<PaymentMethodModel>? paymentMethods;

  OrderDetailResponse({
    this.order,
    this.paymentMethods,
  });

  factory OrderDetailResponse.fromJson(Map<String, dynamic> json) =>
      _$OrderDetailResponseFromJson(json);

  Map<String, dynamic> toJson() => _$OrderDetailResponseToJson(this);
}
