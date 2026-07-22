import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../data/models/invite_model.dart';
import '../../../di/injection.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/velox/velox_back_button.dart';
import '../../widgets/velox/velox_scaffold.dart';

class InviteRecordsPage extends StatefulWidget {
  const InviteRecordsPage({super.key});

  @override
  State<InviteRecordsPage> createState() => _InviteRecordsPageState();
}

class _InviteRecordsPageState extends State<InviteRecordsPage> {
  bool _loading = true;
  String? _error;
  List<InviteRecordModel> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final api = getIt<ApiClient>();
      final resp = await api.get(ApiConstants.inviteDetails);
      final data = resp.data['data'];
      if (!mounted) return;
      setState(() {
        _records = (data as List<dynamic>)
            .map((e) =>
                InviteRecordModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velox;

    return Scaffold(
      backgroundColor: v.bg0,
      body: VeloxScaffold(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(),
              Expanded(child: _buildBody(v)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(VeloxTokens v) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: v.accent));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: v.text3)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: Text(
                AppLocalizations.of(context)?.retry ?? 'Retry',
                style: TextStyle(color: v.accent),
              ),
            ),
          ],
        ),
      );
    }
    if (_records.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)?.noInviteRecords ?? 'No invite records',
          style: TextStyle(color: v.text3, fontSize: 14),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      color: v.accent,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _records.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _RecordItem(record: _records[i]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            AppLocalizations.of(context)?.inviteRecords ?? 'Invite Records',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: v.text1,
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: VeloxBackButton(),
          ),
        ],
      ),
    );
  }
}

class _RecordItem extends StatelessWidget {
  final InviteRecordModel record;
  const _RecordItem({required this.record});

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final l10n = AppLocalizations.of(context);

    final dt = record.createDate;
    final timeStr = dt == null
        ? ''
        : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    final tradeNo = record.tradeNo ?? '';
    final desc = l10n?.commissionReward ?? 'Commission';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: v.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.monetization_on_outlined,
                color: v.accent, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: v.text1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (tradeNo.isNotEmpty) '#$tradeNo',
                    if (timeStr.isNotEmpty) timeStr,
                  ].join('  ·  '),
                  style: TextStyle(fontSize: 11, color: v.text3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '+¥${record.getAmountYuan.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: v.accent,
            ),
          ),
        ],
      ),
    );
  }
}
