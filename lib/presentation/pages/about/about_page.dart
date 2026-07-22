import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/brand.dart';
import '../../../core/theme/velox/velox_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/velox/velox_back_button.dart';
import '../../widgets/velox/velox_brand_tile.dart';
import '../../widgets/velox/velox_scaffold.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      l10n.aboutUs,
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
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App logo tile — matches Dock launcher icon
                      const VeloxBrandTile(size: 96),
                      const SizedBox(height: 18),
                      Text(
                        Brand.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: v.text1,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          final version = snapshot.data?.version ?? '';
                          return Text(
                            version.isEmpty ? 'Version' : 'Version $version',
                            style: TextStyle(fontSize: 13, color: v.text3),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Text(
                          Brand.brandize(l10n.gameDescription),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: v.text2, height: 1.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '《${l10n.termsOfService}》',
                        style: TextStyle(
                          color: v.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => context.push('/terms-of-service'),
                      ),
                      const TextSpan(
                        text: '    ',
                        style: TextStyle(fontSize: 13),
                      ),
                      TextSpan(
                        text: '《${l10n.privacyPolicy}》',
                        style: TextStyle(
                          color: v.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => context.push('/privacy-policy'),
                      ),
                    ],
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
