import 'package:flutter/material.dart';

import '../config/terms_config.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Checkbox + enlace a términos (placeholder legal, Fase 1).
class TermsAcceptanceSection extends StatefulWidget {
  const TermsAcceptanceSection({
    super.key,
    required this.accepted,
    required this.onAcceptedChanged,
  });

  final bool accepted;
  final ValueChanged<bool> onAcceptedChanged;

  @override
  State<TermsAcceptanceSection> createState() => _TermsAcceptanceSectionState();
}

class _TermsAcceptanceSectionState extends State<TermsAcceptanceSection> {
  bool _busy = false;

  Future<void> _showTermsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(TermsConfig.title),
        content: SingleChildScrollView(
          child: Text(
            TermsConfig.body,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _onChanged(bool? value) async {
    if (value != true) {
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
      widget.onAcceptedChanged(false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Checkbox(
                    value: widget.accepted,
                    onChanged: _busy ? null : _onChanged,
                    activeColor: AppColors.brand,
                  ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8, right: 8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Acepto los '),
                    InkWell(
                      onTap: _showTermsDialog,
                      child: Text(
                        'términos y condiciones',
                        style: TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text(' de MotoLink (versión piloto).'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
