import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/remote_config_service.dart';
import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../data/models/ticket_model.dart';
import '../../../di/injection.dart';
import '../../../domain/repositories/ticket_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../blocs/ticket/ticket_bloc.dart';
import '../../widgets/shared/velox_app_bar.dart';
import '../../widgets/shared/velox_card.dart';

class HelpSupportPage extends StatefulWidget {
  final String? initialTab;
  final String? action;

  const HelpSupportPage({super.key, this.initialTab, this.action});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  bool _shouldShowNewTicketDialog = false;

  @override
  void initState() {
    super.initState();
    _shouldShowNewTicketDialog = widget.action == 'new';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocProvider(
      create: (context) =>
          TicketBloc(ticketRepository: getIt<TicketRepository>())
            ..add(TicketListRequested()),
      child: Builder(
        builder: (blocContext) {
          if (_shouldShowNewTicketDialog) {
            _shouldShowNewTicketDialog = false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showCreateTicketDialog(blocContext);
            });
          }

          return Container(
              decoration: BoxDecoration(
                gradient: context.velox.bgGradient,
              ),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: VeloxAppBar(
                title: l10n.myTickets,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add, color: VeloxColors.primary),
                    onPressed: () => _showCreateTicketDialog(blocContext),
                  ),
                ],
              ),
              body: const _TicketsTab(),
              ),
            );
        },
      ),
    );
  }

  void _showCreateTicketDialog(BuildContext parentContext) {
    final l10n = AppLocalizations.of(context)!;
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    int selectedLevel = 0;
    final List<_UploadedImage> uploadedImages = [];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF050E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            left: VeloxSpacing.pagePadding,
            right: VeloxSpacing.pagePadding,
            top: VeloxSpacing.lg,
            bottom:
                MediaQuery.of(context).viewInsets.bottom + VeloxSpacing.lg,
          ),
          decoration: BoxDecoration(
            gradient: context.velox.bgGradient,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: SingleChildScrollView(
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
                      color: context.velox.text4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  l10n.createNewTicket,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.velox.text1,
                  ),
                ),
                const SizedBox(height: VeloxSpacing.lg),
                TextField(
                  controller: subjectController,
                  style: TextStyle(color: context.velox.text1),
                  decoration: _inputDecoration(context, l10n.ticketSubject, l10n.ticketSubjectHint),
                ),
                const SizedBox(height: VeloxSpacing.lg),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  style: TextStyle(color: context.velox.text1),
                  decoration: _inputDecoration(context, l10n.ticketMessage, l10n.ticketMessageHint),
                ),
                const SizedBox(height: VeloxSpacing.lg),
                // 图片上传区域
                _ImagePickerRow(
                  images: uploadedImages,
                  onPickImage: () async {
                    await _pickAndUploadImage(
                      context: context,
                      images: uploadedImages,
                      onUpdate: () => setState(() {}),
                    );
                  },
                  onRemove: (index) => setState(() => uploadedImages.removeAt(index)),
                ),
                const SizedBox(height: VeloxSpacing.lg),
                Text(
                  l10n.priority,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.velox.text1,
                  ),
                ),
                const SizedBox(height: VeloxSpacing.sm),
                Row(
                  children: [
                    _PriorityButton(
                      label: l10n.priorityLow,
                      color: Colors.blue,
                      isSelected: selectedLevel == 0,
                      onTap: () => setState(() => selectedLevel = 0),
                    ),
                    const SizedBox(width: VeloxSpacing.sm),
                    _PriorityButton(
                      label: l10n.priorityMedium,
                      color: Colors.orange,
                      isSelected: selectedLevel == 1,
                      onTap: () => setState(() => selectedLevel = 1),
                    ),
                    const SizedBox(width: VeloxSpacing.sm),
                    _PriorityButton(
                      label: l10n.priorityHigh,
                      color: Colors.red,
                      isSelected: selectedLevel == 2,
                      onTap: () => setState(() => selectedLevel = 2),
                    ),
                  ],
                ),
                const SizedBox(height: VeloxSpacing.xl),
                _VeloxSubmitButton(
                  label: l10n.submitTicket,
                  onTap: () {
                    final subject = subjectController.text.trim();
                    final message = messageController.text.trim();
                    if (subject.isEmpty || message.isEmpty) return;

                    final images = uploadedImages
                        .where((img) => img.remoteId != null)
                        .map((img) => img.remoteId!)
                        .toList();

                    parentContext.read<TicketBloc>().add(
                          TicketCreateRequested(
                            subject: subject,
                            message: message,
                            level: selectedLevel,
                            images: images.isNotEmpty ? images : null,
                          ),
                        );
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(
    BuildContext context, String label, String hint) {
  final v = context.velox;
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: v.text3),
    hintText: hint,
    hintStyle: TextStyle(color: v.text4),
    filled: true,
    fillColor: v.surfaceMid,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(VeloxRadius.md),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(VeloxRadius.md),
      borderSide: BorderSide(color: v.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(VeloxRadius.md),
      borderSide: BorderSide(color: v.accent),
    ),
  );
}

