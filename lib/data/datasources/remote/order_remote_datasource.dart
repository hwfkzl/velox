import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/error_message_mapper.dart';
import '../../models/order_model.dart';

abstract class OrderRemoteDataSource {
  /// 获取订单列表（支持分页和状态筛选）
  Future<List<OrderModel>> getOrderList({int? status, int page = 1});

  /// 获取订单详情
  Future<OrderModel> getOrderDetail(String tradeNo);

  /// 获取支付方式列表
  Future<List<PaymentMethodModel>> getPaymentMethods();

  /// 创建订单
  Future<String> createOrder(CreateOrderRequest request);

  /// 取消订单
  Future<void> cancelOrder(String tradeNo);

  /// 结账
  Future<CheckoutResponse> checkout(String tradeNo, String method);
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  final ApiClient _apiClient;

  OrderRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<OrderModel>> getOrderList({int? status, int page = 1}) async {
    final queryParams = <String, dynamic>{
      'page': page,
    };
    if (status != null) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.get(
      ApiConstants.orderList,
      queryParameters: queryParams,
    );

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) {
        if (json is List) {
          return json
              .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return <OrderModel>[];
      },
    );

    if (!apiResponse.isSuccess) {
      throw Exception(ErrorMessageMapper.map(apiResponse.message ?? 'Failed to get orders'));
    }

    return apiResponse.data ?? [];
  }

  @override
  Future<OrderModel> getOrderDetail(String tradeNo) async {
    final response = await _apiClient.get(
      ApiConstants.orderDetail,
      queryParameters: {'trade_no': tradeNo},
    );

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) => OrderModel.fromJson(json as Map<String, dynamic>),
    );

    if (!apiResponse.isSuccess || apiResponse.data == null) {
      throw Exception(ErrorMessageMapper.map(apiResponse.message ?? 'Failed to get order detail'));
    }

    return apiResponse.data!;
  }

  @override
  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final response = await _apiClient.get(ApiConstants.paymentMethods);

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) {
        if (json is List) {
          return json
              .map((e) => PaymentMethodModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return <PaymentMethodModel>[];
      },
    );

    if (!apiResponse.isSuccess) {
      throw Exception(ErrorMessageMapper.map(apiResponse.message ?? 'Failed to get payment methods'));
    }

    return apiResponse.data ?? [];
  }

  @override
  Future<String> createOrder(CreateOrderRequest request) async {
    final response = await _apiClient.post(
      ApiConstants.orderSave,
      data: request.toJson(),
    );

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) => json as String?,
    );

    if (!apiResponse.isSuccess || apiResponse.data == null) {
      throw Exception(ErrorMessageMapper.map(apiResponse.message ?? 'Failed to create order'));
    }

    return apiResponse.data!;
  }

  @override
  Future<void> cancelOrder(String tradeNo) async {
    final response = await _apiClient.post(
      ApiConstants.orderCancel,
      data: {'trade_no': tradeNo},
    );

    final apiResponse = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      null,
    );

    if (!apiResponse.isSuccess) {
      throw Exception(ErrorMessageMapper.map(apiResponse.message ?? 'Failed to cancel order'));
    }
  }

  @override
  Future<CheckoutResponse> checkout(String tradeNo, String method) async {
    final response = await _apiClient.post(
      ApiConstants.orderCheckout,
      data: {
        'trade_no': tradeNo,
        'method': method,
      },
    );

    final json = response.data as Map<String, dynamic>;

    // Checkout API 返回格式: {"type": 1, "data": "payment_url"}
    // 不是标准的 ApiResponse 格式，需要直接解析
    if (json.containsKey('message')) {
      // 错误响应: {"message": "错误信息"}
      throw Exception(ErrorMessageMapper.map(json['message'] ?? 'Failed to checkout'));
    }

    // 成功响应: {"type": 1, "data": "payment_url"}
    return CheckoutResponse(
      type: json['type']?.toString(),
      data: json['data'] as String?,
    );
  }
}
