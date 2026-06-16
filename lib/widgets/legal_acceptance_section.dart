import 'package:flutter/material.dart';

import '../config/privacy_policy_config.dart';
import '../config/terms_config.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Aceptación de términos y política de privacidad en registro inicial (aliado / importador).
class LegalAcceptanceSection extends StatefulWidget {
  const LegalAcceptanceSection({
    super.key,
    required this.accepted,
    required this.onAcceptedChanged,
  });

  final bool accepted;
  final ValueChanged<bool> onAcceptedChanged;

  @override
  State<LegalAcceptanceSection> createState() => _LegalAcceptanceSectionState();
}

class _LegalAcceptanceSectionState extends State<LegalAcceptanceSection> {
  bool _busy = false;

  Future<void> _showLegalSheet({
    required String title,
    required String body,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.85;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Text(
                      body,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onToggle(bool? value) async {
    if (_busy || value == null || value == widget.accepted) return;

    if (!value) {
      widget.onAcceptedChanged(false);
      return;
    }

    setState(() => _busy = true);
    try {
      await SupabaseService.acceptTerms(version: TermsConfig.currentVersion);
      if (!mounted) return;
      widget.onAcceptedChanged(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar la aceptación: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  TextStyle _baseStyle() => TextStyle(
        fontSize: 13,
        height: 1.35,
        color:
            widget.accepted ? AppColors.successGreen : AppColors.textPrimary,
        fontWeight: widget.accepted ? FontWeight.w600 : FontWeight.w400,
      );

  static const _linkStyle = TextStyle(
    fontSize: 13,
    height: 1.35,
    color: AppColors.brand,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
  );

  Widget _link(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(label, style: _linkStyle),
    );
  }

  Widget _plain(String text) => Text(text, style: _baseStyle());

  @override
  Widget build(BuildContext context) {
    final accepted = widget.accepted;

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _busy
              ? const Padding(
                  padding: EdgeInsets.only(left: 4, top: 6),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Checkbox(
                  value: accepted,
                  onChanged: _busy ? null : _onToggle,
                  activeColor: AppColors.brand,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _plain('Acepto los '),
                  _link(
                    'términos y condiciones',
                    () => _showLegalSheet(
                      title: TermsConfig.title,
                      body: TermsConfig.body,
                    ),
                  ),
                  _plain(' y la '),
                  _link(
                    'política de privacidad',
                    () => _showLegalSheet(
                      title: PrivacyPolicyConfig.title,
                      body: PrivacyPolicyConfig.body,
                    ),
                  ),
                  _plain(' de MotoLink.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// @deprecated Use [LegalAcceptanceSection].
typedef TermsAcceptanceSection = LegalAcceptanceSection;
