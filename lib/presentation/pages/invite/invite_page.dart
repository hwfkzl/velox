import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/services/remote_config_service.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/invite/invite_bloc.dart';
import '../../widgets/velox/velox_back_button.dart';
import '../../widgets/velox/velox_scaffold.dart';

class InvitePage extends StatelessWidget {
  const InvitePage({super.key});

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Scaffold(
      backgroundColor: v.bg0,
      body: VeloxScaffold(
        child: SafeArea(
          child: Column(
            children: [
              _InviteAppBar(),
              Expanded(
                child: BlocBuilder<InviteBloc, InviteState>(
                  builder: (context, state) {
                    if (state is InviteLoading || state is InviteGenerating) {
                      return Center(
                        child: CircularProgressIndicator(color: v.accent),
                      );
                    }
                    if (state is InviteError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(state.message,
                                style: TextStyle(color: v.text3)),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => context
                                  .read<InviteBloc>()
                                  .add(InviteLoadRequested()),
                              child: Text(
                                AppLocalizations.of(context)!.retry,
                                style: TextStyle(color: v.accent),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    if (state is InviteLoaded) {
                      return _InviteContent(state: state);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VeloxSpacing.lg,
        vertical: VeloxSpacing.md,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            AppLocalizations.of(context)!.inviteFriends,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: v.text1,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const VeloxBackButton(),
              _InviteRecordsButton(
                onTap: () => context.push('/invite-records'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteContent extends StatelessWidget {
  final InviteLoaded state;
  const _InviteContent({required this.state});

  String _buildInviteUrl(String? code) {
    if (code == null || code.isEmpty) return '';
    final base = RemoteConfigService.instance.inviteBaseUrl;
    if (base.isNotEmpty) return '$base$code';
    final apiBase = RemoteConfigService.instance.apiBaseUrl;
    return '$apiBase/#/register?code=$code';
  }

  @override
  Widget build(BuildContext context) {
    final inviteCode = state.inviteCode;
    final inviteUrl = _buildInviteUrl(inviteCode);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _QrCodeCard(inviteUrl: inviteUrl, inviteCode: inviteCode),
          const SizedBox(height: 10),
          _StatsCard(state: state),
          const SizedBox(height: 10),
          _CopyLinkButton(inviteUrl: inviteUrl),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// Glass QR code card.
class _QrCodeCard extends StatelessWidget {
  final String inviteUrl;
  final String? inviteCode;

  const _QrCodeCard({required this.inviteUrl, this.inviteCode});

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: v.surfaceMid,
        borderRadius: BorderRadius.circular(v.rSm),
        border: Border.all(color: v.divider),
        boxShadow: v.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: v.accent.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: inviteUrl.isNotEmpty
                ? _QrCodeWidget(data: inviteUrl)
                : Center(
                    child: Icon(Icons.qr_code_2,
                        size: 96, color: v.text4),
                  ),
          ),
          const SizedBox(height: 10),
          if (inviteCode != null && inviteCode!.isNotEmpty)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: inviteCode!));
                _showVeloxToast(context,
                    message: AppLocalizations.of(context)!.inviteCodeCopied,
                    icon: Icons.check_circle_rounded,
                    accent: true);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context)!.inviteCodeLabel(inviteCode!),
                    style: TextStyle(fontSize: 12, color: v.text2),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.copy_rounded, size: 12, color: v.text3),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QrCodeWidget extends StatelessWidget {
  final String data;
  const _QrCodeWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: 160,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(10),
    );
  }
}

/// 3-column stats block. Columns separated by thin blue dividers.
class _StatsCard extends StatelessWidget {
  final InviteLoaded state;
  const _StatsCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: v.surfaceMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: v.divider),
        boxShadow: v.cardShadow,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _StatColumn(
                label: l10n?.successfullyShared ?? 'Shared',
                value: '${state.registeredCount}',
                suffix: (l10n?.peopleSuffix ?? '').isEmpty
                    ? null
                    : l10n!.peopleSuffix,
                valueColor: v.text1,
              ),
            ),
            _VerticalSep(color: v.divider),
            Expanded(
              child: _StatColumn(
                label: l10n?.commissionEarned ?? 'Earned',
                value: '¥${state.commissionEarnedYuan.toStringAsFixed(2)}',
                suffix: null,
                valueColor: v.accent,
              ),
            ),
            _VerticalSep(color: v.divider),
            Expanded(
              child: _StatColumn(
                label: l10n?.commissionPending ?? 'Pending',
                value: '¥${state.commissionPendingYuan.toStringAsFixed(2)}',
                suffix: null,
                valueColor: v.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalSep extends StatelessWidget {
  const _VerticalSep({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: color, margin: const EdgeInsets.symmetric(vertical: 4));
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.suffix,
    required this.valueColor,
  });
  final String label;
  final String value;
  final String? suffix;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: v.text3,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(fontSize: 10, color: v.text3)),
      ],
    );
  }
}

/// Solid accent Copy button — press-aware.
class _CopyLinkButton extends StatefulWidget {
  final String inviteUrl;
  const _CopyLinkButton({required this.inviteUrl});

  @override
  State<_CopyLinkButton> createState() => _CopyLinkButtonState();
}

class _CopyLinkButtonState extends State<_CopyLinkButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final enabled = widget.inviteUrl.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled
          ? () {
              Clipboard.setData(ClipboardData(text: widget.inviteUrl));
              _showVeloxToast(context,
                  message: AppLocalizations.of(context)!.inviteLinkCopied,
                  icon: Icons.check_circle_rounded,
                  accent: true);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        height: 44,
        decoration: BoxDecoration(
          color: _pressed ? v.accent.withValues(alpha: 0.14) : v.surfaceMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? v.accent.withValues(alpha: _pressed ? 0.60 : 0.30)
                : v.divider,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_rounded,
                color: enabled ? v.accent : v.text4,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.copyInviteLink,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: enabled ? v.accent : v.text4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "邀请记录" chip — same press-blue feedback as the rest of the app.
class _InviteRecordsButton extends StatefulWidget {
  const _InviteRecordsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_InviteRecordsButton> createState() => _InviteRecordsButtonState();
}

class _InviteRecordsButtonState extends State<_InviteRecordsButton> {
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
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: VeloxSpacing.md),
        decoration: BoxDecoration(
          color: v.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _pressed ? v.accent.withValues(alpha: 0.6) : v.divider,
          ),
        ),
        child: Center(
          child: Text(
            AppLocalizations.of(context)?.inviteRecords ?? 'Invite Records',
            style: TextStyle(
              fontSize: 13,
              fontWeight: _pressed ? FontWeight.w600 : FontWeight.w500,
              color: _pressed ? v.accent : v.text2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared Velox toast — extracted as a free function so the invite page
/// can raise it without repeating the glass snackbar body.
void _showVeloxToast(
  BuildContext context, {
  required IconData icon,
  required String message,
  required bool accent,
}) {
  final v = context.velox;
  final tint = accent ? v.accent : v.danger;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    elevation: 0,
    backgroundColor: Colors.transparent,
    behavior: SnackBarBehavior.floating,
    padding: EdgeInsets.zero,
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    duration: const Duration(seconds: 2),
    content: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF14233D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: 20),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: v.text1,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  ));
}
