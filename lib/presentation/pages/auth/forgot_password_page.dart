import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../core/utils/localized_error_mapper.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/shared/velox_text_field.dart';
import '../../widgets/velox/velox_back_button.dart';
import '../../widgets/velox/velox_brand_tile.dart';
import '../../widgets/velox/velox_primary_button.dart';
import '../../widgets/velox/velox_scaffold.dart';
import '../../widgets/velox/velox_text_link.dart';
import '../../widgets/velox/velox_snack.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSending = false;
  bool _isLoading = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  void _sendCode() {
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

  void _onReset() {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showError(AppLocalizations.of(context)!.pleaseEnterValidEmail);
      return;
    }
    if (code.isEmpty) {
      _showError(AppLocalizations.of(context)!.pleaseEnterVerificationCode);
      return;
    }
    if (password.length < 6) {
      _showError(AppLocalizations.of(context)!.passwordTooShort);
      return;
    }
    if (password != confirm) {
      _showError(AppLocalizations.of(context)!.passwordsDoNotMatch);
      return;
    }

    setState(() => _isLoading = true);
    context.read<AuthBloc>().add(
          AuthForgotPasswordRequested(
            email: email,
            emailCode: code,
            password: password,
          ),
        );
  }

  void _showError(String msg) {
    showVeloxSnack(context, msg, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          setState(() {
            _isSending = false;
            _isLoading = false;
          });
          final msg = LocalizedErrorMapper.getLocalizedError(l10n, state.message);
          showVeloxSnack(context, msg, isError: true);
        } else if (state is AuthCodeSent) {
          setState(() => _isSending = false);
          showVeloxSnack(context, l10n.verificationCodeSent);
        } else if (state is AuthPasswordReset) {
          setState(() => _isLoading = false);
          showVeloxSnack(context, l10n.passwordResetSuccess);
          Navigator.of(context).pop();
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
                    // 能装下 → 垂直居中;装不下 → 自动滚动。
                    return SingleChildScrollView(
                      padding:
                          const EdgeInsets.all(VeloxSpacing.pagePadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight -
                              VeloxSpacing.pagePadding * 2,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Center(
                                child: VeloxBrandTile(size: 56),
                              ),
                              const SizedBox(height: 14),

                      Text(
                        l10n.forgotPassword,
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
                        l10n.resetPasswordSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: v.text3),
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
                      ),

                      const SizedBox(height: VeloxSpacing.lg),

                      // 验证码
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: VeloxTextField(
                              controller: _codeController,
                              hintText: l10n.verificationCode,
                              keyboardType: TextInputType.number,
                              prefixIcon: const Icon(
                                Icons.verified_outlined,
                                color: VeloxColors.textTertiary,
                              ),
                            ),
                          ),
                          const SizedBox(width: VeloxSpacing.md),
                          _CodeButton(
                            label: _countdown > 0 ? '${_countdown}s' : l10n.sendCode,
                            loading: _isSending,
                            disabled: _countdown > 0 || _isSending,
                            onTap: _sendCode,
                          ),
                        ],
                      ),

                      const SizedBox(height: VeloxSpacing.md),

                      // 新密码
                      VeloxTextField(
                        controller: _passwordController,
                        hintText: l10n.newPassword,
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
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),

                      const SizedBox(height: VeloxSpacing.lg),

                      // 确认新密码
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
                          onPressed: () => setState(
                              () => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),

                      const SizedBox(height: VeloxSpacing.lg),

                      // 重置按钮
                      VeloxPrimaryButton(
                        label: l10n.resetPassword,
                        loading: _isLoading,
                        onTap: _isLoading ? null : _onReset,
                      ),

                      const SizedBox(height: VeloxSpacing.md),

                      // 返回登录
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.rememberPassword,
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


/// Compact accent-pill "Send Code" button used in the verification flow.
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
