import 'package:flutter/material.dart';

import '../auth/referral_invite_storage.dart';
import '../config/referral_invite_config.dart';
import '../models/account_access_status.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'profile_section_helpers.dart';
import 'referral_qr_scan_sheet.dart';

/// Perfil: aplicar código de vendedor externo (opcional, una sola vez).
/// Oculto si la cuenta ya está autorizada o ya tiene atribución (el usuario
/// no ve que fue referido; eso queda solo en el panel admin / KYC).
class ProfileReferralSection extends StatefulWidget {
  const ProfileReferralSection({
    super.key,
    required this.profile,
    this.onChanged,
  });

  final ProfileModel profile;
  final VoidCallback? onChanged;

  @override
  State<ProfileReferralSection> createState() => _ProfileReferralSectionState();
}

class _ProfileReferralSectionState extends State<ProfileReferralSection> {
  late final TextEditingController _codeCtrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
    _prefillPending();
  }

  Future<void> _prefillPending() async {
    if (widget.profile.hasReferralAttribution) return;
    final pending = await ReferralInviteStorage.peekPendingCode();
    if (!mounted || pending == null) return;
    _codeCtrl.text = pending;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final code = await ReferralQrScanSheet.scan(context);
    if (!mounted || code == null || code.isEmpty) return;
    setState(() => _codeCtrl.text = code);
  }

  Future<void> _apply() async {
    final code = ReferralInviteConfig.normalizeCode(_codeCtrl.text);
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique un código de referido.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await SupabaseService.applyReferralCode(code);
      await ReferralInviteStorage.clearPendingCode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código de referido aplicado.')),
      );
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.profile.accountAccessStatus?.trim();
    // Tras autorización no se muestra nada de referido al usuario.
    if (access == AccountAccessStatus.active) {
      return const SizedBox.shrink();
    }
    // Ya atribuido: no revelar al usuario que llegó por referido.
    if (widget.profile.hasReferralAttribution) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionHeader(
          label: 'REFERIDO',
          infoTitle: 'Código de vendedor',
          infoMessage:
              'Si un vendedor externo de B2B Conecta le compartió un código o QR, '
              'puede ingresarlo aquí (opcional, solo una vez). '
              'Los usuarios de la app no generan códigos propios.',
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.brandBlueContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Código de referido (opcional)',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                enabled: !_busy,
                decoration: InputDecoration(
                  hintText: 'Ej. B2BABC123',
                  filled: true,
                  fillColor: AppColors.fieldFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Escanear QR',
                    onPressed: _busy ? null : _scanQr,
                    icon: const Icon(Icons.photo_camera_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _apply,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Aplicar código'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
