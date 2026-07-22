part of 'order_bloc.dart';

abstract class OrderState extends Equatable {
  const OrderState();

  @override
  List<Object?> get props => [];
}

class OrderInitial extends OrderState {}

class OrderLoading extends OrderState {}

class OrderCreating extends OrderState {}

class OrderCheckingOut extends OrderState {}

class OrderListLoaded extends OrderState {
  final List<OrderModel> orders;
  final int currentPage;
  final bool hasMore;
  final int? currentStatus; // null: 全部, 0: 待支付, 1: 已支付

  const OrderListLoaded({
    required this.orders,
    this.currentPage = 1,
    this.hasMore = true,
    this.currentStatus,
  });

  @override
  List<Object?> get props => [orders, currentPage, hasMore, currentStatus];

  List<OrderModel> get pendingOrders =>
      orders.where((o) => o.isPending).toList();

  List<OrderModel> get paidOrders =>
      orders.where((o) => o.isPaid).toList();

  OrderListLoaded copyWith({
    List<OrderModel>? orders,
    int? currentPage,
    bool? hasMore,
    int? currentStatus,
  }) {
    return OrderListLoaded(
      orders: orders ?? this.orders,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      currentStatus: currentStatus,
    );
  }
}

class OrderLoadingMore extends OrderState {
  final List<OrderModel> currentOrders;
  final int? currentStatus;

  const OrderLoadingMore({
    required this.currentOrders,
    this.currentStatus,
  });

  @override
  List<Object?> get props => [currentOrders, currentStatus];
}

class OrderDetailLoaded extends OrderState {
  final OrderModel order;

  const OrderDetailLoaded({required this.order});

  @override
  List<Object> get props => [order];
}

class PaymentMethodsLoaded extends OrderState {
  final String tradeNo;
  final List<PaymentMethodModel> paymentMethods;

  const PaymentMethodsLoaded({
    required this.tradeNo,
    required this.paymentMethods,
  });

  @override
  List<Object> get props => [tradeNo, paymentMethods];
}

class OrderCreated extends OrderState {
  final String tradeNo;

  const OrderCreated({required this.tradeNo});

  @override
  List<Object> get props => [tradeNo];
}

class OrderCancelled extends OrderState {}

class OrderCheckoutReady extends OrderState {
  final CheckoutResponse response;

  const OrderCheckoutReady({required this.response});

  @override
  List<Object> get props => [response];
}

class OrderError extends OrderState {
  final String message;

  const OrderError({required this.message});

  @override
  List<Object> get props => [message];
}
