part of 'order_bloc.dart';

abstract class OrderEvent extends Equatable {
  const OrderEvent();

  @override
  List<Object?> get props => [];
}

class OrderListRequested extends OrderEvent {
  final int? status; // 0: 待支付, 1: 已支付, null: 全部
  final int page;
  final bool loadMore; // 是否加载更多（追加到列表）

  const OrderListRequested({
    this.status,
    this.page = 1,
    this.loadMore = false,
  });

  @override
  List<Object?> get props => [status, page, loadMore];
}

class OrderDetailRequested extends OrderEvent {
  final String tradeNo;

  const OrderDetailRequested({required this.tradeNo});

  @override
  List<Object> get props => [tradeNo];
}

class OrderCreateRequested extends OrderEvent {
  final int planId;
  final String period;
  final String? couponCode;

  const OrderCreateRequested({
    required this.planId,
    required this.period,
    this.couponCode,
  });

  @override
  List<Object?> get props => [planId, period, couponCode];
}

class OrderCancelRequested extends OrderEvent {
  final String tradeNo;

  const OrderCancelRequested({required this.tradeNo});

  @override
  List<Object> get props => [tradeNo];
}

class OrderCheckoutRequested extends OrderEvent {
  final String tradeNo;
  final String method;

  const OrderCheckoutRequested({
    required this.tradeNo,
    required this.method,
  });

  @override
  List<Object> get props => [tradeNo, method];
}

class PaymentMethodsRequested extends OrderEvent {
  final String tradeNo;

  const PaymentMethodsRequested({required this.tradeNo});

  @override
  List<Object> get props => [tradeNo];
}

/// 创建订单并立即支付
class OrderCreateAndCheckout extends OrderEvent {
  final int planId;
  final String period;
  final int methodId;
  final String? couponCode;

  const OrderCreateAndCheckout({
    required this.planId,
    required this.period,
    required this.methodId,
    this.couponCode,
  });

  @override
  List<Object?> get props => [planId, period, methodId, couponCode];
}
