import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/referral_invite_storage.dart';
import '../config/referral_invite_config.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'profile_section_helpers.dart';

/// Sección de perfil: código/link de referido y captura opcional si aún no hay.
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
    if (widget.profile.referredByProfileId != null) return;
    final pending = await ReferralInviteStorage.peekPendingCode();
    if (!mounted || pending == null) return;
    _codeCtrl.text = pending;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _copy(String text, String okMessage) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(okMessage)),
    );
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
    final code = widget.profile.referralCode?.trim();
    final hasCode = code != null && code.isNotEmpty;
    final inviteUrl =
        hasCode ? ReferralInviteConfig.inviteUrlForCode(code) : null;
    final alreadyReferred = widget.profile.referredByProfileId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileSectionHeader(
          label: 'REFERIDOS',
          infoTitle: 'Sistema de referidos',
          infoMessage:
              'Comparta su código o enlace para invitar aliados e importadores. '
              'Si alguien lo usó al registrarse, quedará asociado a su cuenta '
              'para métricas de B2B Conecta.',
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
                'Su código de invitación',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      hasCode ? code : 'Se generará al guardar el perfil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (hasCode)
                    IconButton(
                      tooltip: 'Copiar código',
                      onPressed: () => _copy(code, 'Código copiado'),
                      icon: const Icon(Icons.copy_outlined, size: 20),
                    ),
                ],
              ),
              if (inviteUrl != null) ...[
                const SizedBox(height: 8),
                Text(
                  inviteUrl,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _copy(inviteUrl, 'Enlace copiado'),
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Copiar enlace de invitación'),
                ),
              ],
              if (!alreadyReferred) ...[
                const SizedBox(height: 14),
                Text(
                  '¿Lo invitaron? Ingrese el código (solo una vez).',
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
                  enabled: !_busy && hasCode,
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
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: (!_busy && hasCode) ? _apply : null,
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
              ] else ...[
                const SizedBox(height: 12),
                Text(
                  'Cuenta vinculada a un referido.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
