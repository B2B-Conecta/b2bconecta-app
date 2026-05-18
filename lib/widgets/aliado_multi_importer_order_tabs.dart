import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/transaction_request_model.dart';
import '../theme/app_theme.dart';
import '../utils/aliado_multi_importer_payment.dart';
import '../utils/ves_amount_format.dart';
import 'courier_timeline_widget.dart';
import 'importer_aliado_solicitud_section.dart';
import 'transaction_request_admin_sections.dart';

/// Cabecera del pedido maestro (carrito multi-importador).
class AliadoPedidoMaestroHeader extends StatelessWidget {
  const AliadoPedidoMaestroHeader({
    super.key,
    required this.allLines,
    required this.porImportador,
  });

  final List<TransactionRequestModel> allLines;
  final List<List<TransactionRequestModel>> porImportador;

  @override
  Widget build(BuildContext context) {
    final nImp = porImportador.length;
    if (nImp < 2) return const SizedBox.shrink();

    final pagados = importadoresConPagoConfirmado(porImportador);
    final totalRef = allLines.fold<double>(0, (s, r) => s + r.precioTotal);
    final cg = allLines.first.checkoutGroupId?.trim();
    final refCorta = (cg != null && cg.length >= 8)
        ? '${cg.substring(0, 8)}…'
        : null;
    final ranks = porImportador
        .map((c) => motoconectaEnvioTimelineRank(c.first.status))
        .toSet();
    final estadoMaestro = ranks.length <= 1
        ? allLines.first.statusLabelEs(aliadoViewer: true)
        : 'Avance distinto por proveedor';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandBlueContainer.withOpacity(0.55),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBlue.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hub_outlined, color: AppColors.brandBlue, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pedido maestro',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Carrito con $nImp importadores · '
                      '${formatRefAmount(totalRef)} REF'
                      '${refCorta != null ? ' · ref. $refCorta' : ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.brandBlue.withOpacity(0.35)),
                ),
                child: Text(
                  estadoMaestro,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Un solo pedido en MotoLink: destino y productos compartidos. '
            'Use el selector de proveedor para ver envío y pago de cada uno.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: nImp > 0 ? pagados / nImp : 0,
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              color: pagados == nImp ? Colors.green.shade600 : AppColors.brandBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pagos confirmados: $pagados de $nImp proveedores',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: pagados == nImp
                  ? Colors.green.shade800
                  : AppColors.brandBlue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Selector compartido + seguimiento y detalle por importador.
class AliadoMultiImporterOrderTabs extends StatefulWidget {
  const AliadoMultiImporterOrderTabs({
    super.key,
    required this.allLines,
    required this.porImportador,
    required this.importerPanelBuilder,
  });

  final List<TransactionRequestModel> allLines;
  final List<List<TransactionRequestModel>> porImportador;

  /// Factura, pago, mensajes y valoración de este proveedor.
  final Widget Function(
    BuildContext context,
    List<TransactionRequestModel> chunk,
    int importerIndex,
    int importerTotal,
  ) importerPanelBuilder;

  @override
  State<AliadoMultiImporterOrderTabs> createState() =>
      _AliadoMultiImporterOrderTabsState();
}

class _AliadoMultiImporterOrderTabsState extends State<AliadoMultiImporterOrderTabs> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final n = widget.porImportador.length;
    if (n == 0) return const SizedBox.shrink();

    final idx = _selected.clamp(0, n - 1);
    final chunk = widget.porImportador[idx];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          title: 'Proveedores de este pedido',
          subtitle:
              'Seleccione un importador. El seguimiento del envío y el detalle '
              'de factura/pago se actualizan para ese proveedor.',
        ),
        const SizedBox(height: 10),
        _ImporterChipRow(
          porImportador: widget.porImportador,
          selectedIndex: idx,
          onSelected: (i) => setState(() => _selected = i),
        ),
        const SizedBox(height: 16),
        _SectionHeading(
          title: 'Seguimiento del envío',
          subtitle:
              'Resumen de todos los proveedores; abajo, el detalle de fases del seleccionado.',
        ),
        const SizedBox(height: 10),
        _AllImportersEnvioOverview(
          porImportador: widget.porImportador,
          selectedIndex: idx,
          onSelect: (i) => setState(() => _selected = i),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _AliadoImporterShippingPanel(
            key: ValueKey<String>('ship-$idx'),
            chunk: chunk,
            importerIndex: idx + 1,
            importerTotal: n,
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeading(
          title: 'Detalle por proveedor',
          subtitle: 'Contacto, productos, factura y pago del mismo proveedor.',
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _AliadoImporterDetailPanel(
            key: ValueKey<String>('det-$idx'),
            chunk: chunk,
            importerIndex: idx + 1,
            importerTotal: n,
            importerPanel: widget.importerPanelBuilder(
              context,
              chunk,
              idx + 1,
              n,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            height: 1.3,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _ImporterChipRow extends StatelessWidget {
  const _ImporterChipRow({
    required this.porImportador,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<List<TransactionRequestModel>> porImportador;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final n = porImportador.length;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(n, (i) {
          return Padding(
            padding: EdgeInsets.only(right: i < n - 1 ? 8 : 0),
            child: _ImporterSelectorChip(
              index: i + 1,
              total: n,
              chunk: porImportador[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          );
        }),
      ),
    );
  }
}

class _ImporterSelectorChip extends StatelessWidget {
  const _ImporterSelectorChip({
    required this.index,
    required this.total,
    required this.chunk,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final int total;
  final List<TransactionRequestModel> chunk;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = chunk.first.ownerBusinessName?.trim() ?? 'Importador';
    final fase = fasePagoBloqueImportador(chunk);
    final envio = chunk.first.statusLabelEs(aliadoViewer: true);

    return Material(
      color: selected
          ? AppColors.brandBlue.withOpacity(0.12)
          : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.brandBlue : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: selected
                        ? AppColors.brandBlue
                        : Colors.grey.shade400,
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: selected
                            ? AppColors.brandBlue
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Envío: $envio',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
              ),
              Text(
                fasePagoBloqueLabelEs(fase),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _faseColor(fase),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _faseColor(AliadoImportadorPagoFase fase) {
    switch (fase) {
      case AliadoImportadorPagoFase.pagoConfirmado:
        return Colors.green.shade800;
      case AliadoImportadorPagoFase.comprobanteEnRevision:
        return Colors.orange.shade900;
      case AliadoImportadorPagoFase.pendientePago:
        return AppColors.brandBlue;
      case AliadoImportadorPagoFase.esperandoFacturaProveedor:
        return Colors.amber.shade900;
      default:
        return Colors.grey.shade700;
    }
  }
}

/// Vista rápida del estado logístico de cada importador del carrito.
class _AllImportersEnvioOverview extends StatelessWidget {
  const _AllImportersEnvioOverview({
    required this.porImportador,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<List<TransactionRequestModel>> porImportador;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Avance por proveedor',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(porImportador.length, (i) {
              final chunk = porImportador[i];
              final ref = chunk.first;
              final selected = i == selectedIndex;
              final envio = ref.statusLabelEs(aliadoViewer: true);
              final name = ref.ownerBusinessName?.trim() ?? 'Importador ${i + 1}';
              return Padding(
                padding: EdgeInsets.only(right: i < porImportador.length - 1 ? 8 : 0),
                child: Material(
                  color: selected
                      ? Colors.teal.shade50
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => onSelect(i),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 148,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? Colors.teal.shade400
                              : Colors.grey.shade300,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${i + 1}.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            envio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Timeline y recogida en almacén del proveedor activo.
class _AliadoImporterShippingPanel extends StatelessWidget {
  const _AliadoImporterShippingPanel({
    super.key,
    required this.chunk,
    required this.importerIndex,
    required this.importerTotal,
  });

  final List<TransactionRequestModel> chunk;
  final int importerIndex;
  final int importerTotal;

  @override
  Widget build(BuildContext context) {
    final ref = chunk.first;
    final name = ref.ownerBusinessName?.trim() ?? 'Importador';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.teal.shade50.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping_outlined,
                    size: 20, color: Colors.teal.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Proveedor $importerIndex de $importerTotal · $name',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CourierTimelineWidget(
                  request: ref,
                  compact: true,
                  viewerRole: AppHomeRole.aliado,
                  showHeading: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AliadoImporterDetailPanel extends StatelessWidget {
  const _AliadoImporterDetailPanel({
    super.key,
    required this.chunk,
    required this.importerIndex,
    required this.importerTotal,
    required this.importerPanel,
  });

  final List<TransactionRequestModel> chunk;
  final int importerIndex;
  final int importerTotal;
  final Widget importerPanel;

  @override
  Widget build(BuildContext context) {
    final ref = chunk.first;
    final name = ref.ownerBusinessName?.trim() ?? 'Importador';
    final fase = fasePagoBloqueImportador(chunk);
    final monto = subtotalBloqueImportador(chunk);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proveedor $importerIndex de $importerTotal · $name',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${chunk.length} ${chunk.length == 1 ? "línea" : "líneas"} · '
                  '${formatRefAmount(monto)} REF · ${fasePagoBloqueLabelEs(fase)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TransactionRequestImporterContactSection(request: ref),
                const SizedBox(height: 12),
                TransactionRequestProductosDesgloseSection(
                  lines: chunk,
                  compact: true,
                  viewer: PedidoDesgloseViewer.aliado,
                  showPrecioHelp: false,
                  sectionTitle: 'Productos de este proveedor',
                  showImporterGroupHeaders: false,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: importerPanel,
          ),
        ],
      ),
    );
  }
}