// 上传图片：选择 → base64 → 调后端 → 存 remoteId
Future<void> _pickAndUploadImage({
  required BuildContext context,
  required List<_UploadedImage> images,
  required VoidCallback onUpdate,
}) async {
  if (images.length >= 4) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('最多上传 4 张图片')),
    );
    return;
  }

  final picker = ImagePicker();
  XFile? picked;
  try {
    picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1920,
      maxHeight: 1920,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开相册：$e')),
      );
    }
    return;
  }
  if (picked == null) return;

  final file = File(picked.path);
  final bytes = await file.readAsBytes();
  if (bytes.lengthInBytes > 1024 * 1024) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片大小不能超过 1MB')),
      );
    }
    return;
  }

  final ext = picked.name.split('.').last.toLowerCase();
  final mime = _mimeType(ext);
  final base64Data = base64Encode(bytes);
  final dataUri = 'data:$mime;base64,$base64Data';

  final placeholder = _UploadedImage(localFile: file, isUploading: true);
  images.add(placeholder);
  onUpdate();

  try {
    final repo = getIt<TicketRepository>();
    final remoteId = await repo.uploadImage(dataUri, picked.name);
    placeholder.remoteId = remoteId;
    placeholder.isUploading = false;
  } catch (e) {
    images.remove(placeholder);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败：$e')),
      );
    }
  }
  onUpdate();
}

String _mimeType(String ext) {
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    default:
      return 'image/png';
  }
}

/// 解码 base64url 得到原始 ImgBB URL
String _decodeImageUrl(String encoded) {
  try {
    String b64 = encoded.replaceAll('-', '+').replaceAll('_', '/');
    while (b64.length % 4 != 0) {
      b64 += '=';
    }
    return utf8.decode(base64Decode(b64));
  } catch (_) {
    // 解码失败时走后端重定向接口
    final base = RemoteConfigService.instance.apiBaseUrl;
    return '$base/api/v1/user/ticket/image/$encoded';
  }
}

class _UploadedImage {
  final File localFile;
  String? remoteId;
  bool isUploading;

  _UploadedImage({
    required this.localFile,
    this.remoteId,
    this.isUploading = false,
  });
}

class _ImagePickerRow extends StatelessWidget {
  final List<_UploadedImage> images;
  final VoidCallback onPickImage;
  final ValueChanged<int> onRemove;

  static const int _maxImages = 4;

