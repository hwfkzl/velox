import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../core/services/remote_config_service.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../data/models/knowledge_model.dart';
import '../../../data/models/remote_config_model.dart';
import '../../../di/injection.dart';
import '../../../domain/repositories/ticket_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/shared/velox_app_bar.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  // OSS FAQ 优先；无数据时回退到 V2Board API
  final List<RemoteFaqItem> _ossFaq =
      RemoteConfigService.instance.faq;

  late Future<List<KnowledgeModel>> _apiFuture;

  @override
  void initState() {
    super.initState();
    // 只在 OSS FAQ 为空时才请求 API
    if (_ossFaq.isEmpty) {
      _apiFuture = getIt<TicketRepository>().getKnowledgeList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: VeloxAppBar(title: l10n.faq, showBackButton: true),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.velox.bgGradient),
        child: SafeArea(
          child: _ossFaq.isNotEmpty
              ? _buildOssFaqList(_ossFaq)
              : _buildApiFaqList(l10n),
        ),
      ),
    );
  }

  Widget _buildOssFaqList(List<RemoteFaqItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(VeloxSpacing.pagePadding),
      itemCount: items.length,
      itemBuilder: (context, i) => _OssFaqItem(item: items[i]),
    );
  }

  Widget _buildApiFaqList(AppLocalizations l10n) {
    return FutureBuilder<List<KnowledgeModel>>(
      future: _apiFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(color: context.velox.accent),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 48, color: context.velox.danger),
                const SizedBox(height: VeloxSpacing.md),
                Text(
                  l10n.serverError,
                  style: TextStyle(color: context.velox.text2),
                ),
                const SizedBox(height: VeloxSpacing.md),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _apiFuture =
                        getIt<TicketRepository>().getKnowledgeList();
                  }),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: context.velox.accent,
                      foregroundColor: Colors.white),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          );
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Center(
            child: Text(l10n.noFaqArticles,
                style: TextStyle(color: context.velox.text2)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(VeloxSpacing.pagePadding),
          itemCount: list.length,
          itemBuilder: (context, i) => _ApiFaqItem(article: list[i]),
        );
      },
    );
  }
}

// ─── OSS FAQ 条目 ──────────────────────────────────────────────────────────

class _OssFaqItem extends StatefulWidget {
  final RemoteFaqItem item;
  const _OssFaqItem({required this.item});

  @override
  State<_OssFaqItem> createState() => _OssFaqItemState();
}

class _OssFaqItemState extends State<_OssFaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Container(
      margin: const EdgeInsets.only(bottom: VeloxSpacing.sm),
      decoration: BoxDecoration(
        color: v.surfaceMid,
        borderRadius: BorderRadius.circular(VeloxRadius.md),
        border: Border.all(color: v.divider),
        boxShadow: v.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(VeloxSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: v.text1,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: v.text3,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && widget.item.answer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                VeloxSpacing.md,
                0,
                VeloxSpacing.md,
                VeloxSpacing.md,
              ),
              child: Text(
                widget.item.answer,
                style: TextStyle(
                  fontSize: 13,
                  color: v.text2,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── V2Board API FAQ 条目（回退用）────────────────────────────────────────

class _ApiFaqItem extends StatefulWidget {
  final KnowledgeModel article;
  const _ApiFaqItem({required this.article});

  @override
  State<_ApiFaqItem> createState() => _ApiFaqItemState();
}

class _ApiFaqItemState extends State<_ApiFaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Container(
      margin: const EdgeInsets.only(bottom: VeloxSpacing.sm),
      decoration: BoxDecoration(
        color: v.surfaceMid,
        borderRadius: BorderRadius.circular(VeloxRadius.md),
        border: Border.all(color: v.divider),
        boxShadow: v.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(VeloxSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.article.title ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: v.text1,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: v.text3,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && widget.article.body != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                VeloxSpacing.md,
                0,
                VeloxSpacing.md,
                VeloxSpacing.md,
              ),
              child: Html(
                data: widget.article.body!,
                style: {
                  'body': Style(
                    color: v.text2,
                    fontSize: FontSize(13),
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                },
              ),
            ),
        ],
      ),
    );
  }
}
