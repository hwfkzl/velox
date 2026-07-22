import '../../data/models/order_model.dart';

abstract class OrderRepository {
  /// 获取订单列表（支持分页和状态筛选）
  /// [status] 0: 待支付, 1: 已支付, null: 全部
  /// [page] 页码，从1开始
  Future<List<OrderModel>> getOrderList({int? status, int page = 1});

  /// 获取订单详情
  Future<OrderModel> getOrderDetail(String tradeNo);

  /// 获取支付方式列表
  Future<List<PaymentMethodModel>> getPaymentMethods();

  /// 创建订单
  Future<String> createOrder({
    required int planId,
    required String period,
    String? couponCode,
  });

  /// 取消订单
  Future<void> cancelOrder(String tradeNo);

  /// 结账
  Future<CheckoutResponse> checkout(String tradeNo, String method);
}
