import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../widgets/velox/velox_scaffold.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/localized_error_mapper.dart';
import '../../../data/models/subscribe_model.dart';
import '../../../data/models/notice_model.dart';
import '../../../data/models/order_model.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/repositories/order_repository.dart';
import '../../../di/injection.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/subscription/subscription_bloc.dart';
import '../../blocs/order/order_bloc.dart';
import '../../blocs/user/user_bloc.dart';
import '../../widgets/shared/velox_card.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => SubscriptionBloc(
            userRepository: getIt<UserRepository>(),
          )..add(const SubscriptionLoadRequested()),
        ),
        BlocProvider(
          create: (context) => OrderBloc(
            orderRepository: getIt<OrderRepository>(),
          )..add(const OrderListRequested()), // 默认加载全部订单
        ),
      ],
      child: const _SubscriptionPageContent(),
    );
  }
}

class _SubscriptionPageContent extends StatefulWidget {
  const _SubscriptionPageContent();

  @override
  State<_SubscriptionPageContent> createState() => _SubscriptionPageContentState();
}

class _SubscriptionPageContentState extends State<_SubscriptionPageContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// iOS 上是否允许购买（由后端 ios_enable 控制）
  /// 非 iOS 平台默认 true；iOS 需等待预检完成
  bool _iosPurchaseEnabled = !Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (Platform.isIOS) _checkIosPurchase();
  }

  Future<void> _checkIosPurchase() async {
    try {
      final repo = getIt<OrderRepository>();
      final methods = await repo.getPaymentMethods();
      if (mounted) {
        setState(() => _iosPurchaseEnabled = methods.isNotEmpty);
      }
    } catch (_) {
      // 检测失败时保守隐藏购买入口
      if (mounted) setState(() => _iosPurchaseEnabled = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;

    return Scaffold(
      backgroundColor: v.bg0,
      body: VeloxScaffold(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, l10n, v),
              _buildTabBar(context, l10n, v),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _PlansTab(iosPurchaseEnabled: _iosPurchaseEnabled),
                    _OrdersTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(
      BuildContext context, AppLocalizations l10n, VeloxTokens v) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            l10n.purchaseSubscription,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: v.text1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(
      BuildContext context, AppLocalizations l10n, VeloxTokens v) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: v.surfaceMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: v.divider),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6BB5FF), Color(0xFF3B82F6)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: v.accent.withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        indicatorPadding: const EdgeInsets.all(3),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        // 关闭点击水波纹 + 悬停高亮 —— 否则选中时会闪一下"阴影"再淡出
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        labelColor: Colors.white,
        unselectedLabelColor: v.text3,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          Tab(text: l10n.choosePlan, height: 38),
          Tab(text: l10n.orders, height: 38),
        ],
      ),
    );
  }
}

