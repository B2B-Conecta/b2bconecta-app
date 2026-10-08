import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bcv_reference_rate_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';

/// Admin (Comisiones): tasa BCV vigente, compacta.
class AdminTasaBcvCard extends StatefulWidget {
  const AdminTasaBcvCard({super.key});

  @override
  State<AdminTasaBcvCard> createState() => _AdminTasaBcvCardState();
}

class _AdminTasaBcvCardState extends State<AdminTasaBcvCard> {
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _editing = false;
  String? _error;
  double? _rate;
  DateTime? _updatedAt;
  String? _effectiveDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
      if (missing || staleDay || publishedDiffers) {
        await SupabaseService.syncGlobalTasaBcvFromReference();
        rec = await SupabaseService.fetchGlobalTasaBcvRecord();
      }
      if (!mounted) return;
      setState(() {
        _rate = rec?.tasa;
        _updatedAt = rec?.updatedAt;
        _effectiveDate = rec?.effectiveDate ?? quote?.effectiveDate;
        _ctrl.text =
            rec != null ? formatVesAmount(rec.tasa, fractionDigits: 4) : '';
        _loading = false;
        _editing = false;
      });
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
        _ctrl.text = formatVesAmount(synced, fractionDigits: 4);
        _editing = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveManual() async {
    final parsed = parseVesOrEnDecimal(_ctrl.text);
    if (parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique una tasa válida.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await SupabaseService.adminSetTasaBcv(parsed);
      if (!mounted) return;
      setState(() {
        _rate = parsed;
        _updatedAt = DateTime.now();
        _effectiveDate = null;
        _editing = false;
      });
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
      if (_updatedAt != null) 'actualizada ${formatEsShortDateTime(_updatedAt)}',
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: _loading
            ? const SizedBox(
                height: 52,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final sideBySide = constraints.maxWidth >= 560;
                  final value = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tasa BCV del día',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _rate != null && _rate! > 0
                            ? '${formatTasaBcvDisplay(_rate!, fractionDigits: 4)} VES/REF'
                            : 'Sin tasa',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brand,
                          height: 1.1,
                        ),
                      ),
                      if (_metaLine != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _metaLine!,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.25,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  );
                  final actions = Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: sideBySide
                        ? WrapAlignment.end
                        : WrapAlignment.start,
                    children: [
                      _action(
                        onPressed: _busy ? null : _refreshFromBcv,
                        icon: _busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync, size: 16),
                        label: 'Sincronizar',
                      ),
                      _action(
                        onPressed: _openBcvOfficial,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: 'BCV oficial',
                      ),
                      _action(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _editing = !_editing),
                        icon: Icon(
                          _editing ? Icons.close : Icons.edit_outlined,
                          size: 16,
                        ),
                        label: _editing ? 'Cerrar' : 'Manual',
                      ),
                    ],
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (sideBySide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: value),
                            const SizedBox(width: 12),
                            actions,
                          ],
                        )
                      else ...[
                        value,
                        const SizedBox(height: 8),
                        actions,
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ],
                      if (_editing) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _ctrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'VES por 1 REF',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _busy ? null : _saveManual,
                            child: const Text('Guardar'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _action({
    required VoidCallback? onPressed,
    required Widget icon,
    required String label,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}
