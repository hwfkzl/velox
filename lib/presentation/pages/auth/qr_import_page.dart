import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/velox_colors.dart';
import '../../../core/theme/velox_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/shared/velox_app_bar.dart';

/// QR Code Import Page
class QRImportPage extends StatefulWidget {
  const QRImportPage({super.key});

  @override
  State<QRImportPage> createState() => _QRImportPageState();
}

class _QRImportPageState extends State<QRImportPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _scanController,
        curve: Curves.easeInOut,
      ),
    );

    _scanController.repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.veloxColors;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: VeloxAppBar(
        title: l10n.scanQrCode,
        showBackButton: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: colors.bgGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              // Scan frame
              Center(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: VeloxColors.primaryWithOpacity(0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(VeloxRadius.xl),
                  ),
                  child: Stack(
                    children: [
                      // Corner decorations
                      ..._buildCorners(),
                      // Scan line
                      AnimatedBuilder(
                        animation: _scanAnimation,
                        builder: (context, child) {
                          return Positioned(
                            top: _scanAnimation.value * 260,
                            left: 10,
                            right: 10,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    VeloxColors.primary,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: VeloxSpacing.xxl),
              Text(
                l10n.qrScanHint,
                style: const TextStyle(
                  fontSize: 14,
                  color: VeloxColors.textTertiary,
                ),
              ),
              const Spacer(),
              // Bottom buttons
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: VeloxSpacing.pagePadding,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBottomButton(
                      icon: Icons.photo_library_outlined,
                      label: l10n.gallery,
                      onTap: () {
                        // TODO: Select from gallery
                      },
                    ),
                    _buildBottomButton(
                      icon: _flashOn
                          ? Icons.flash_on
                          : Icons.flash_off_outlined,
                      label: l10n.flashlight,
                      isActive: _flashOn,
                      onTap: () {
                        setState(() {
                          _flashOn = !_flashOn;
                        });
                      },
                    ),
                    _buildBottomButton(
                      icon: Icons.link,
                      label: l10n.linkImport,
                      onTap: () {
                        context.push('/url-import');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: VeloxSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 24.0;
    const color = VeloxColors.primary;
    const width = 3.0;

    return [
      // Top left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: width),
              left: BorderSide(color: color, width: width),
            ),
          ),
        ),
      ),
      // Top right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: width),
              right: BorderSide(color: color, width: width),
            ),
          ),
        ),
      ),
      // Bottom left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: width),
              left: BorderSide(color: color, width: width),
            ),
          ),
        ),
      ),
      // Bottom right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: width),
              right: BorderSide(color: color, width: width),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive
                  ? VeloxColors.primaryWithOpacity(0.2)
                  : VeloxColors.bgCardWithOpacity(0.6),
              borderRadius: BorderRadius.circular(VeloxRadius.md),
              border: Border.all(
                color: isActive
                    ? VeloxColors.primaryWithOpacity(0.5)
                    : VeloxColors.borderWithOpacity(0.3),
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: isActive
                    ? VeloxColors.primary
                    : VeloxColors.textSecondary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: VeloxSpacing.sm),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive
                  ? VeloxColors.primary
                  : VeloxColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