/// 套餐 Tab
class _PlansTab extends StatelessWidget {
  final bool iosPurchaseEnabled;
  const _PlansTab({this.iosPurchaseEnabled = true});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<SubscriptionBloc, SubscriptionState>(
      builder: (context, state) {
        if (state.status == SubscriptionStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(
              color: VeloxColors.primary,
            ),
          );
        }

        if (state.status == SubscriptionStatus.error) {
          final errorMsg = state.errorMessage != null
              ? LocalizedErrorMapper.getLocalizedError(l10n, state.errorMessage!)
              : l10n.error;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  errorMsg,
                  style: const TextStyle(color: VeloxColors.error),
                ),
                const SizedBox(height: VeloxSpacing.md),
                ElevatedButton(
                  onPressed: () {
                    context.read<SubscriptionBloc>().add(
                          const SubscriptionLoadRequested(),
                        );
                  },
                  child: Text(l10n.retry),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<SubscriptionBloc>().add(
                  const SubscriptionRefreshRequested(),
                );
          },
          color: VeloxColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(VeloxSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 计费周期选择
                _buildBillingCycleSelector(context, state, l10n),
                const SizedBox(height: VeloxSpacing.lg),

                // 套餐列表
                _buildPlansList(context, state, l10n, iosPurchaseEnabled: iosPurchaseEnabled),
                const SizedBox(height: VeloxSpacing.xxl),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentSubscription(BuildContext context, AppLocalizations l10n) {
    return BlocBuilder<UserBloc, UserState>(
      builder: (context, state) {
        if (state is! UserLoaded) {
          return const SizedBox.shrink();
        }

        final subscribe = state.subscribe;
        if (subscribe == null || subscribe.plan == null) {
          return const SizedBox.shrink();
        }

        final usagePercent = subscribe.usagePercent;

        return VeloxCard(
          child: Padding(
            padding: const EdgeInsets.all(VeloxSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscribe.plan!.name ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: VeloxColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subscribe.expiredAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatExpireDate(subscribe.expiredAt!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: VeloxColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: VeloxSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: usagePercent / 100,
                    minHeight: 8,
                    backgroundColor: VeloxColors.bgCardWithOpacity(0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      usagePercent > 80
                          ? VeloxColors.error
                          : usagePercent > 50
                              ? VeloxColors.warning
                              : VeloxColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: VeloxSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '已用 ${_formatBytes(subscribe.usedTraffic)} / 共计 ${_formatBytes(subscribe.transferEnable ?? 0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: VeloxColors.textTertiary,
                      ),
                    ),
                    Text(
                      '${usagePercent.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: VeloxColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatExpireDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildBillingCycleSelector(
    BuildContext context,
    SubscriptionState state,
    AppLocalizations l10n,
  ) {
    final cycles = [
      (BillingCycle.monthly, l10n.monthly, null),
      (BillingCycle.quarterly, l10n.quarterly, null),
      (BillingCycle.halfYearly, l10n.halfYearly, null),
      (BillingCycle.yearly, l10n.yearly, null),
      (BillingCycle.oneTime, l10n.oneTime, null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.billingCycle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.velox.text1,
          ),
        ),
        const SizedBox(height: VeloxSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: cycles.map((cycle) {
              final isSelected = state.selectedCycle == cycle.$1;
              return Padding(
                padding: const EdgeInsets.only(right: VeloxSpacing.sm),
                child: _BillingCycleChip(
                  label: cycle.$2,
                  savePercent: cycle.$3,
                  isSelected: isSelected,
                  onTap: () {
                    context.read<SubscriptionBloc>().add(
                          SubscriptionBillingCycleChanged(cycle.$1),
                        );
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPlansList(
    BuildContext context,
    SubscriptionState state,
    AppLocalizations l10n, {
    bool iosPurchaseEnabled = true,
  }) {
    if (state.plans.isEmpty) {
      return Center(
        child: Text(
          l10n.noData,
          style: const TextStyle(color: VeloxColors.textTertiary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.choosePlan,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.velox.text1,
          ),
        ),
        const SizedBox(height: VeloxSpacing.sm),
        ...state.plans.map((plan) => Padding(
              padding: const EdgeInsets.only(bottom: VeloxSpacing.md),
              child: _PlanCard(
                plan: plan,
                billingCycle: state.selectedCycle,
                isSelected: state.selectedPlan?.id == plan.id,
                onTap: () {
                  context.read<SubscriptionBloc>().add(
                        SubscriptionPlanSelected(plan),
                      );
                },
                onPurchase: iosPurchaseEnabled
                    ? () => _showPaymentMethodSheet(
                          context,
                          plan,
                          state.selectedCycle,
                        )
                    : null,
              ),
            )),
      ],
    );
  }

  void _showPaymentMethodSheet(
    BuildContext context,
    PlanModel plan,
    BillingCycle cycle,
  ) {
    final orderBloc = context.read<OrderBloc>();

    // 先获取支付方式
    orderBloc.add(PaymentMethodsRequested(tradeNo: ''));

    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      isScrollControlled: true,
      backgroundColor: const Color(0xFF050E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => BlocProvider.value(
        value: orderBloc,
        child: _PaymentMethodSheet(
          plan: plan,
          cycle: cycle,
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

/// 支付方式选择弹窗
class _PaymentMethodSheet extends StatefulWidget {
  final PlanModel plan;
  final BillingCycle cycle;

  const _PaymentMethodSheet({
    required this.plan,
    required this.cycle,
  });

  @override
  State<_PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<_PaymentMethodSheet> {
  bool _isCreatingOrder = false;

  String get _periodString {
    switch (widget.cycle) {
      case BillingCycle.monthly:
        return 'month_price';
      case BillingCycle.quarterly:
        return 'quarter_price';
      case BillingCycle.halfYearly:
        return 'half_year_price';
      case BillingCycle.yearly:
        return 'year_price';
      case BillingCycle.oneTime:
        return 'onetime_price';
    }
  }

  int? get _price {
    switch (widget.cycle) {
      case BillingCycle.monthly:
        return widget.plan.monthPrice;
      case BillingCycle.quarterly:
        return widget.plan.quarterPrice;
      case BillingCycle.halfYearly:
        return widget.plan.halfYearPrice;
      case BillingCycle.yearly:
        return widget.plan.yearPrice;
      case BillingCycle.oneTime:
        return widget.plan.onetimePrice;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;

    return BlocConsumer<OrderBloc, OrderState>(
      listener: (context, state) async {
        if (state is OrderCreated) {
          if (mounted) setState(() => _isCreatingOrder = false);
        } else if (state is OrderCheckoutReady) {
          Navigator.pop(context);
          final url = state.response.data;
          if (url != null && url.isNotEmpty) {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        } else if (state is OrderError) {
          if (mounted) setState(() => _isCreatingOrder = false);
          final localizedMsg =
              LocalizedErrorMapper.getLocalizedError(l10n, state.message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizedMsg),
              backgroundColor: v.danger,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is OrderLoading || _isCreatingOrder;
        List<PaymentMethodModel> paymentMethods = [];
        if (state is PaymentMethodsLoaded) {
          paymentMethods = state.paymentMethods;
        }

        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
            decoration: BoxDecoration(
              gradient: v.bgGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // grab handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: v.text3.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.selectPaymentMethod,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: v.text1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Order summary glass card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: v.surfaceMid,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: v.divider),
                      boxShadow: [
                        BoxShadow(
                          color: v.accent.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.plan.name ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: v.text1,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _getCycleName(context),
                                style: TextStyle(
                                    fontSize: 12, color: v.text3),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyUtils.formatPrice(_price ?? 0),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: v.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (isLoading && paymentMethods.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: v.accent),
                    ),
                  )
                else if (paymentMethods.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.noPaymentMethods,
                        style: TextStyle(color: v.text3),
                      ),
                    ),
                  )
                else
                  ...paymentMethods.map(
                    (method) => Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                      child: _PaymentMethodTile(
                        method: method,
                        isLoading: isLoading,
                        onTap: () => _handlePayment(context, method),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getCycleName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.cycle) {
      case BillingCycle.monthly:
        return l10n.monthly;
      case BillingCycle.quarterly:
        return l10n.quarterly;
      case BillingCycle.halfYearly:
        return l10n.halfYearly;
      case BillingCycle.yearly:
        return l10n.yearly;
      case BillingCycle.oneTime:
        return l10n.oneTime;
    }
  }

  void _handlePayment(BuildContext context, PaymentMethodModel method) {
    setState(() => _isCreatingOrder = true);

    // 创建订单并立即支付
    context.read<OrderBloc>().add(
          OrderCreateAndCheckout(
            planId: widget.plan.id!,
            period: _periodString,
            methodId: method.id!,
          ),
        );
  }
}

/// 支付方式选项
class _PaymentMethodTile extends StatefulWidget {
  final PaymentMethodModel method;
  final bool isLoading;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.method,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_PaymentMethodTile> createState() => _PaymentMethodTileState();
}

class _PaymentMethodTileState extends State<_PaymentMethodTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final disabled = widget.isLoading;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:
          disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel:
          disabled ? null : () => setState(() => _pressed = false),
      onTap: disabled ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed
              ? v.accent.withValues(alpha: 0.14)
              : v.surfaceMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _pressed
                ? v.accent.withValues(alpha: 0.45)
                : v.divider,
            width: _pressed ? 1.3 : 1,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: v.accent.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: v.accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.payment_rounded,
                  color: v.accent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.method.name ?? widget.method.payment ?? '',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: v.text1,
                ),
              ),
            ),
            if (widget.isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: v.accent,
                ),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  color: v.text4, size: 18),
          ],
        ),
      ),
    );
  }
}

/// 订单 Tab
class _OrdersTab extends StatefulWidget {
  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  bool _showAllOrders = true; // 默认显示全部订单
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    final state = context.read<OrderBloc>().state;
    if (state is OrderListLoaded && state.hasMore) {
      context.read<OrderBloc>().add(OrderListRequested(
            status: _showAllOrders ? null : 0,
            page: state.currentPage + 1,
            loadMore: true,
          ));
    }
  }

  void _switchFilter(bool showAll) {
    if (_showAllOrders != showAll) {
      setState(() => _showAllOrders = showAll);
      // 切换筛选时重新加载
      context.read<OrderBloc>().add(OrderListRequested(
            status: showAll ? null : 0,
            page: 1,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<OrderBloc, OrderState>(
      listener: (context, state) async {
        if (state is OrderCancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.success),
              backgroundColor: VeloxColors.success,
            ),
          );
          context.read<OrderBloc>().add(OrderListRequested(
                status: _showAllOrders ? null : 0,
              ));
        } else if (state is OrderCheckoutReady) {
          final url = state.response.data;
          if (url != null && url.isNotEmpty) {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        } else if (state is OrderError) {
          final localizedMsg = LocalizedErrorMapper.getLocalizedError(l10n, state.message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizedMsg),
              backgroundColor: VeloxColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is OrderLoading) {
          return Column(
            children: [
              _buildFilterBar(l10n),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: VeloxColors.primary,
                  ),
                ),
              ),
            ],
          );
        }

        if (state is OrderError) {
          final localizedMsg = LocalizedErrorMapper.getLocalizedError(l10n, state.message);
          return Column(
            children: [
              _buildFilterBar(l10n),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: VeloxColors.error.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: VeloxSpacing.md),
                      Text(
                        localizedMsg,
                        style: const TextStyle(color: VeloxColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: VeloxSpacing.md),
                      ElevatedButton(
                        onPressed: () {
                          context.read<OrderBloc>().add(OrderListRequested(
                                status: _showAllOrders ? null : 0,
                              ));
                        },
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // 获取当前订单列表
        List<OrderModel> orders = [];
        bool hasMore = false;
        bool isLoadingMore = false;

        if (state is OrderListLoaded) {
          orders = state.orders;
          hasMore = state.hasMore;
        } else if (state is OrderLoadingMore) {
          orders = state.currentOrders;
          isLoadingMore = true;
          hasMore = true;
        }

        if (orders.isEmpty) {
          return Column(
            children: [
              _buildFilterBar(l10n),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: VeloxColors.textTertiary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: VeloxSpacing.md),
                      Text(
                        l10n.noData,
                        style: const TextStyle(color: VeloxColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildFilterBar(l10n),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  context.read<OrderBloc>().add(OrderListRequested(
                        status: _showAllOrders ? null : 0,
                      ));
                },
                color: VeloxColors.primary,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(VeloxSpacing.pagePadding),
                  itemCount: orders.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == orders.length) {
                      // 加载更多指示器
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: VeloxSpacing.md),
                        child: Center(
                          child: isLoadingMore
                              ? const CircularProgressIndicator(
                                  color: VeloxColors.primary,
                                  strokeWidth: 2,
                                )
                              : TextButton(
                                  onPressed: _loadMore,
                                  child: Text(l10n.more),
                                ),
                        ),
                      );
                    }
                    final order = orders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: VeloxSpacing.sm),
                      child: _OrderCard(order: order),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VeloxSpacing.pagePadding,
        vertical: VeloxSpacing.sm,
      ),
      child: Row(
        children: [
          _FilterChip(
            label: l10n.pendingOrders,
            isSelected: !_showAllOrders,
            onTap: () => _switchFilter(false),
          ),
          const SizedBox(width: VeloxSpacing.sm),
          _FilterChip(
            label: l10n.all,
            isSelected: _showAllOrders,
            onTap: () => _switchFilter(true),
          ),
        ],
      ),
    );
  }
}

/// 订单卡片
class _OrderCard extends StatelessWidget {
  final OrderModel order;

  const _OrderCard({
    required this.order,
  });

  /// 获取状态颜色 — pulled from VeloxTokens at build time.
  Color _getStatusColor(VeloxTokens v) {
    switch (order.orderStatus) {
      case OrderStatus.pending:
        return v.warning;
      case OrderStatus.paid:
        return v.success;
      case OrderStatus.cancelled:
        return v.danger;
      case OrderStatus.completed:
        return v.accent;
    }
  }

  /// 获取状态文字
  String _getStatusText(AppLocalizations l10n) {
    switch (order.orderStatus) {
      case OrderStatus.pending:
        return l10n.pendingPayment;
      case OrderStatus.paid:
        return l10n.paid;
      case OrderStatus.cancelled:
        return l10n.cancelledOrders;
      case OrderStatus.completed:
        return l10n.completedOrders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;
    final statusColor = _getStatusColor(v);
    final isPending = order.isPending;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: v.surfaceMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: v.divider),
        boxShadow: [
          BoxShadow(
            color: v.accent.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  order.plan?.name ?? l10n.unknownPlan,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: v.text1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  _getStatusText(l10n),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.formattedDate,
                style: TextStyle(fontSize: 12, color: v.text3),
              ),
              Text(
                CurrencyUtils.formatPrice(order.totalAmount ?? 0),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: v.accent,
                ),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _OrderActionButton(
                    label: l10n.cancelOrder,
                    variant: _OrderBtnVariant.danger,
                    onTap: () => _showCancelConfirm(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OrderActionButton(
                    label: l10n.payNow,
                    variant: _OrderBtnVariant.accent,
                    onTap: () => _showPaymentMethods(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showCancelConfirm(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VeloxColors.bgCard,
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
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<OrderBloc>().add(
                    OrderCancelRequested(tradeNo: order.tradeNo!),
                  );
            },
            style: TextButton.styleFrom(foregroundColor: VeloxColors.error),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethods(BuildContext context) {
    final orderBloc = context.read<OrderBloc>();

    orderBloc.add(PaymentMethodsRequested(tradeNo: order.tradeNo!));

    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      backgroundColor: const Color(0xFF050E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => BlocProvider.value(
        value: orderBloc,
        child: _OrderPaymentSheet(order: order),
      ),
    );
  }
}

/// 订单支付弹窗
class _OrderPaymentSheet extends StatelessWidget {
  final OrderModel order;

  const _OrderPaymentSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;

    return BlocBuilder<OrderBloc, OrderState>(
      builder: (context, state) {
        List<PaymentMethodModel> paymentMethods = [];
        final isLoading = state is OrderLoading || state is OrderCheckingOut;

        if (state is PaymentMethodsLoaded) {
          paymentMethods = state.paymentMethods;
        }

        return Container(
          padding: const EdgeInsets.all(VeloxSpacing.pagePadding),
          decoration: BoxDecoration(
            gradient: v.bgGradient,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: VeloxSpacing.md),
                  decoration: BoxDecoration(
                    color: v.text4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.selectPaymentMethod,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: v.text1,
                ),
              ),
              const SizedBox(height: VeloxSpacing.lg),
              if (isLoading && paymentMethods.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(VeloxSpacing.xl),
                    child: CircularProgressIndicator(
                      color: v.accent,
                    ),
                  ),
                )
              else if (paymentMethods.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(VeloxSpacing.xl),
                    child: Text(
                      l10n.noPaymentMethods,
                      style: TextStyle(
                        color: v.text3,
                      ),
                    ),
                  ),
                )
              else
                ...paymentMethods.map((method) => Padding(
                      padding: const EdgeInsets.only(bottom: VeloxSpacing.sm),
                      child: _PaymentMethodTile(
                        method: method,
                        isLoading: isLoading,
                        onTap: () {
                          context.read<OrderBloc>().add(
                                OrderCheckoutRequested(
                                  tradeNo: order.tradeNo!,
                                  method: method.id?.toString() ?? '',
                                ),
                              );
                        },
                      ),
                    )),
              const SizedBox(height: VeloxSpacing.md),
            ],
          ),
        );
      },
    );
  }
}

/// 公告/教程 Tab
class _AnnouncementsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<SubscriptionBloc, SubscriptionState>(
      builder: (context, state) {
        if (state.status == SubscriptionStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(
              color: VeloxColors.primary,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<SubscriptionBloc>().add(
                  const SubscriptionRefreshRequested(),
                );
          },
          color: VeloxColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(VeloxSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 公告
                if (state.notices.isNotEmpty) ...[
                  _buildSectionHeader(
                    Icons.campaign_outlined,
                    l10n.announcements,
                    VeloxColors.warning,
                  ),
                  const SizedBox(height: VeloxSpacing.sm),
                  ...state.notices.map((notice) => Padding(
                        padding: const EdgeInsets.only(bottom: VeloxSpacing.sm),
                        child: _AnnouncementCard(notice: notice),
                      )),
                  const SizedBox(height: VeloxSpacing.lg),
                ],


                // 联系支持
                const SizedBox(height: VeloxSpacing.lg),
                _buildContactSection(context, l10n),
                const SizedBox(height: VeloxSpacing.xxl),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: VeloxSpacing.sm),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: VeloxColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          Icons.support_agent,
          l10n.contactSupport,
          VeloxColors.success,
        ),
        const SizedBox(height: VeloxSpacing.sm),
        _ContactButton(
          icon: Icons.support_agent,
          label: l10n.customerService,
          color: VeloxColors.primary,
          onTap: () => context.push('/support'),
        ),
      ],
    );
  }
}

/// 公告卡片
class _AnnouncementCard extends StatelessWidget {
  final NoticeModel notice;

  const _AnnouncementCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    return VeloxCard(
      child: Padding(
        padding: const EdgeInsets.all(VeloxSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    notice.title ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: VeloxColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  notice.formattedDate,
                  style: const TextStyle(
                    fontSize: 12,
                    color: VeloxColors.textTertiary,
                  ),
                ),
              ],
            ),
            if (notice.content != null && notice.content!.isNotEmpty) ...[
              const SizedBox(height: VeloxSpacing.sm),
              Html(
                data: notice.contentHtml,
                style: {
                  'body': Style(
                    color: context.velox.text2,
                    fontSize: FontSize(13),
                    lineHeight: LineHeight(1.5),
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                  'a': Style(color: context.velox.accent),
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 计费周期选择按钮
class _BillingCycleChip extends StatelessWidget {
  final String label;
  final int? savePercent;
  final bool isSelected;
  final VoidCallback onTap;

  const _BillingCycleChip({
    required this.label,
    this.savePercent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6BB5FF), Color(0xFF3B82F6)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [v.surfaceMid, v.surfaceMid],
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : v.divider,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: v.accent.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : v.text1,
              ),
            ),
            if (savePercent != null) ...[
              const SizedBox(height: 2),
              Text(
                '-$savePercent%',
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.85)
                      : v.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 套餐卡片
class _PlanCard extends StatelessWidget {
  final PlanModel plan;
  final BillingCycle billingCycle;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onPurchase;

  const _PlanCard({
    required this.plan,
    required this.billingCycle,
    required this.isSelected,
    required this.onTap,
    this.onPurchase,
  });

  int? get _price {
    switch (billingCycle) {
      case BillingCycle.monthly:
        return plan.monthPrice;
      case BillingCycle.quarterly:
        return plan.quarterPrice;
      case BillingCycle.halfYearly:
        return plan.halfYearPrice;
      case BillingCycle.yearly:
        return plan.yearPrice;
      case BillingCycle.oneTime:
        return plan.onetimePrice;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final price = _price;

    if (price == null || price == 0) {
      return const SizedBox.shrink();
    }

    final v = context.velox;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: v.surfaceMid,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? v.accent.withValues(alpha: 0.55)
                : v.divider,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: v.accent.withValues(alpha: 0.24),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: v.accent.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: v.text1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _FeatureTag(
                              icon: Icons.data_usage,
                              label: '${plan.transferEnable ?? 0} GB',
                            ),
                            if (plan.speedLimit != null && plan.speedLimit! > 0)
                              _FeatureTag(
                                icon: Icons.speed,
                                label: '${plan.speedLimit} Mbps',
                              )
                            else
                              _FeatureTag(
                                icon: Icons.speed,
                                label: l10n.noSpeedLimit,
                                color: v.accent,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyUtils.formatPrice(price),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: v.accent,
                        ),
                      ),
                      Text(
                        '/${_getCycleShortName(context)}',
                        style: TextStyle(fontSize: 11, color: v.text3),
                      ),
                    ],
                  ),
                ],
              ),
              if (plan.content != null && plan.content!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _PlanFeatureList(content: plan.content!),
              ],
              if (onPurchase != null) ...[
                const SizedBox(height: 12),
                _PurchaseButton(
                  label: l10n.selectThisPlan,
                  filled: isSelected,
                  onTap: onPurchase!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getCycleShortName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (billingCycle) {
      case BillingCycle.monthly:
        return l10n.monthly;
      case BillingCycle.quarterly:
        return l10n.quarterly;
      case BillingCycle.halfYearly:
        return l10n.halfYearly;
      case BillingCycle.yearly:
        return l10n.yearly;
      case BillingCycle.oneTime:
        return l10n.oneTime;
    }
  }
}

/// 筛选标签
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6BB5FF), Color(0xFF3B82F6)],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [v.surfaceMid, v.surfaceMid],
                ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.transparent : v.divider,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: v.accent.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : v.text2,
          ),
        ),
      ),
    );
  }
}

/// 特性标签
class _FeatureTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _FeatureTag({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tagColor = color ?? context.velox.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(VeloxRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: tagColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: tagColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 联系按钮
class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(VeloxSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(VeloxRadius.md),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: VeloxSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 套餐特性条目 —— text 为描述，supported 表示该特性是否包含。
class _PlanFeature {
  final String text;
  final bool supported;
  const _PlanFeature(this.text, this.supported);
}

/// 解析套餐 content 并逐条渲染为带图标的行。
///
/// V2Board 后端 plan.content 是自由文本字段，格式不统一，需同时兼容：
///   1. JSON 数组：[{"feature": "每月300G流量", "support": true}, ...]
///   2. HTML 列表：<ul><li>...</li></ul>
///   3. 纯文本
class _PlanFeatureList extends StatelessWidget {
  final String content;
  const _PlanFeatureList({required this.content});

  static final _liRegExp = RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true);
  static final _tagRegExp = RegExp(r'<[^>]+>');
  static final _prefixRegExp = RegExp(r'^[✔✅✓✕✗✘×•·★☆\-]\s*');

  static String _stripPrefix(String text) =>
      text.replaceFirst(_prefixRegExp, '').trim();

  List<_PlanFeature> _parseItems() {
    final raw = content.trim();

    // 1) V2Board JSON 数组格式：[{"feature": "...", "support": true}, ...]
    if (raw.startsWith('[')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final items = <_PlanFeature>[];
          for (final e in decoded) {
            if (e is Map) {
              final text = (e['feature'] ?? e['name'] ?? e['title'] ?? '')
                  .toString()
                  .trim();
              if (text.isEmpty) continue;
              final support = e['support'];
              final supported =
                  support == null || support == true || support == 1;
              items.add(_PlanFeature(text, supported));
            } else if (e is String && e.trim().isNotEmpty) {
              items.add(_PlanFeature(e.trim(), true));
            }
          }
          if (items.isNotEmpty) return items;
        }
      } catch (_) {
        // 非法 JSON —— 落到下面的 HTML / 纯文本分支
      }
    }

    // 2) HTML <li> 列表
    final htmlItems = <_PlanFeature>[];
    for (final m in _liRegExp.allMatches(raw)) {
      final text = m.group(1)!.replaceAll(_tagRegExp, '').trim();
      if (text.isNotEmpty) htmlItems.add(_PlanFeature(_stripPrefix(text), true));
    }
    if (htmlItems.isNotEmpty) return htmlItems;

    // 3) 纯文本回退（去除残留标签）
    final plain = raw.replaceAll(_tagRegExp, '').trim();
    if (plain.isNotEmpty) return [_PlanFeature(plain, true)];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final items = _parseItems();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  item.supported
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 15,
                  color: item.supported ? v.success : v.text4,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: item.supported ? v.text2 : v.text4,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}


/// Glass "Select plan" button — translucent surface + accent border/text,
/// press-aware (accent-tinted glass highlight on press).
class _PurchaseButton extends StatefulWidget {
  const _PurchaseButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  State<_PurchaseButton> createState() => _PurchaseButtonState();
}

class _PurchaseButtonState extends State<_PurchaseButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: _pressed
              ? v.accent.withValues(alpha: 0.14)
              : v.surfaceMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: v.accent.withValues(alpha: _pressed ? 0.60 : 0.30),
            width: 1,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: v.accent.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : v.cardShadow,
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: v.accent,
            ),
          ),
        ),
      ),
    );
  }
}


enum _OrderBtnVariant { accent, danger }

/// Press-aware order action button — glass surface with accent/danger
/// tint on border + text (accent = pay now, danger = cancel).
class _OrderActionButton extends StatefulWidget {
  const _OrderActionButton({
    required this.label,
    required this.variant,
    required this.onTap,
  });

  final String label;
  final _OrderBtnVariant variant;
  final VoidCallback onTap;

  @override
  State<_OrderActionButton> createState() => _OrderActionButtonState();
}

class _OrderActionButtonState extends State<_OrderActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final tint =
        widget.variant == _OrderBtnVariant.accent ? v.accent : v.danger;

    final bg = _pressed ? tint.withValues(alpha: 0.14) : v.surfaceMid;
    final fg = tint;
    final borderColor = tint.withValues(alpha: _pressed ? 0.60 : 0.30);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: tint.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : v.cardShadow,
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
