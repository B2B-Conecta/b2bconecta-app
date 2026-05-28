import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/bcv_reference_rate_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import '../utils/ves_amount_format.dart';

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
      if (rec == null ||
          rec.tasa <= 1.01 ||
          SupabaseService.globalTasaBcvNeedsDailySync(rec.updatedAt)) {
        await SupabaseService.syncGlobalTasaBcvFromReference();
        rec = await SupabaseService.fetchGlobalTasaBcvRecord();
      }
      if (!mounted) return;
      setState(() {
        _rate = rec?.tasa;
        _updatedAt = rec?.updatedAt;
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.currency_exchange,
                        color: AppColors.brandBlue,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tasa BCV del día',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _rate != null && _rate! > 0
                                  ? '${formatTasaBcvDisplay(_rate!, fractionDigits: 4)} VES/REF'
                                  : 'Sin tasa',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                height: 1.1,
                              ),
                            ),
                            if (_updatedAt != null)
                              Text(
                                'Actualizada ${formatEsShortDateTime(_updatedAt)} · '
                                'notificación diaria a usuarios',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.grey.shade700,
                                  height: 1.25,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _refreshFromBcv,
                        icon: _busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync, size: 16),
                        label: const Text('Sincronizar'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openBcvOfficial,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('BCV oficial'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _editing = !_editing),
                        icon: Icon(
                          _editing ? Icons.expand_less : Icons.edit_outlined,
                          size: 16,
                        ),
                        label: Text(_editing ? 'Ocultar' : 'Manual'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  if (_editing) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ctrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
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
              ),
      ),
    );
  }
}
