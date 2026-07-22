import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../core/theme/velox_spacing.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../data/models/notice_model.dart';
import '../../../di/injection.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/subscription/subscription_bloc.dart';
import '../../widgets/velox/velox_back_button.dart';
import '../../widgets/velox/velox_scaffold.dart';

class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SubscriptionBloc(
        userRepository: getIt<UserRepository>(),
      )..add(const SubscriptionLoadRequested()),
      child: const _AnnouncementsContent(),
    );
  }
}

class _AnnouncementsContent extends StatelessWidget {
  const _AnnouncementsContent();

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
              _TopBar(label: l10n.announcements),
              Expanded(
                child: BlocBuilder<SubscriptionBloc, SubscriptionState>(
                  builder: (context, state) {
                    if (state.status == SubscriptionStatus.loading &&
                        state.notices.isEmpty) {
                      return Center(
                        child: CircularProgressIndicator(color: v.accent),
                      );
                    }
                    if (state.notices.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.noAnnouncements,
                          style: TextStyle(color: v.text3),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => context
                          .read<SubscriptionBloc>()
                          .add(const SubscriptionRefreshRequested()),
                      color: v.accent,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(
                            VeloxSpacing.pagePadding),
                        itemCount: state.notices.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _NoticeCard(notice: state.notices[i]),
                      ),
                    );
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VeloxSpacing.pagePadding,
        vertical: VeloxSpacing.sm,
      ),
      child: Row(
        children: [
          const VeloxBackButton(),
          const SizedBox(width: VeloxSpacing.sm),
          Icon(Icons.campaign_outlined, color: v.accent, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
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
}

/// Expandable glass card. Click to toggle content visibility — matches the
/// preview.html Announcement component.
class _NoticeCard extends StatefulWidget {
  final NoticeModel notice;
  const _NoticeCard({required this.notice});

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard> {
  bool _expanded = false;

  bool get _hasContent =>
      widget.notice.content != null && widget.notice.content!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        // 深色玻璃公告卡片：克制的"展开"提示，不染色不闪
        //   - 折叠：白 5% 雾
        //   - 展开：略增白雾 + accent 微弱边框（不染色，不光晕）
        color: _expanded
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(v.rSm),
        border: Border.all(
          color: _expanded
              ? v.accent.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: null, // 列表卡片不要光晕，避免"闪"
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(v.rSm),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _hasContent
                ? () => setState(() => _expanded = !_expanded)
                : null,
            splashColor: v.accent.withValues(alpha: 0.08),
            highlightColor: v.accent.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.notice.title ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _expanded ? v.accent : v.text1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.notice.formattedDate,
                              style: TextStyle(fontSize: 12, color: v.text3),
                            ),
                          ],
                        ),
                      ),
                      if (_hasContent) ...[
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: Icon(
                            Icons.expand_more_rounded,
                            size: 20,
                            color: _expanded ? v.accent : v.text3,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_hasContent)
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 1,
                              color: v.divider,
                            ),
                            const SizedBox(height: 10),
                            Html(
                              data: widget.notice.contentHtml,
                              style: {
                                'body': Style(
                                  color: v.text2,
                                  fontSize: FontSize(13),
                                  lineHeight: LineHeight(1.55),
                                  margin: Margins.zero,
                                  padding: HtmlPaddings.zero,
                                ),
                                'a': Style(color: v.accent),
                              },
                            ),
                          ],
                        ),
                      ),
                      crossFadeState: _expanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 180),
                      sizeCurve: Curves.easeOut,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
