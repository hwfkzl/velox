import 'package:flutter/material.dart';
import 'package:velox/app/brand.dart';
import 'package:velox/l10n/app_localizations.dart';

import '../../../core/theme/velox/velox_tokens.dart';
import '../../widgets/velox/velox_back_button.dart';
import '../../widgets/velox/velox_scaffold.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

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
                      l10n.termsOfService,
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    Brand.brandize(l10n.termsContent),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: v.text2,
                    ),
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
