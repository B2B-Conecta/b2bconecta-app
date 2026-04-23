import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../models/catalog_filters.dart';
import '../models/document_type_preference.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/encomiendas_report_excel_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import '../utils/transaction_request_filter_utils.dart';

/// Reportes de encomiendas: facturación (preferencia de documento) y métricas gerenciales.
class AdminEncomiendasReportPanel extends StatefulWidget {
  const AdminEncomiendasReportPanel({super.key});

  @override
  State<AdminEncomiendasReportPanel> createState() =>
      _AdminEncomiendasReportPanelState();
}

class _AdminEncomiendasReportPanelState
    extends State<AdminEncomiendasReportPanel> {
  List<TransactionRequestModel> _raw = [];
  List<TransactionRequestModel> _filtered = [];
  List<ImporterOption> _importers = [];
  bool _loading = false;
  String? _error;

  late DateTime _desde;
  late DateTime _hasta;
  final _searchCtrl = TextEditingController();

  /// Vacío = todos los estados (servidor).
  final Set<String> _statusSelection = {};

  String? _ownerId;
  String _docPrefFilter = 'all';
  bool _soloConFacturaAliado = false;
  bool _soloConValoracion = false;
  bool _soloPagosAprobados = false;
  bool _soloEntregados = false;

  static const _docOptions = <_DocOpt>[
    _DocOpt('all', 'Todas las preferencias'),
    _DocOpt('pendiente', 'Preferencia pendiente'),
    _DocOpt(DocumentTypePreference.notaEntrega, 'Nota de entrega'),
    _DocOpt(DocumentTypePreference.facturaFiscal, 'Factura fiscal'),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _hasta = DateTime(now.year, now.month, now.day);
    _desde = _hasta.subtract(const Duration(days: 90));
    _searchCtrl.addListener(_applyLocalFilters);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final imp = await SupabaseService.fetchImporterOptions();
      if (!mounted) return;
      setState(() => _importers = imp);
    } catch (_) {}
    await _load();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyLocalFilters);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final statuses = _statusSelection.isEmpty ? null : _statusSelection.toList();
      final rows = await SupabaseService.fetchTransactionRequestsForAdminReport(
        createdFromLocal: _desde,
        createdToLocal: _hasta,
        statuses: statuses,
        ownerId: _ownerId,
      );
      if (!mounted) return;
      setState(() {
        _raw = rows;
        _loading = false;
      });
      _applyLocalFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyLocalFilters() {
    var list = List<TransactionRequestModel>.from(_raw);

    if (_soloEntregados) {
      list = list
          .where((r) => r.status == TransactionRequestStatus.entregado)
          .toList();
    }

    switch (_docPrefFilter) {
      case 'pendiente':
        list = list
            .where(
              (r) =>
                  r.documentTypePreference == null ||
                  r.documentTypePreference!.trim().isEmpty,
            )
            .toList();
        break;
      case DocumentTypePreference.notaEntrega:
      case DocumentTypePreference.facturaFiscal:
        list = list
            .where((r) => r.documentTypePreference?.trim() == _docPrefFilter)
            .toList();
        break;
      default:
        break;
    }

    if (_soloConFacturaAliado) {
      list = list.where((r) => r.hasFacturaAliado).toList();
    }
    if (_soloConValoracion) {
      list = list.where((r) => r.aliadoExperienceSubmittedAt != null).toList();
    }
    if (_soloPagosAprobados) {
      list = list
          .where(
            (r) =>
                r.pagoEstadoRevision?.trim() == 'aprobado',
          )
          .toList();
    }

    list = TransactionRequestFilterUtils.apply(
      list,
      searchQuery: _searchCtrl.text,
      statusFilter: null,
    );

    setState(() => _filtered = list);
  }

  void _setDocPrefFilter(String value) {
    setState(() => _docPrefFilter = value);
    _applyLocalFilters();
  }

  void _clearClientFilters() {
    setState(() {
      _docPrefFilter = 'all';
      _soloConFacturaAliado = false;
      _soloConValoracion = false;
      _soloPagosAprobados = false;
      _soloEntregados = false;
      _searchCtrl.clear();
    });
    _applyLocalFilters();
  }

  Future<void> _pickDesde() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _desde,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _desde = d);
  }

  Future<void> _pickHasta() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _hasta,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _hasta = d);
  }

  void _presetDays(int days) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    setState(() {
      _hasta = end;
      _desde = end.subtract(Duration(days: days));
    });
  }

  Future<void> _exportExcel() async {
    if (_filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay filas para exportar.')),
      );
      return;
    }
    try {
      final bytes = EncomiendasReportExcelService.buildReportBytes(_filtered);
      final stamp = DateTime.now().toIso8601String().split('T').first;
      await FileSaver.instance.saveFile(
        name: 'motolink_encomiendas_$stamp',
        bytes: bytes,
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exportadas ${_filtered.length} filas.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }

  Widget _summary() {
    final list = _filtered;
    if (list.isEmpty) {
      return Text(
        'Sin resultados con los filtros actuales.',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
      );
    }
    final totalUsd = list.fold<double>(0, (s, r) => s + r.precioTotal);
    final conFactura = list.where((r) => r.hasFacturaAliado).length;
    final prefNota = list
        .where((r) => r.documentTypePreference == DocumentTypePreference.notaEntrega)
        .length;
    final prefFiscal = list
        .where((r) => r.documentTypePreference == DocumentTypePreference.facturaFiscal)
        .length;
    final prefPend = list
        .where(
          (r) =>
              r.documentTypePreference == null ||
              r.documentTypePreference!.trim().isEmpty,
        )
        .length;
    final valorados = list.where((r) => r.aliadoExperienceSubmittedAt != null).toList();
    double? avgStars;
    if (valorados.isNotEmpty) {
      final sum = valorados.fold<int>(0, (s, r) => s + (r.aliadoExperienceStars ?? 0));
      avgStars = sum / valorados.length;
    }
    final entregados = list.where((r) => r.status == TransactionRequestStatus.entregado).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatCard(
              title: 'Pedidos',
              value: '${list.length}',
              icon: Icons.inventory_2_outlined,
            ),
            _StatCard(
              title: 'Total USD (aliado)',
              value: '\$${totalUsd.toStringAsFixed(2)}',
              icon: Icons.payments_outlined,
            ),
            _StatCard(
              title: 'Con factura MotoLink',
              value: '$conFactura',
              icon: Icons.receipt_long_outlined,
            ),
            _StatCard(
              title: 'Entregados',
              value: '$entregados',
              icon: Icons.done_all_outlined,
            ),
            _StatCard(
              title: 'Nota / Fiscal / Pref. pend.',
              value: '$prefNota / $prefFiscal / $prefPend',
              icon: Icons.description_outlined,
            ),
            _StatCard(
              title: 'Valoraciones (prom.)',
              value: valorados.isEmpty
                  ? '—'
                  : '${valorados.length} · ${avgStars!.toStringAsFixed(2)} ★',
              icon: Icons.star_outline,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _raw.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text(
                  'Consolidado de encomiendas para facturación (preferencia nota vs fiscal), seguimiento de '
                  'factura MotoLink al aliado y valoraciones post-entrega. Use los filtros y exporte a Excel '
                  'para contabilidad o reportes gerenciales.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.brandBlue.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filtros rápidos de facturación',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Solo facturas fiscales'),
                            selected: _docPrefFilter ==
                                DocumentTypePreference.facturaFiscal,
                            onSelected: (_) => _setDocPrefFilter(
                              _docPrefFilter ==
                                      DocumentTypePreference.facturaFiscal
                                  ? 'all'
                                  : DocumentTypePreference.facturaFiscal,
                            ),
                          ),
                          FilterChip(
                            label: const Text('Solo nota de entrega'),
                            selected: _docPrefFilter ==
                                DocumentTypePreference.notaEntrega,
                            onSelected: (_) => _setDocPrefFilter(
                              _docPrefFilter ==
                                      DocumentTypePreference.notaEntrega
                                  ? 'all'
                                  : DocumentTypePreference.notaEntrega,
                            ),
                          ),
                          FilterChip(
                            label: const Text('Preferencia pendiente'),
                            selected: _docPrefFilter == 'pendiente',
                            onSelected: (_) => _setDocPrefFilter(
                              _docPrefFilter == 'pendiente'
                                  ? 'all'
                                  : 'pendiente',
                            ),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.clear_all, size: 18),
                            label: const Text('Limpiar filtros locales'),
                            onPressed: _clearClientFilters,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Filtros',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDesde,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          'Desde ${_desde.day}/${_desde.month}/${_desde.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickHasta,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          'Hasta ${_hasta.day}/${_hasta.month}/${_hasta.year}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      label: const Text('30 días'),
                      onPressed: () {
                        _presetDays(30);
                        _load();
                      },
                    ),
                    ActionChip(
                      label: const Text('90 días'),
                      onPressed: () {
                        _presetDays(90);
                        _load();
                      },
                    ),
                    ActionChip(
                      label: const Text('365 días'),
                      onPressed: () {
                        _presetDays(365);
                        _load();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Estado (servidor; dejar vacío = todos)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final s in TransactionRequestStatus.valuesForReportFilter)
                      FilterChip(
                        label: Text(TransactionRequestStatus.labelEs(s)),
                        selected: _statusSelection.contains(s),
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _statusSelection.add(s);
                            } else {
                              _statusSelection.remove(s);
                            }
                          });
                          _load();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: _ownerId,
                  decoration: const InputDecoration(
                    labelText: 'Importador',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    ..._importers.map(
                      (o) => DropdownMenuItem<String?>(
                        value: o.id,
                        child: Text(
                          o.businessName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _ownerId = v);
                    _load();
                  },
                ),
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text(
                    'Más filtros',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  subtitle: const Text(
                    'Documento, pago, entrega y valoración',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  children: [
                    DropdownButtonFormField<String>(
                      value: _docPrefFilter,
                      decoration: const InputDecoration(
                        labelText: 'Preferencia de documento',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _docOptions
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.value,
                              child: Text(e.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        _setDocPrefFilter(v);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Solo con factura MotoLink al aliado'),
                      value: _soloConFacturaAliado,
                      onChanged: (v) {
                        setState(() => _soloConFacturaAliado = v);
                        _applyLocalFilters();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Solo pedidos con valoración del aliado'),
                      value: _soloConValoracion,
                      onChanged: (v) {
                        setState(() => _soloConValoracion = v);
                        _applyLocalFilters();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Solo pagos aprobados por MotoLink'),
                      value: _soloPagosAprobados,
                      onChanged: (v) {
                        setState(() => _soloPagosAprobados = v);
                        _applyLocalFilters();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Solo entregados (cliente)'),
                      value: _soloEntregados,
                      onChanged: (v) {
                        setState(() => _soloEntregados = v);
                        _applyLocalFilters();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Buscar producto, SKU, aliado o importador',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _applyLocalFilters(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _load,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 20),
                        label: Text(_loading ? 'Cargando…' : 'Aplicar fechas (servidor)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _exportExcel,
                      icon: const Icon(Icons.download_outlined),
                      tooltip: 'Exportar Excel',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Resumen gerencial',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _summary(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Detalle',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${_filtered.length} filas',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        _loading ? 'Cargando…' : 'Ajuste filtros o amplíe el rango de fechas.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  ..._filtered.map(_detailTile),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailTile(TransactionRequestModel r) {
    final doc = r.documentTypePreference?.trim();
    final docTxt = doc == null || doc.isEmpty
        ? 'Doc: pendiente'
        : 'Doc: ${DocumentTypePreference.labelEs(doc) ?? doc}';
    final stars = r.aliadoExperienceStars;
    final valTxt = r.aliadoExperienceSubmittedAt == null
        ? 'Valoración: —'
        : 'Valoración: ${stars ?? 0}/5';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.productName ?? 'Producto',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '${TransactionRequestStatus.labelEs(r.status)} · '
              '${formatEsShortDateTime(r.createdAt)} · '
              '\$${r.precioTotal.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 2),
            Text(
              '${r.aliadoBusinessName ?? "Aliado"} ← ${r.ownerBusinessName ?? "Importador"}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              '$docTxt · $valTxt',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.brandBlue.withOpacity(0.95),
              ),
            ),
            if ((r.aliadoExperienceComment ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '“${r.aliadoExperienceComment!.trim()}”',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.brandBlue),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocOpt {
  const _DocOpt(this.value, this.label);
  final String value;
  final String label;
}
