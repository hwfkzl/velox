import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/shared/velox_text_field.dart';
import '../../widgets/velox/velox_back_button.dart';
import '../../widgets/velox/velox_brand_tile.dart';
import '../../widgets/velox/velox_primary_button.dart';
import '../../widgets/velox/velox_scaffold.dart';
import '../../widgets/velox/velox_snack.dart';
import '../../widgets/velox/velox_text_link.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSending = false;
  bool _isLoading = false;
  bool _emailVerifyRequired = false;
  // 是否强制要求邀请码 —— 来自后端 /api/v1/guest/comm/config 的 is_invite_force,
  // ON 时 placeholder 切到"邀请码（必填）",空提交直接前端拦截。
  bool _inviteForce = false;

  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // 先读取当前已有状态（避免 BlocListener 不触发相同状态的问题）
    final currentState = context.read<AuthBloc>().state;
    if (currentState is AuthSiteConfigLoaded) {
      _emailVerifyRequired = currentState.emailVerifyRequired;
      _inviteForce = currentState.inviteForce;
    }
    // 再请求刷新（若状态变化则 listener 会更新）
    context.read<AuthBloc>().add(AuthSiteConfigRequested());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _sendVerificationCode() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showVeloxSnack(
        context,
        AppLocalizations.of(context)!.pleaseEnterValidEmail,
        isError: true,
      );
      return;
    }

    setState(() => _isSending = true);
    context.read<AuthBloc>().add(AuthSendCodeRequested(email: email));
    _startCountdown();
  }

  void _onRegister() {
    if (_formKey.currentState?.validate() ?? false) {
      // 后端 invite_force=ON 时,空邀请码前端先拦截,避免一次无效 RTT。
      // 后端同样会兜底(AuthController.php:115-119 abort "必须使用邀请码才可以注册"),
      // 这里前端拦截只是为了更快的反馈。
      if (_inviteForce && _inviteCodeController.text.trim().isEmpty) {
        showVeloxSnack(
          context,
          AppLocalizations.of(context)!.pleaseEnterInviteCode,
          isError: true,
        );
        return;
      }
      setState(() => _isLoading = true);
      context.read<AuthBloc>().add(
            AuthRegisterRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              emailCode: _emailVerifyRequired
                  ? _emailCodeController.text.trim()
                  : null,
              inviteCode: _inviteCodeController.text.trim().isEmpty
                  ? null
                  : _inviteCodeController.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthSiteConfigLoaded) {
          setState(() {
            _emailVerifyRequired = state.emailVerifyRequired;
            _inviteForce = state.inviteForce;
          });
        } else if (state is AuthError) {
          // 仅重置本页 loading 标志,错误 snack 由栈底的 login_page
          // 的 AuthError 监听统一渲染(已是玻璃态),避免双层 snack 重叠。
          setState(() {
            _isSending = false;
            _isLoading = false;
          });
        } else if (state is AuthCodeSent) {
          setState(() => _isSending = false);
          showVeloxSnack(context, l10n.verificationCodeSent);
        }
      },
      child: Scaffold(
        backgroundColor: v.bg0,
        body: VeloxScaffold(
          child: Stack(
            children: [
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 能装下 → 垂直居中;装不下(5 输入框)→ 自动滚动。
                    return SingleChildScrollView(
                      padding:
                          const EdgeInsets.all(VeloxSpacing.pagePadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight -
                              VeloxSpacing.pagePadding * 2,
                        ),
                        child: IntrinsicHeight(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Center(
                                  child: VeloxBrandTile(size: 56),
                                ),
                                const SizedBox(height: 14),

                        Text(
                          l10n.createAccount,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: v.text1,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.signUpToGetStarted,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: v.text3,
                          ),
                        ),

                        const SizedBox(height: VeloxSpacing.lg),

                        // 邮箱
                        VeloxTextField(
                          controller: _emailController,
                          hintText: l10n.email,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: VeloxColors.textTertiary,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.pleaseEnterEmail;
                            }
                            if (!value.contains('@')) {
                              return l10n.pleaseEnterValidEmail;
                            }
                            return null;
                          },
                        ),

                        // 验证码（仅在后端开启邮箱验证时显示）
                        if (_emailVerifyRequired) ...[
                          const SizedBox(height: VeloxSpacing.md),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: VeloxTextField(
                                  controller: _emailCodeController,
                                  hintText: l10n.verificationCode,
                                  keyboardType: TextInputType.number,
                                  prefixIcon: const Icon(
                                    Icons.verified_outlined,
                                    color: VeloxColors.textTertiary,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return l10n.pleaseEnterVerificationCode;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: VeloxSpacing.md),
                              _CodeButton(
                                label: _countdown > 0 ? '${_countdown}s' : l10n.sendCode,
                                loading: _isSending,
                                disabled: _countdown > 0 || _isSending,
                                onTap: _sendVerificationCode,
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: VeloxSpacing.md),

                        // 密码
                        VeloxTextField(
                          controller: _passwordController,
                          hintText: l10n.password,
                          obscureText: _obscurePassword,
                          prefixIcon: const Icon(
                            Icons.lock_outlined,
                            color: VeloxColors.textTertiary,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: VeloxColors.textTertiary,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.pleaseEnterPassword;
                            }
                            if (value.length < 6) {
                              return l10n.passwordTooShort;
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: VeloxSpacing.md),

                        // 确认密码
                        VeloxTextField(
                          controller: _confirmPasswordController,
                          hintText: l10n.confirmPassword,
                          obscureText: _obscureConfirmPassword,
                          prefixIcon: const Icon(
                            Icons.lock_outlined,
                            color: VeloxColors.textTertiary,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: VeloxColors.textTertiary,
                            ),
                            onPressed: () {
                              setState(() =>
                                  _obscureConfirmPassword = !_obscureConfirmPassword);
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.pleaseEnterPassword;
                            }
                            if (value != _passwordController.text) {
                              return l10n.passwordsDoNotMatch;
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: VeloxSpacing.md),

                        // 邀请码 —— 根据 invite_force 切换"必填"/"可选"
                        VeloxTextField(
                          controller: _inviteCodeController,
                          hintText: _inviteForce
                              ? l10n.inviteCodeRequired
                              : l10n.inviteCodeOptional,
                          prefixIcon: const Icon(
                            Icons.card_giftcard_outlined,
                            color: VeloxColors.textTertiary,
                          ),
                        ),

                        const SizedBox(height: VeloxSpacing.lg),

                        // 注册按钮
                        VeloxPrimaryButton(
                          label: l10n.register,
                          loading: _isLoading,
                          onTap: _isLoading ? null : _onRegister,
                        ),

                        const SizedBox(height: VeloxSpacing.md),

                        // 登录链接
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.hasAccount,
                              style: TextStyle(fontSize: 13, color: v.text2),
                            ),
                            VeloxTextLink(
                              label: l10n.login,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: VeloxBackButton(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _CodeButton extends StatefulWidget {
  const _CodeButton({
    required this.label,
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;

  @override
  State<_CodeButton> createState() => _CodeButtonState();
}

class _CodeButtonState extends State<_CodeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final off = widget.disabled;
    final fg = off ? v.text4 : v.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: off ? null : (_) => setState(() => _pressed = true),
      onTapUp: off ? null : (_) => setState(() => _pressed = false),
      onTapCancel: off ? null : () => setState(() => _pressed = false),
      onTap: off ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          // 与 VeloxPrimaryButton 同源:玻璃底 + accent 描边 + accent 文字
          color: _pressed
              ? v.accent.withValues(alpha: 0.14)
              : v.surfaceMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: off
                ? v.divider
                : v.accent.withValues(alpha: _pressed ? 0.60 : 0.30),
            width: 1,
          ),
          boxShadow: off
              ? null
              : (_pressed
                  ? [
                      BoxShadow(
                        color: v.accent.withValues(alpha: 0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : v.cardShadow),
        ),
        child: Center(
          child: widget.loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: v.accent,
                  ),
                )
              : Text(
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
