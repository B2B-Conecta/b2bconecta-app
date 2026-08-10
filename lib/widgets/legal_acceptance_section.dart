import 'package:flutter/material.dart';

import '../config/privacy_policy_config.dart';
import '../config/terms_config.dart';
import '../theme/app_theme.dart';

/// Aceptación de términos y política de privacidad en registro inicial (aliado / importador).
///
/// La casilla solo marca intención local. La persistencia (`profile_accept_terms`)
/// ocurre al guardar el perfil. Se bloquea únicamente cuando [locked] es true
/// (aceptación ya guardada en BD).
class LegalAcceptanceSection extends StatelessWidget {
  const LegalAcceptanceSection({
    super.key,
    required this.accepted,
    required this.onAcceptedChanged,
    this.locked = false,
  });

  /// Marcada en UI (local y/o persistida).
  final bool accepted;

  /// True cuando la aceptación ya está en `profiles` (versión vigente).
  final bool locked;

  final ValueChanged<bool> onAcceptedChanged;

  Future<void> _showLegalSheet(
    BuildContext context, {
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
                    style: TextStyle(
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
                        color: AppColors.textPrimary,
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

  void _onToggle(bool? value) {
    if (locked || value == null) return;
    // Solo se puede aceptar (no retirar desde aquí una vez persistido).
    if (!value) return;
    if (accepted) return;
    onAcceptedChanged(true);
  }

  TextStyle _baseStyle() => TextStyle(
        fontSize: 13,
        height: 1.35,
        color: accepted ? AppColors.successGreen : AppColors.textPrimary,
        fontWeight: accepted ? FontWeight.w600 : FontWeight.w400,
      );

  static const _linkStyle = TextStyle(
    fontSize: 13,
    height: 1.35,
    color: AppColors.brand,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
  );

  Widget _link(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(label, style: _linkStyle),
    );
  }

  Widget _plain(String text) => Text(text, style: _baseStyle());

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: accepted,
            onChanged: locked ? null : _onToggle,
            activeColor: AppColors.brand,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _plain('Acepto los '),
                      _link(
                        context,
                        'términos y condiciones',
                        () => _showLegalSheet(
                          context,
                          title: TermsConfig.title,
                          body: TermsConfig.body,
                        ),
                      ),
                      _plain(' y la '),
                      _link(
                        context,
                        'política de privacidad',
                        () => _showLegalSheet(
                          context,
                          title: PrivacyPolicyConfig.title,
                          body: PrivacyPolicyConfig.body,
                        ),
                      ),
                      _plain(' de B2B Conecta.'),
                    ],
                  ),
                  if (locked) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Aceptación registrada. Puede consultar los textos; '
                      'no es posible retirar el consentimiento desde aquí.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else if (accepted) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Marcado. Se registrará al guardar el perfil.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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
