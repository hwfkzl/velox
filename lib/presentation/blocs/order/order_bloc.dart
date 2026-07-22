import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/errors/exceptions.dart';
import '../../../data/models/order_model.dart';
import '../../../domain/repositories/order_repository.dart';

part 'order_event.dart';
part 'order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository _orderRepository;

  OrderBloc({required OrderRepository orderRepository})
      : _orderRepository = orderRepository,
        super(OrderInitial()) {
    on<OrderListRequested>(_onListRequested);
    on<OrderDetailRequested>(_onDetailRequested);
    on<OrderCreateRequested>(_onCreateRequested);
    on<OrderCancelRequested>(_onCancelRequested);
    on<OrderCheckoutRequested>(_onCheckoutRequested);
    on<PaymentMethodsRequested>(_onPaymentMethodsRequested);
    on<OrderCreateAndCheckout>(_onCreateAndCheckout);
  }

  Future<void> _onListRequested(
    OrderListRequested event,
    Emitter<OrderState> emit,
  ) async {
    // 如果是加载更多，显示加载更多状态
    if (event.loadMore && state is OrderListLoaded) {
      final currentState = state as OrderListLoaded;
      emit(OrderLoadingMore(
        currentOrders: currentState.orders,
        currentStatus: event.status,
      ));
    } else {
      emit(OrderLoading());
    }

    try {
      final orders = await _orderRepository.getOrderList(
        status: event.status,
        page: event.page,
      );

      // 判断是否还有更多数据（如果返回的数据少于10条，认为没有更多了）
      final hasMore = orders.length >= 10;

      if (event.loadMore && state is OrderLoadingMore) {
        // 加载更多：追加到现有列表
        final loadingState = state as OrderLoadingMore;
        final allOrders = [...loadingState.currentOrders, ...orders];
        emit(OrderListLoaded(
          orders: allOrders,
          currentPage: event.page,
          hasMore: hasMore,
          currentStatus: event.status,
        ));
      } else {
        // 新加载：替换列表
        emit(OrderListLoaded(
          orders: orders,
          currentPage: event.page,
          hasMore: hasMore,
          currentStatus: event.status,
        ));
      }
    } catch (e) {
      emit(OrderError(message: extractErrorMessage(e)));
    }
  }

  Future<void> _onDetailRequested(
    OrderDetailRequested event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());
    try {
      final order = await _orderRepository.getOrderDetail(event.tradeNo);
      emit(OrderDetailLoaded(order: order));
    } catch (e) {
      emit(OrderError(message: extractErrorMessage(e)));
    }
  }

  Future<void> _onPaymentMethodsRequested(
    PaymentMethodsRequested event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());
    try {
      final paymentMethods = await _orderRepository.getPaymentMethods();
      emit(PaymentMethodsLoaded(
        tradeNo: event.tradeNo,
        paymentMethods: paymentMethods,
      ));
    } catch (e) {
      emit(OrderError(message: extractErrorMessage(e)));
    }
  }

  Future<void> _onCreateRequested(
    OrderCreateRequested event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderCreating());
    try {
      final tradeNo = await _orderRepository.createOrder(
        planId: event.planId,
        period: event.period,
        couponCode: event.couponCode,
      );
      emit(OrderCreated(tradeNo: tradeNo));
    } catch (e) {
      emit(OrderError(message: extractErrorMessage(e)));
    }
  }

  Future<void> _onCancelRequested(
    OrderCancelRequested event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderLoading());
    try {
      await _orderRepository.cancelOrder(event.tradeNo);
      emit(OrderCancelled());
      // 重新加载列表
      add(OrderListRequested());
    } catch (e) {
      emit(OrderError(message: extractErrorMessage(e)));
    }
  }

  Future<void> _onCheckoutRequested(
    OrderCheckoutRequested event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderCheckingOut());
    try {
      final response = await _orderRepository.checkout(
        event.tradeNo,
        event.method,
      );
      emit(OrderCheckoutReady(response: response));
    } catch (e) {
      emit(OrderError(message: extractErrorMessage(e)));
    }
  }

  /// 创建订单并立即支付
  Future<void> _onCreateAndCheckout(
    OrderCreateAndCheckout event,
    Emitter<OrderState> emit,
  ) async {
    emit(OrderCreating());
    try {
      // 1. 创建订单
      final tradeNo = await _orderRepository.createOrder(
        planId: event.planId,
        period: event.period,
        couponCode: event.couponCode,
      );

      // 2. 立即支付
      emit(OrderCheckingOut());
      final response = await _orderRepository.checkout(
        tradeNo,
        event.methodId.toString(),
      );
      emit(OrderCheckoutReady(response: response));
    } catch (e) {
      emit(OrderError(message: extractErrorMessage(e)));
    }
  }
}
