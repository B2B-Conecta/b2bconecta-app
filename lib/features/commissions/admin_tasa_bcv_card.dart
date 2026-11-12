import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bcv_reference_rate_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/unified_action_dialog.dart';

/// Admin (Comisiones): tasa BCV vigente, compacta.
class AdminTasaBcvCard extends StatefulWidget {
  const AdminTasaBcvCard({super.key, required this.canEdit, this.onRateChanged});

  /// Sincronizar o fijar la tasa global. Sin permiso la tarjeta es de lectura.
  final bool canEdit;
  final ValueChanged<double?>? onRateChanged;

  @override
  State<AdminTasaBcvCard> createState() => _AdminTasaBcvCardState();
}

class _AdminTasaBcvCardState extends State<AdminTasaBcvCard> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  double? _rate;
  DateTime? _updatedAt;
  String? _effectiveDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var rec = await SupabaseService.fetchGlobalTasaBcvRecord();
      final quote = await BcvReferenceRateService.fetchPublicBcvUsdRate();
      final missing = rec == null || rec.tasa <= 1.01;
      final staleDay =
          SupabaseService.globalTasaBcvNeedsDailySync(rec?.updatedAt);
      final publishedDiffers = quote != null &&
          rec != null &&
          BcvReferenceRateService.ratesDiffer(quote.vesPerUsd, rec.tasa);
      if (widget.canEdit && (missing || staleDay || publishedDiffers)) {
        await SupabaseService.syncGlobalTasaBcvFromReference();
        rec = await SupabaseService.fetchGlobalTasaBcvRecord();
      }
      if (!mounted) return;
      setState(() {
        _rate = rec?.tasa;
        _updatedAt = rec?.updatedAt;
        _effectiveDate = rec?.effectiveDate ?? quote?.effectiveDate;
        _loading = false;
      });
      widget.onRateChanged?.call(_rate);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshFromBcv() async {
    setState(() => _busy = true);
    try {
      final synced = await SupabaseService.syncGlobalTasaBcvFromReference();
      if (!mounted) return;
      if (synced == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo obtener la tasa. Consulte el BCV oficial o ingrésela manualmente.',
            ),
          ),
        );
        return;
      }
      final rec = await SupabaseService.fetchGlobalTasaBcvRecord();
      setState(() {
        _rate = synced;
        _updatedAt = rec?.updatedAt ?? DateTime.now();
        _effectiveDate = rec?.effectiveDate;
      });
      widget.onRateChanged?.call(_rate);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openManualDialog() async {
    final initial = _rate != null
        ? formatVesAmount(_rate!, fractionDigits: 4)
        : '';
    final saved = await UnifiedActionDialog.show<double>(
      context: context,
      builder: (ctx) => _ManualTasaBcvDialog(initialText: initial),
    );
    if (saved == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.adminSetTasaBcv(saved);
      if (!mounted) return;
      setState(() {
        _rate = saved;
        _updatedAt = DateTime.now();
        _effectiveDate = null;
      });
      widget.onRateChanged?.call(_rate);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tasa guardada. Los usuarios serán notificados si aún no recibieron el aviso de hoy.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBcvOfficial() async {
    final ok = await launchUrl(
      Uri.parse(BcvReferenceRateService.bcvOfficialUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el sitio del BCV.')),
      );
    }
  }

  String? get _metaLine {
    final parts = <String>[
      if (BcvReferenceRateService.formatFechaValorEs(_effectiveDate) != null)
        'Fecha valor ${BcvReferenceRateService.formatFechaValorEs(_effectiveDate)}',
      if (_updatedAt != null)
        'act. ${formatEsShortDateTime(_updatedAt)}',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: theme.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderSubtle),
        ),
        child: _loading
            ? SizedBox(
                height: 56,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.brand,
                    ),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: theme.brandContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: LucideIcon(
                          LucideGlyph.badgeDollarSign,
                          size: 16,
                          color: theme.brand,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tasa BCV del día',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _rate != null && _rate! > 0
                                  ? '${formatTasaBcvDisplay(_rate!, fractionDigits: 4)} VES/REF'
                                  : 'Sin tasa',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: theme.brand,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_busy)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.brand,
                          ),
                        )
                      else
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.successFg,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (_metaLine != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _metaLine!,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: theme.textMuted,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.canEdit)
                        _OutlineAction(
                          label: 'Sincronizar',
                          glyph: LucideGlyph.refreshCw,
                          onPressed: _busy ? null : _refreshFromBcv,
                        ),
                      _OutlineAction(
                        label: 'BCV oficial',
                        glyph: LucideGlyph.arrowRight,
                        onPressed: _openBcvOfficial,
                      ),
                      if (widget.canEdit)
                        _OutlineAction(
                          label: 'Manual',
                          glyph: LucideGlyph.pencil,
                          onPressed: _busy ? null : _openManualDialog,
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.label,
    required this.glyph,
    this.onPressed,
  });

  final String label;
  final LucideGlyph glyph;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: LucideIcon(glyph, size: 14, color: theme.brand),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.brand,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.brand,
        side: BorderSide(color: theme.borderStrong),
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _ManualTasaBcvDialog extends StatefulWidget {
  const _ManualTasaBcvDialog({required this.initialText});

  final String initialText;

  @override
  State<_ManualTasaBcvDialog> createState() => _ManualTasaBcvDialogState();
}

class _ManualTasaBcvDialogState extends State<_ManualTasaBcvDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = parseVesOrEnDecimal(_ctrl.text);
    if (parsed == null || parsed <= 0) {
      setState(() => _error = 'Indique una tasa válida mayor a 0.');
      return;
    }
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return UnifiedActionDialog(
      title: 'Tasa BCV manual',
      subtitle: 'VES por 1 REF · se notificará a usuarios si aplica.',
      glyph: LucideGlyph.pencil,
      tone: UnifiedActionTone.info,
      primaryLabel: 'Guardar tasa',
      onPrimary: _submit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            style: TextStyle(color: theme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'VES por 1 REF',
              filled: true,
              fillColor: theme.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.brand, width: 1.4),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
