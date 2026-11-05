import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/segmented_filter_bar.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/profile/profile_service.dart';
import 'envio_politica.dart';
import 'logistics_service.dart';

/// Política de flete de vitrina (incluido / cobro adicional). Sin catálogo de agencias.
class ImporterEnvioPoliticaPanel extends StatefulWidget {
  const ImporterEnvioPoliticaPanel({super.key});

  @override
  State<ImporterEnvioPoliticaPanel> createState() =>
      _ImporterEnvioPoliticaPanelState();
}

class _ImporterEnvioPoliticaPanelState extends State<ImporterEnvioPoliticaPanel> {
  static const _labels = ['Incluido', 'Cobro adicional'];

  String _tipo = EnvioPolitica.noDefinido;
  bool _gratis = false;
  final _minimo = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minimo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await ProfileService.fetchMyProfile();
      if (!mounted) return;
      final tipo = EnvioPolitica.normalize(profile?.envioTipo);
      final minimo = profile?.montoMinimoEnvioGratis;
      setState(() {
        _tipo = tipo;
        _gratis =
            minimo != null && minimo > 0 && tipo != EnvioPolitica.noDefinido;
        _minimo.text = _gratis ? minimo!.toStringAsFixed(2) : '';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int get _selectedIndex {
    switch (_tipo) {
      case EnvioPolitica.incluido:
        return 0;
      case EnvioPolitica.aparte:
        return 1;
      default:
        return -1;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    double? minimo;
    if (_gratis && _tipo != EnvioPolitica.noDefinido) {
      minimo = parseVesOrEnDecimal(_minimo.text);
      if (minimo == null || minimo <= 0) {
        _snack('Indique un monto mayor a 0 para el envío gratis.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await LogisticsService.importadorSetEnvioPolitica(
        tipo: _tipo,
        montoMinimo: minimo,
        transportistas: const [],
      );
      if (!mounted) return;
      _snack('Política de envío guardada.');
    } catch (_) {
      if (!mounted) return;
      _snack('No se pudo guardar la política de envío.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: _loading
            ? const SizedBox(
                height: 88,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Política de envío',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Así lo ve la tienda en el catálogo. El monto final del flete '
                    'lo define usted en cada pedido.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedFilterBar(
                    labels: _labels,
                    selectedIndex: _selectedIndex,
                    onSelected: (index) {
                      setState(() {
                        _tipo = index == 0
                            ? EnvioPolitica.incluido
                            : EnvioPolitica.aparte;
                      });
                    },
                  ),
                  Text(
                    EnvioPolitica.ayudaProveedor(_tipo),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (_tipo != EnvioPolitica.noDefinido)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _tipo = EnvioPolitica.noDefinido;
                          _gratis = false;
                        }),
                        child: const Text('Dejar sin definir'),
                      ),
                    ),
                  if (_tipo != EnvioPolitica.noDefinido) ...[
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _gratis,
                      onChanged: (value) => setState(() => _gratis = value),
                      title: const Text(
                        'Envío gratis a partir de un monto',
                        style:
                            TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Opcional. Se informa al confirmar el pedido.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (_gratis)
                      TextField(
                        controller: _minimo,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Monto mínimo (USD)',
                          hintText: '150.00',
                          isDense: true,
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar política'),
                  ),
                ],
              ),
      ),
    );
  }
}
