import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../core/utils/localized_error_mapper.dart';
import '../../../data/models/order_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/order/order_bloc.dart';
import '../../widgets/shared/velox_app_bar.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  String? _pendingPaymentTradeNo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.veloxColors;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: VeloxAppBar(
        title: l10n.orders,
        showBackButton: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: colors.bgGradient,
        ),
        child: SafeArea(
          child: BlocConsumer<OrderBloc, OrderState>(
            listener: (context, state) {
              if (state is OrderCancelled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.success),
                    backgroundColor: VeloxColors.success,
                  ),
                );
                context.read<OrderBloc>().add(OrderListRequested());
              } else if (state is PaymentMethodsLoaded) {
                // 获取到支付方式后显示支付弹窗
                _showPaymentMethodsSheet(
                  context,
                  state.tradeNo,
                  state.paymentMethods,
                  l10n,
                );
                _pendingPaymentTradeNo = null;
              } else if (state is OrderCheckoutReady) {
                // 处理支付响应
                _handleCheckoutResponse(context, state.response, l10n);
              } else if (state is OrderError) {
                final localizedMsg = LocalizedErrorMapper.getLocalizedError(l10n, state.message);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizedMsg),
                    backgroundColor: VeloxColors.error,
                  ),
                );
                // 如果正在等待支付方式，清除状态并刷新订单列表
                if (_pendingPaymentTradeNo != null) {
                  _pendingPaymentTradeNo = null;
                  context.read<OrderBloc>().add(OrderListRequested());
                }
              }
            },
            builder: (context, state) {
              if (state is OrderLoading || state is OrderCheckingOut) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: VeloxColors.primary,
                  ),
                );
              }

              if (state is OrderError && _pendingPaymentTradeNo == null) {
                final localizedMsg = LocalizedErrorMapper.getLocalizedError(l10n, state.message);
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: VeloxColors.error.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: VeloxSpacing.lg),
                      Text(
                        localizedMsg,
                        style: const TextStyle(
                          color: VeloxColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: VeloxSpacing.lg),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.read<OrderBloc>().add(OrderListRequested());
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(l10n.retry),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VeloxColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (state is OrderListLoaded) {
                if (state.orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: VeloxColors.textTertiary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: VeloxSpacing.lg),
                        Text(
                          l10n.noOrders,
                          style: const TextStyle(
                            color: VeloxColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<OrderBloc>().add(OrderListRequested());
                  },
                  color: VeloxColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(VeloxSpacing.pagePadding),
                    itemCount: state.orders.length,
                    itemBuilder: (context, index) {
                      final order = state.orders[index];
                      return _OrderCard(
                        order: order,
                        l10n: l10n,
                        onPayPressed: () => _onPayPressed(order.tradeNo!),
                      );
                    },
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  void _onPayPressed(String tradeNo) {
    _pendingPaymentTradeNo = tradeNo;
    context.read<OrderBloc>().add(PaymentMethodsRequested(tradeNo: tradeNo));
  }

  void _showPaymentMethodsSheet(
    BuildContext context,
    String tradeNo,
    List<PaymentMethodModel> paymentMethods,
    AppLocalizations l10n,
  ) {
    // 如果没有支付方式，显示错误
    if (paymentMethods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noPaymentMethods),
          backgroundColor: VeloxColors.error,
        ),
      );
      context.read<OrderBloc>().add(OrderListRequested());
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: VeloxColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(VeloxSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VeloxColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: VeloxSpacing.lg),
              Text(
                l10n.selectPaymentMethod,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: VeloxColors.textPrimary,
                ),
              ),
              const SizedBox(height: VeloxSpacing.lg),
              ...paymentMethods.map((method) => _PaymentMethodTile(
                    method: method,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.read<OrderBloc>().add(
                            OrderCheckoutRequested(
                              tradeNo: tradeNo,
                              method: method.id?.toString() ?? '',
                            ),
                          );
                    },
                  )),
            ],
          ),
        ),
      ),
    ).then((_) {
      // 弹窗关闭后刷新订单列表
      context.read<OrderBloc>().add(OrderListRequested());
    });
  }

  void _handleCheckoutResponse(
    BuildContext context,
    CheckoutResponse response,
    AppLocalizations l10n,
  ) {
    if (response.type == '-1' || response.type == 'balance') {
      // 余额支付成功
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paymentSuccess),
          backgroundColor: VeloxColors.success,
        ),
      );
      context.read<OrderBloc>().add(OrderListRequested());
    } else if (response.data != null && response.data!.isNotEmpty) {
      // 跳转到支付链接
      _launchPaymentUrl(response.data!);
      // 刷新订单列表
      context.read<OrderBloc>().add(OrderListRequested());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paymentFailed),
          backgroundColor: VeloxColors.error,
        ),
      );
      context.read<OrderBloc>().add(OrderListRequested());
    }
  }

  Future<void> _launchPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final AppLocalizations l10n;
  final VoidCallback onPayPressed;

  const _OrderCard({
    required this.order,
    required this.l10n,
    required this.onPayPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: VeloxSpacing.md),
      decoration: BoxDecoration(
        color: VeloxColors.bgCard,
        borderRadius: BorderRadius.circular(VeloxRadius.lg),
        border: Border.all(
          color: VeloxColors.borderWithOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(VeloxSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 套餐名称和状态
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.plan?.name ?? 'Unknown Plan',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: VeloxColors.textPrimary,
                    ),
                  ),
                ),
                _StatusChip(status: order.orderStatus, l10n: l10n),
              ],
            ),
            const SizedBox(height: VeloxSpacing.sm),

            // 订单号
            Text(
              '${l10n.orderNo}: ${order.tradeNo ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 12,
                color: VeloxColors.textTertiary,
              ),
            ),
            const SizedBox(height: VeloxSpacing.md),

            // 周期和金额
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: VeloxColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      order.periodDisplay,
                      style: const TextStyle(
                        color: VeloxColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₽${order.totalAmountYuan.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: VeloxColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: VeloxSpacing.sm),

            // 创建时间
            Text(
              '${l10n.orderTime}: ${_formatDate(order.createDate)}',
              style: const TextStyle(
                fontSize: 12,
                color: VeloxColors.textTertiary,
              ),
            ),

            // 待支付订单的操作按钮
            if (order.isPending) ...[
              const SizedBox(height: VeloxSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _showCancelDialog(context, order.tradeNo!);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VeloxColors.error,
                        side: const BorderSide(color: VeloxColors.error),
                        padding: const EdgeInsets.symmetric(
                          vertical: VeloxSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VeloxRadius.sm),
                        ),
                      ),
                      child: Text(l10n.cancelOrder),
                    ),
                  ),
                  const SizedBox(width: VeloxSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onPayPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VeloxColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: VeloxSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VeloxRadius.sm),
                        ),
                      ),
                      child: Text(l10n.payNow),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  void _showCancelDialog(BuildContext context, String tradeNo) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VeloxColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VeloxRadius.lg),
        ),
        title: Text(
          l10n.cancelOrder,
          style: const TextStyle(color: VeloxColors.textPrimary),
        ),
        content: Text(
          l10n.cancelOrderConfirm,
          style: const TextStyle(color: VeloxColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.no,
              style: const TextStyle(color: VeloxColors.textTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<OrderBloc>().add(
                    OrderCancelRequested(tradeNo: tradeNo),
                  );
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VeloxColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final PaymentMethodModel method;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.onTap,
  });

  IconData _getPaymentIcon() {
    final payment = method.payment?.toLowerCase() ?? '';
    if (payment.contains('alipay')) return Icons.account_balance_wallet;
    if (payment.contains('wechat') || payment.contains('weixin')) {
      return Icons.chat_bubble;
    }
    if (payment.contains('stripe') || payment.contains('card')) {
      return Icons.credit_card;
    }
    if (payment.contains('balance')) return Icons.account_balance_wallet;
    if (payment.contains('paypal')) return Icons.payment;
    if (payment.contains('crypto') || payment.contains('usdt')) {
      return Icons.currency_bitcoin;
    }
    return Icons.payment;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: VeloxColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_getPaymentIcon(), color: VeloxColors.primary),
      ),
      title: Text(
        method.name ?? method.payment ?? 'Unknown',
        style: const TextStyle(
          color: VeloxColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: method.handlingFeePercent != null && method.handlingFeePercent! > 0
          ? Text(
              '+${method.handlingFeePercent}%',
              style: const TextStyle(
                color: VeloxColors.textTertiary,
                fontSize: 12,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        color: VeloxColors.textTertiary,
      ),
      onTap: onTap,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final OrderStatus status;
  final AppLocalizations l10n;

  const _StatusChip({required this.status, required this.l10n});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case OrderStatus.pending:
        color = VeloxColors.warning;
        text = l10n.pendingOrders;
        break;
      case OrderStatus.paid:
        color = VeloxColors.success;
        text = l10n.completedOrders;
        break;
      case OrderStatus.cancelled:
        color = VeloxColors.error;
        text = l10n.cancelledOrders;
        break;
      case OrderStatus.completed:
        color = VeloxColors.primary;
        text = l10n.completedOrders;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(VeloxRadius.sm),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
