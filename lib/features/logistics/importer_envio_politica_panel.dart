import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/segmented_filter_bar.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/profile/profile_service.dart';
import 'envio_politica.dart';
import 'logistics_service.dart';

const _estadosVenezuela = <String>[
  'Amazonas',
  'Anzoátegui',
  'Apure',
  'Aragua',
  'Barinas',
  'Bolívar',
  'Carabobo',
  'Cojedes',
  'Delta Amacuro',
  'Distrito Capital',
  'Falcón',
  'Guárico',
  'La Guaira',
  'Lara',
  'Mérida',
  'Miranda',
  'Monagas',
  'Nueva Esparta',
  'Portuguesa',
  'Sucre',
  'Táchira',
  'Trujillo',
  'Yaracuy',
  'Zulia',
];

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
  bool _todos = false;
  final Set<String> _estados = {};
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
        _todos = profile?.envioGratisTodos == true;
        _estados
          ..clear()
          ..addAll(profile?.envioGratisEstados ?? const []);
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

  Future<void> _saveDesktop() async {
    if (_saving) return;
    double? minimo;
    if (_gratis && _tipo != EnvioPolitica.noDefinido) {
      minimo = parseVesOrEnDecimal(_minimo.text);
      if (minimo == null || minimo <= 0) {
        _snack('Indique un monto mayor a 0 para el envío gratis.');
        return;
      }
      if (!_todos && _estados.isEmpty) {
        _snack('Elige al menos un estado, o marca todos los estados.');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await LogisticsService.importadorSetEnvioPoliticaWeb(
        tipo: _tipo,
        montoMinimo: minimo,
        gratisTodos: _gratis && _todos,
        gratisEstados: _gratis && !_todos ? _estados.toList() : const [],
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
    final desktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
    if (desktop) return _buildDesktop(context);
    return _buildNarrow();
  }

  Widget _buildNarrow() {
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

  Widget _buildDesktop(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final onBrand = Theme.of(context).colorScheme.onPrimary;
    final undefined = _tipo == EnvioPolitica.noDefinido;
    return Material(
      color: theme.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderSubtle),
        ),
        child: _loading
            ? SizedBox(
                height: 88,
                child: Center(
                  child: CircularProgressIndicator(color: theme.brand),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      LucideIcon(
                        LucideGlyph.truck,
                        size: 18,
                        color: theme.brand,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Política de envío',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                          ),
                        ),
                      ),
                      _PolicyBadge(undefined: undefined),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Así lo ve la tienda. El monto del flete lo confirmas en cada pedido.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: theme.textSecondary,
                    ),
                  ),
                  if (undefined) ...[
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.borderSubtle),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Text(
                          'Aún no tienes una política de envío. Elige si el flete va incluido o es un cobro adicional y guárdala aquí.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 8),
                  Text(
                    EnvioPolitica.ayudaProveedor(_tipo),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimary,
                    ),
                  ),
                  if (!undefined)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _tipo = EnvioPolitica.noDefinido;
                          _gratis = false;
                          _todos = false;
                          _estados.clear();
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.textSecondary,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                        ),
                        child: const Text('Dejar sin definir'),
                      ),
                    ),
                  if (!undefined) ...[
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _gratis,
                      activeColor: theme.brand,
                      onChanged: (value) => setState(() {
                        _gratis = value;
                        if (!value) {
                          _todos = false;
                          _estados.clear();
                        }
                      }),
                      title: Text(
                        'Envío gratis a partir de un monto',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: theme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Solo en los estados que marques. Los demás no tienen envío gratis y la tienda ve un costo adicional de flete.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: theme.textSecondary,
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: !_gratis
                          ? const SizedBox(width: double.infinity)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _minimo,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,]'),
                                    ),
                                  ],
                                  style: TextStyle(color: theme.textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Monto mínimo (USD)',
                                    hintText: '150.00',
                                    isDense: true,
                                    filled: true,
                                    fillColor: theme.inputFill,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Dónde aplica el envío gratis',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: theme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _StatePill(
                                      label: 'Todos los estados',
                                      selected: _todos,
                                      onTap: () => setState(() {
                                        _todos = !_todos;
                                        if (_todos) _estados.clear();
                                      }),
                                    ),
                                    for (final estado in _estadosVenezuela)
                                      _StatePill(
                                        label: estado,
                                        selected:
                                            !_todos && _estados.contains(estado),
                                        onTap: () => setState(() {
                                          _todos = false;
                                          if (!_estados.add(estado)) {
                                            _estados.remove(estado);
                                          }
                                        }),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _todos
                                        ? theme.successBg
                                        : theme.warningBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: (_todos
                                              ? theme.successFg
                                              : theme.warningFg)
                                          .withOpacity(0.35),
                                    ),
                                  ),
                                  child: Text(
                                    _todos
                                        ? 'Cubre todos los estados. Ninguno queda con costo adicional por estar fuera de la cobertura.'
                                        : 'Estados sin marcar: sin envío gratis. El comprador ve un costo adicional de flete.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700,
                                      color: _todos
                                          ? theme.successFg
                                          : theme.warningFg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _saving ? null : _saveDesktop,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.brand,
                      foregroundColor: onBrand,
                      minimumSize: const Size.fromHeight(42),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onBrand,
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

class _PolicyBadge extends StatelessWidget {
  const _PolicyBadge({required this.undefined});

  final bool undefined;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: undefined ? theme.surfaceSubtle : theme.successBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          undefined ? 'Sin definir' : 'Definida',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: undefined ? theme.textSecondary : theme.successFg,
          ),
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: selected ? theme.brandContainer : theme.surfaceSubtle,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? theme.brand : theme.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? theme.brand : theme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
