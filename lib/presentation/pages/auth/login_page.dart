import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'register_page.dart';
import 'forgot_password_page.dart';

import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../core/utils/localized_error_mapper.dart';
import '../../../app/brand.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/shared/velox_text_field.dart';
import '../../widgets/velox/velox_brand_tile.dart';
import '../../widgets/velox/velox_primary_button.dart';
import '../../widgets/velox/velox_text_link.dart';
import '../../widgets/velox/velox_scaffold.dart';
import '../../widgets/velox/velox_snack.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(
            AuthLoginRequested(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;

    return Scaffold(
      backgroundColor: v.bg0,
      body: VeloxScaffold(
        child: Stack(
          children: [
            // 主内容
            BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthError) {
                  final l10n = AppLocalizations.of(context)!;
                  final localizedMessage = LocalizedErrorMapper.getLocalizedError(
                    l10n,
                    state.message,
                  );
                  // 走全 app 统一的玻璃态 snackbar(红边 + info 图标)。
                  // veloxCode 非 null 时(基础设施错误)自动追加"（error:1003）"。
                  // veloxCode 为 null 时(V2Board 业务错误)只显示干净文案。
                  showVeloxSnack(
                    context,
                    localizedMessage,
                    isError: true,
                    code: state.veloxCode,
                  );
                }
              },
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 内容能装下 → 垂直居中;装不下 → 自动滚动。
                    // 不再写死顶部 72px,避免小窗口被撑出底部截断。
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(VeloxSpacing.pagePadding),
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
                                // Logo — glossy Velox brand tile(缩小到 64 适配 540 窗口)
                                const Center(child: VeloxBrandTile(size: 64)),
                                const SizedBox(height: 18),

                        // 标题
                        Text(
                          l10n.welcomeBack,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: v.text1,
                            letterSpacing: 0.2,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          Brand.brandize(l10n.loginToContinue),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: v.text3,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 26),

                        // 邮箱输入框
                        VeloxTextField(
                          controller: _emailController,
                          hintText: l10n.enterEmail,
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

                        const SizedBox(height: VeloxSpacing.lg),

                        // 密码输入框
                        VeloxTextField(
                          controller: _passwordController,
                          hintText: l10n.enterPassword,
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
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
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

                        const SizedBox(height: VeloxSpacing.sm),

                        // 忘记密码 —— tertiary text link
                        Align(
                          alignment: Alignment.centerRight,
                          child: VeloxTextLink(
                            label: l10n.forgotPassword,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<AuthBloc>(),
                                  child: const ForgotPasswordPage(),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: VeloxSpacing.xl),

                        // 登录按钮 — Velox 实心强调 + 蓝色浮起
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            final isLoading = state is AuthLoading;
                            return VeloxPrimaryButton(
                              label: l10n.login,
                              loading: isLoading,
                              onTap: isLoading ? null : _onLogin,
                            );
                          },
                        ),

                        const SizedBox(height: 18),

                        // 注册链接
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l10n.noAccount,
                              style: TextStyle(
                                fontSize: 13,
                                color: v.text2,
                              ),
                            ),
                            const SizedBox(width: 2),
                            VeloxTextLink(
                              label: l10n.registerNow,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<AuthBloc>(),
                                    child: const RegisterPage(),
                                  ),
                                ),
                              ),
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
            ),
          ],
        ),
      ),
    );
  }
}