  const _ImagePickerRow({
    required this.images,
    required this.onPickImage,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final canAddMore = images.length < _maxImages;
    // 已选缩略图数量 + (可加时的"+"按钮 = 1)
    final itemCount = images.length + (canAddMore ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              // 已选缩略图
              if (index < images.length) {
                final img = images[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          img.localFile,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (img.isUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!img.isUploading)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => onRemove(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }
              // 最后一格:"+" 添加按钮(accent 虚线框风格)
              return GestureDetector(
                onTap: onPickImage,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: v.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: v.accent.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: v.accent,
                      size: 26,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '添加截图(可选,最多 $_maxImages 张)',
          style: TextStyle(fontSize: 11, color: v.text3),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PriorityButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.18)
                : v.surfaceMid,
            borderRadius: BorderRadius.circular(VeloxRadius.md),
            border: Border.all(
              color: isSelected ? color : v.divider,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : v.text3,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketsTab extends StatelessWidget {
  const _TicketsTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<TicketBloc, TicketState>(
      builder: (context, state) {
        final v = context.velox;
        if (state is TicketLoading || state is TicketSubmitting) {
          return Center(
            child: CircularProgressIndicator(color: v.accent),
          );
        }

        if (state is TicketError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 56, color: v.danger),
                const SizedBox(height: VeloxSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    state.message,
                    style: TextStyle(color: v.text2, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: VeloxSpacing.lg),
                // 重试:重新拉工单列表(而不是 Navigator.pop 把用户赶出工单页)
                GestureDetector(
                  onTap: () => context
                      .read<TicketBloc>()
                      .add(TicketListRequested()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: v.surfaceMid,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: v.accent.withValues(alpha: 0.30),
                      ),
                      boxShadow: v.cardShadow,
                    ),
                    child: Text(
                      l10n.retry,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: v.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (state is TicketListLoaded) {
          if (state.tickets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.support_agent, size: 56, color: v.text3),
                  const SizedBox(height: VeloxSpacing.md),
                  Text(
                    l10n.noTicketsYet,
                    style: TextStyle(fontSize: 16, color: v.text1),
                  ),
                  const SizedBox(height: VeloxSpacing.sm),
                  Text(
                    l10n.createTicketHelp,
                    style: TextStyle(color: v.text3),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<TicketBloc>().add(TicketListRequested());
            },
            color: v.accent,
            child: ListView.builder(
              padding: const EdgeInsets.all(VeloxSpacing.pagePadding),
              itemCount: state.tickets.length,
              itemBuilder: (context, index) {
                final ticket = state.tickets[index];
                return _TicketCard(ticket: ticket);
              },
            ),
          );
        }

        return Center(
          child: CircularProgressIndicator(color: v.accent),
        );
      },
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TicketModel ticket;

  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: VeloxSpacing.sm),
      child: VeloxCard(
        onTap: () => _showTicketDetail(context),
        backgroundColor: context.velox.surfaceMid,
        borderColor: context.velox.divider,
        child: Padding(
          padding: const EdgeInsets.all(VeloxSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject ?? l10n.noSubject,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.velox.text1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(isOpen: ticket.isOpen),
                ],
              ),
              const SizedBox(height: VeloxSpacing.sm),
              Row(
                children: [
                  Text(
                    '#${ticket.id}',
                    style: TextStyle(fontSize: 12, color: context.velox.text3),
                  ),
                  const SizedBox(width: VeloxSpacing.md),
                  _PriorityChip(level: ticket.level ?? 0),
                  if (ticket.hasNewReply) ...[
                    const SizedBox(width: VeloxSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: VeloxColors.primaryGradient,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.newReply,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTicketDetail(BuildContext context) {
    final ticketId = ticket.id;
    if (ticketId == null) return;

    final ticketBloc = context.read<TicketBloc>();
    final ticketRepository = getIt<TicketRepository>();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF050E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => FutureBuilder<TicketModel>(
        future: ticketRepository.getTicketDetail(ticketId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox(
              height: 280,
              child: Center(
                child: CircularProgressIndicator(color: context.velox.accent),
              ),
            );
          }

          final detail = snapshot.data;
          final mergedTicket = TicketModel(
            id: ticket.id,
            userId: ticket.userId,
            subject: detail?.subject ?? ticket.subject,
            level: detail?.level ?? ticket.level,
            status: detail?.status ?? ticket.status,
            replyStatus: detail?.replyStatus ?? ticket.replyStatus,
            createdAt: detail?.createdAt ?? ticket.createdAt,
            updatedAt: detail?.updatedAt ?? ticket.updatedAt,
            message: (detail?.message?.isNotEmpty == true)
                ? detail!.message
                : ticket.message,
          );
          return BlocProvider.value(
            value: ticketBloc,
            child: _TicketDetailSheet(ticket: mergedTicket),
          );
        },
      ),
    );
  }
}

class _TicketDetailSheet extends StatefulWidget {
  final TicketModel ticket;

  const _TicketDetailSheet({required this.ticket});

  @override
  State<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends State<_TicketDetailSheet> {
  final TextEditingController _replyController = TextEditingController();
  final List<_UploadedImage> _replyImages = [];
  bool _isSending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          gradient: context.velox.bgGradient,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: context.velox.text4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Builder(builder: (ctx) {
            final v = ctx.velox;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '#${widget.ticket.id} - ${widget.ticket.subject}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: v.text1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.ticket.isOpen)
                    TextButton(
                      onPressed: () {
                        if (widget.ticket.id != null) {
                          context.read<TicketBloc>().add(
                                TicketCloseRequested(ticketId: widget.ticket.id!),
                              );
                        }
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(
                        l10n.closeTicketAction,
                        style: TextStyle(
                          color: v.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
          Builder(builder: (ctx) => Divider(height: 1, color: ctx.velox.divider)),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(VeloxSpacing.pagePadding),
              itemCount: widget.ticket.message?.length ?? 0,
              itemBuilder: (context, index) {
                final message = widget.ticket.message![index];
                return _MessageBubble(message: message);
              },
            ),
          ),
          if (widget.ticket.isOpen) _buildReplyComposer(context),
        ],
        ),
      ),
    );
  }

  Widget _buildReplyComposer(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final v = context.velox;
    return SafeArea(
      top: false,
      child: StatefulBuilder(
        builder: (context, setLocalState) => Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(top: BorderSide(color: v.divider)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 图片预览
              if (_replyImages.isNotEmpty) ...[
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _replyImages.length,
                    itemBuilder: (context, index) {
                      final img = _replyImages[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                img.localFile,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (img.isUploading)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (!img.isUploading)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setLocalState(() => _replyImages.removeAt(index)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 10, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 📎 上传图片按钮:accent 玻璃圆钮, 与 _SendButton 同一视觉重量
                  //  上限 4 张(_pickAndUploadImage 内部会 snack 提示); 上传中/达上限 → 置灰
                  Builder(builder: (btnCtx) {
                    final full = _replyImages.length >= 4;
                    return GestureDetector(
                      onTap: full
                          ? null
                          : () async {
                              await _pickAndUploadImage(
                                context: context,
                                images: _replyImages,
                                onUpdate: () => setLocalState(() {}),
                              );
                            },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: v.accent.withValues(alpha: full ? 0.06 : 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: v.accent.withValues(alpha: full ? 0.15 : 0.35),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.attach_file_rounded,
                          size: 18,
                          color: full ? v.text3 : v.accent,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      minLines: 1,
                      maxLines: 4,
                      style: TextStyle(color: v.text1, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: l10n.replyTicket,
                        hintStyle: TextStyle(color: v.text3, fontSize: 14),
                        filled: true,
                        fillColor: v.surfaceMid,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: v.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide:
                              BorderSide(color: v.accent, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SendButton(
                    sending: _isSending,
                    label: l10n.send,
                    onTap: () => _submitReply(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitReply(BuildContext context) {
    final message = _replyController.text.trim();
    final ticketId = widget.ticket.id;
    if (message.isEmpty || ticketId == null) return;

    // 检查是否还有图片在上传中
    if (_replyImages.any((img) => img.isUploading)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片上传中，请稍候')),
      );
      return;
    }

    final images = _replyImages
        .where((img) => img.remoteId != null)
        .map((img) => img.remoteId!)
        .toList();

    setState(() => _isSending = true);
    context.read<TicketBloc>().add(
      TicketReplyRequested(
        ticketId: ticketId,
        message: message,
        images: images.isNotEmpty ? images : null,
      ),
    );
    Navigator.pop(context);
  }
}

class _MessageBubble extends StatelessWidget {
  final TicketMessageModel message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final isMe = message.isUserMessage;
    final images = message.images;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _avatar(v, false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    isMe ? '我' : '客服',
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? v.accent : v.text3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isMe ? null : v.surfaceMid,
                gradient: isMe
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6BB5FF), Color(0xFF3B82F6)],
                      )
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: v.divider),
                boxShadow: isMe
                    ? [
                        BoxShadow(
                          color: const Color(0xFF3B82F6)
                              .withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
            // 新格式:message 里带 [img: URL] 标记(后端 embed),
            // 拆成 text 段 + inline image 段渲染;旧格式 message.images 单独列的走下面 Wrap 块。
            if (message.message?.isNotEmpty == true)
              ..._buildInlineMessageParts(
                context,
                message.message!,
                isMe: isMe,
              ),
            if (images != null && images.isNotEmpty) ...[
              if (message.message?.isNotEmpty == true) const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: images.map((encoded) {
                  final url = _decodeImageUrl(encoded);
                  return GestureDetector(
                    onTap: () => _showFullImage(context, url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        url,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 120,
                          height: 120,
                          color: v.surfaceMid,
                          child: Icon(Icons.broken_image, color: v.text3),
                        ),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 120,
                            height: 120,
                            color: v.surfaceLight,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: v.accent,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            _avatar(v, true),
          ],
        ],
      ),
    );
  }

  /// 圆形头像 —— 客服用耳麦图标，"我"用人像 + 蓝色渐变。
  Widget _avatar(VeloxTokens v, bool isMe) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMe ? null : v.surfaceMid,
        gradient: isMe
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6BB5FF), Color(0xFF3B82F6)],
              )
            : null,
        border: isMe ? null : Border.all(color: v.divider),
      ),
      child: Icon(
        isMe ? Icons.person_rounded : Icons.support_agent_rounded,
        size: 16,
        color: isMe ? Colors.white : v.accent,
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(url),
          ),
        ),
      ),
    );
  }

  /// 把 message 拆成 [文本, 图片, 文本, 图片...] 序列, 每段一个 widget。
  /// 匹配 `[img: https://...]` 或 `[img: http://...]` 内联标记, 其他保留为普通文本。
  static final RegExp _reInlineImg =
      RegExp(r'\[img:\s*(https?://[^\]\s]+)\]');

  List<Widget> _buildInlineMessageParts(
    BuildContext context, String raw, {required bool isMe}) {
    final v = context.velox;
    final textStyle = TextStyle(
      fontSize: 14,
      height: 1.4,
      color: isMe ? Colors.white : v.text1,
    );
    final widgets = <Widget>[];
    int last = 0;
    for (final m in _reInlineImg.allMatches(raw)) {
      if (m.start > last) {
        final t = raw.substring(last, m.start).trim();
        if (t.isNotEmpty) widgets.add(Text(t, style: textStyle));
      }
      final url = m.group(1)!;
      widgets.add(Padding(
        padding: EdgeInsets.only(
          top: widgets.isNotEmpty ? 6 : 0,
          bottom: 2,
        ),
        child: GestureDetector(
          onTap: () => _showFullImage(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 200,
                height: 120,
                color: v.surfaceMid,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image_outlined,
                    color: v.text3, size: 32),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  width: 200,
                  height: 120,
                  color: v.surfaceMid.withValues(alpha: 0.5),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isMe ? Colors.white : v.accent,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ));
      last = m.end;
    }
    if (last < raw.length) {
      final t = raw.substring(last).trim();
      if (t.isNotEmpty) widgets.add(Text(t, style: textStyle));
    }
    // 无任何 [img: URL] 时保留原始 Text 行为(直接一个 Text widget)
    if (widgets.isEmpty && raw.trim().isNotEmpty) {
      widgets.add(Text(raw, style: textStyle));
    }
    return widgets;
  }
}

class _StatusChip extends StatelessWidget {
  final bool isOpen;

  const _StatusChip({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final v = context.velox;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isOpen ? v.success : v.text3).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isOpen ? l10n.ticketStatusOpen : l10n.ticketStatusClosed,
        style: TextStyle(
          color: isOpen ? v.success : v.text3,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final int level;

  const _PriorityChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String text;

    switch (level) {
      case 0:
        color = Colors.blue;
        text = l10n.priorityLow;
        break;
      case 1:
        color = Colors.orange;
        text = l10n.priorityMedium;
        break;
      case 2:
        color = Colors.red;
        text = l10n.priorityHigh;
        break;
      default:
        color = context.velox.text3;
        text = l10n.priorityUnknown;
    }

    return Text(text, style: TextStyle(color: color, fontSize: 12));
  }
}


/// Velox-styled submit button for the new-ticket sheet.
class _VeloxSubmitButton extends StatefulWidget {
  const _VeloxSubmitButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_VeloxSubmitButton> createState() => _VeloxSubmitButtonState();
}

class _VeloxSubmitButtonState extends State<_VeloxSubmitButton> {
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
        padding: const EdgeInsets.symmetric(vertical: 13),
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


/// Velox send button for the ticket reply composer.
class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.sending,
    required this.label,
    required this.onTap,
  });

  final bool sending;
  final String label;
  final VoidCallback onTap;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final v = context.velox;
    final disabled = widget.sending;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel:
          disabled ? null : () => setState(() => _pressed = false),
      onTap: disabled ? null : widget.onTap,
      child: Tooltip(
        message: widget.label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [v.accent, const Color(0xFF3B82F6)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6)
                    .withValues(alpha: _pressed ? 0.40 : 0.28),
                blurRadius: _pressed ? 14 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }
}
