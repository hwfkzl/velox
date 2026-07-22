import '../../domain/repositories/order_repository.dart';
import '../datasources/remote/order_remote_datasource.dart';
import '../models/order_model.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource _remoteDataSource;

  OrderRepositoryImpl({required OrderRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<List<OrderModel>> getOrderList({int? status, int page = 1}) async {
    return await _remoteDataSource.getOrderList(status: status, page: page);
  }

  @override
  Future<OrderModel> getOrderDetail(String tradeNo) async {
    return await _remoteDataSource.getOrderDetail(tradeNo);
  }

  @override
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    return await _remoteDataSource.getPaymentMethods();
  }

  @override
  Future<String> createOrder({
    required int planId,
    required String period,
    String? couponCode,
  }) async {
    final request = CreateOrderRequest(
      planId: planId,
      period: period,
      couponCode: couponCode,
    );
    return await _remoteDataSource.createOrder(request);
  }

  @override
  Future<void> cancelOrder(String tradeNo) async {
    await _remoteDataSource.cancelOrder(tradeNo);
  }

  @override
  Future<CheckoutResponse> checkout(String tradeNo, String method) async {
    return await _remoteDataSource.checkout(tradeNo, method);
  }
}
