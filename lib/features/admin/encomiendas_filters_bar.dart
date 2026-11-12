import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/widgets/app_date_picker.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/features/payments/document_type_preference.dart';

/// Píldora de estado rápido en Encomiendas.
enum EncomiendasStatusPill {
  todos,
  enPreparacion,
  enTransito,
  entregados,
  cancelados,
}

extension EncomiendasStatusPillX on EncomiendasStatusPill {
  String get labelEs => switch (this) {
        EncomiendasStatusPill.todos => 'Todos',
        EncomiendasStatusPill.enPreparacion => 'En preparación',
        EncomiendasStatusPill.enTransito => 'En tránsito',
        EncomiendasStatusPill.entregados => 'Entregados',
        EncomiendasStatusPill.cancelados => 'Cancelados',
      };

  /// Estados enviados al servidor (`null` = sin filtro).
  Set<String>? get serverStatuses => switch (this) {
        EncomiendasStatusPill.todos => null,
        EncomiendasStatusPill.enPreparacion => {
            TransactionRequestStatus.enPreparacion,
          },
        EncomiendasStatusPill.enTransito => {
            TransactionRequestStatus.enTransito,
            TransactionRequestStatus.enviado,
          },
        EncomiendasStatusPill.entregados => {
            TransactionRequestStatus.entregado,
          },
        EncomiendasStatusPill.cancelados => {
            TransactionRequestStatus.rechazado,
          },
      };
}

enum EncomiendasPeriodPreset { d7, d30, d90, custom }

/// Barra de periodo, estados y filtros avanzados (popover compacto).
class EncomiendasFiltersBar extends StatelessWidget {
  const EncomiendasFiltersBar({
    super.key,
    required this.desde,
    required this.hasta,
    required this.periodPreset,
    required this.statusPill,
    required this.importers,
    required this.ownerId,
    required this.docPrefFilter,
    required this.topSoldLimit,
    required this.searchCtrl,
    required this.loading,
    required this.exporting,
    required this.canExport,
    required this.filteredCount,
    required this.advancedActiveCount,
    required this.onPeriodPreset,
    required this.onCustomRange,
    required this.onStatusPill,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onExport,
    required this.onRefresh,
    required this.onApplyAdvanced,
    required this.onClearAll,
  });

  final DateTime desde;
  final DateTime hasta;
  final EncomiendasPeriodPreset periodPreset;
  final EncomiendasStatusPill statusPill;
  final List<ImporterOption> importers;
  final String? ownerId;
  final String docPrefFilter;
  final int? topSoldLimit;
  final TextEditingController searchCtrl;
  final bool loading;
  final bool exporting;
  final bool canExport;
  final int filteredCount;
  final int advancedActiveCount;
  final ValueChanged<EncomiendasPeriodPreset> onPeriodPreset;
  final Future<void> Function() onCustomRange;
  final ValueChanged<EncomiendasStatusPill> onStatusPill;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onExport;
  final VoidCallback onRefresh;
  final Future<void> Function({
    required String? ownerId,
    required String docPref,
    required int? topSoldLimit,
  }) onApplyAdvanced;
  final VoidCallback onClearAll;

  String get _periodLabel {
    switch (periodPreset) {
      case EncomiendasPeriodPreset.d7:
        return 'Últimos 7 días';
      case EncomiendasPeriodPreset.d30:
        return 'Últimos 30 días';
      case EncomiendasPeriodPreset.d90:
        return 'Últimos 90 días';
      case EncomiendasPeriodPreset.custom:
        return '${_short(desde)} – ${_short(hasta)}';
    }
  }

  String _short(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  Future<void> _openAdvanced(BuildContext context) async {
    final theme = B2BThemeExtension.of(context);
    var draftOwner = ownerId;
    var draftDoc = docPrefFilter;
    var draftTop = topSoldLimit;
    final importerSearch = TextEditingController();

    final result = await showDialog<_AdvancedDraft?>(
      context: context,
      barrierColor: theme.textPrimary.withOpacity(0.28),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final q = importerSearch.text.trim().toLowerCase();
            final filteredImporters = importers.where((o) {
              if (q.isEmpty) return true;
              return o.businessName.toLowerCase().contains(q);
            }).toList();

            return Dialog(
              backgroundColor: theme.dialogSurface,
              surfaceTintColor: theme.dialogSurface,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.borderSubtle),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          LucideIcon(
                            LucideGlyph.slidersHorizontal,
                            size: 18,
                            color: theme.brand,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Filtros avanzados',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: theme.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.pop(ctx),
                            icon: LucideIcon(
                              LucideGlyph.close,
                              size: 18,
                              color: theme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Importador',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: importerSearch,
                        onChanged: (_) => setLocal(() {}),
                        decoration: InputDecoration(
                          hintText: 'Buscar mayorista…',
                          isDense: true,
                          filled: true,
                          fillColor: theme.inputFill,
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 10, right: 6),
                            child: LucideIcon(
                              LucideGlyph.search,
                              size: 16,
                              color: theme.textSecondary,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: theme.borderStrong),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: theme.borderStrong),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        value: draftOwner,
                        isExpanded: true,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: theme.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'Todos los importadores',
                              style: TextStyle(color: theme.textPrimary),
                            ),
                          ),
                          for (final o in filteredImporters)
                            DropdownMenuItem<String?>(
                              value: o.id,
                              child: Text(
                                o.businessName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: theme.textPrimary),
                              ),
                            ),
                        ],
                        onChanged: (v) => setLocal(() => draftOwner = v),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Preferencia de documento',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: draftDoc,
                        isExpanded: true,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: theme.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(
                              'Todas',
                              style: TextStyle(color: theme.textPrimary),
                            ),
                          ),
                          DropdownMenuItem(
                            value: DocumentTypePreference.notaEntrega,
                            child: Text(
                              'Nota de entrega',
                              style: TextStyle(color: theme.textPrimary),
                            ),
                          ),
                          DropdownMenuItem(
                            value: DocumentTypePreference.facturaFiscal,
                            child: Text(
                              'Factura fiscal',
                              style: TextStyle(color: theme.textPrimary),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setLocal(() => draftDoc = v);
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Top de productos',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int?>(
                        value: draftTop,
                        isExpanded: true,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: theme.inputFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: [
                          DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'Todos',
                              style: TextStyle(color: theme.textPrimary),
                            ),
                          ),
                          DropdownMenuItem<int?>(
                            value: 10,
                            child: Text(
                              'Top 10',
                              style: TextStyle(color: theme.textPrimary),
                            ),
                          ),
                          DropdownMenuItem<int?>(
                            value: 20,
                            child: Text(
                              'Top 20',
                              style: TextStyle(color: theme.textPrimary),
                            ),
                          ),
                        ],
                        onChanged: (v) => setLocal(() => draftTop = v),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(
                                ctx,
                                const _AdvancedDraft.clear(),
                              ),
                              child: const Text('Limpiar filtros'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(
                                ctx,
                                _AdvancedDraft(
                                  ownerId: draftOwner,
                                  docPref: draftDoc,
                                  topSoldLimit: draftTop,
                                  clearAll: false,
                                ),
                              ),
                              child: const Text('Aplicar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    importerSearch.dispose();
    if (result == null) return;
    if (result.clearAll) {
      onClearAll();
      return;
    }
    await onApplyAdvanced(
      ownerId: result.ownerId,
      docPref: result.docPref,
      topSoldLimit: result.topSoldLimit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: MediaQuery.sizeOf(context).width < 600
                      ? 'Producto, SKU, tienda…'
                      : 'Buscar producto, SKU, tienda minorista…',
                  isDense: true,
                  filled: true,
                  fillColor: theme.inputFill,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: LucideIcon(
                      LucideGlyph.search,
                      size: 18,
                      color: theme.textSecondary,
                    ),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                  suffixIcon: searchCtrl.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: onClearSearch,
                          icon: LucideIcon(
                            LucideGlyph.close,
                            size: 16,
                            color: theme.textSecondary,
                          ),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.brand, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: canExport ? onExport : null,
              tooltip: filteredCount == 0
                  ? 'Sin datos para Excel'
                  : 'Descargar Excel ($filteredCount)',
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              icon: exporting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.brand,
                      ),
                    )
                  : LucideIcon(
                      LucideGlyph.download,
                      size: 18,
                      color: theme.brand,
                    ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: loading ? null : onRefresh,
              tooltip: 'Actualizar',
              style: IconButton.styleFrom(
                backgroundColor: theme.brand,
                foregroundColor: theme.surfaceCard,
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              icon: loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.surfaceCard,
                      ),
                    )
                  : LucideIcon(
                      LucideGlyph.refreshCw,
                      size: 18,
                      color: theme.surfaceCard,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _PeriodMenu(
              theme: theme,
              label: _periodLabel,
              enabled: !loading,
              preset: periodPreset,
              onPreset: onPeriodPreset,
              onCustom: onCustomRange,
            ),
            _FiltersSoftButton(
              theme: theme,
              activeCount: advancedActiveCount,
              enabled: !loading,
              onTap: () => _openAdvanced(context),
            ),
            if (advancedActiveCount > 0 ||
                statusPill != EncomiendasStatusPill.todos)
              TextButton(
                onPressed: onClearAll,
                style: TextButton.styleFrom(
                  foregroundColor: theme.textSecondary,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Limpiar'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final pill in EncomiendasStatusPill.values) ...[
                _StatusPillChip(
                  theme: theme,
                  label: pill.labelEs,
                  selected: statusPill == pill,
                  onTap: loading ? null : () => onStatusPill(pill),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AdvancedDraft {
  const _AdvancedDraft({
    required this.ownerId,
    required this.docPref,
    required this.topSoldLimit,
    required this.clearAll,
  });

  const _AdvancedDraft.clear()
      : ownerId = null,
        docPref = 'all',
        topSoldLimit = null,
        clearAll = true;

  final String? ownerId;
  final String docPref;
  final int? topSoldLimit;
  final bool clearAll;
}

/// Píldora ligera «Filtros» (outline / soft fill) — light & dark vía tokens.
class _FiltersSoftButton extends StatelessWidget {
  const _FiltersSoftButton({
    required this.theme,
    required this.activeCount,
    required this.enabled,
    required this.onTap,
  });

  final B2BThemeExtension theme;
  final int activeCount;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = activeCount > 0;
    final label = active ? 'Filtros · $activeCount' : 'Filtros';
    final fg = active ? theme.brand : theme.textSecondary;
    final bg = active ? theme.brandContainer : theme.inputFill;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? theme.brand.withOpacity(0.45) : theme.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LucideIcon(
                  LucideGlyph.slidersHorizontal,
                  size: 15,
                  color: fg,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? theme.brand : theme.textPrimary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodMenu extends StatelessWidget {
  const _PeriodMenu({
    required this.theme,
    required this.label,
    required this.enabled,
    required this.preset,
    required this.onPreset,
    required this.onCustom,
  });

  final B2BThemeExtension theme;
  final String label;
  final bool enabled;
  final EncomiendasPeriodPreset preset;
  final ValueChanged<EncomiendasPeriodPreset> onPreset;
  final Future<void> Function() onCustom;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<EncomiendasPeriodPreset>(
      enabled: enabled,
      tooltip: 'Periodo',
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.borderStrong),
      ),
      color: theme.dialogSurface,
      onSelected: (v) async {
        if (v == EncomiendasPeriodPreset.custom) {
          await onCustom();
          return;
        }
        onPreset(v);
      },
      itemBuilder: (context) => [
        for (final p in const [
          EncomiendasPeriodPreset.d7,
          EncomiendasPeriodPreset.d30,
          EncomiendasPeriodPreset.d90,
        ])
          CheckedPopupMenuItem(
            value: p,
            checked: preset == p,
            child: Text(
              switch (p) {
                EncomiendasPeriodPreset.d7 => 'Últimos 7 días',
                EncomiendasPeriodPreset.d30 => 'Últimos 30 días',
                EncomiendasPeriodPreset.d90 => 'Últimos 90 días',
                EncomiendasPeriodPreset.custom => 'Rango personalizado',
              },
            ),
          ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
          value: EncomiendasPeriodPreset.custom,
          checked: preset == EncomiendasPeriodPreset.custom,
          child: const Text('Rango personalizado'),
        ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.borderStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LucideIcon(
                LucideGlyph.activity,
                size: 16,
                color: theme.brand,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              LucideIcon(
                LucideGlyph.chevronDown,
                size: 16,
                color: theme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPillChip extends StatelessWidget {
  const _StatusPillChip({
    required this.theme,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final B2BThemeExtension theme;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? theme.brandContainer : theme.surfaceCard,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? theme.brand : theme.borderSubtle,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? theme.brand : theme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector de rango personalizado (desde / hasta).
Future<(DateTime, DateTime)?> pickEncomiendasCustomRange({
  required BuildContext context,
  required DateTime desde,
  required DateTime hasta,
}) async {
  var from = desde;
  var to = hasta;
  final d1 = await showAppDatePicker(
    context: context,
    initialDate: from,
    firstDate: DateTime(2020),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    helpText: 'Desde',
  );
  if (d1 == null || !context.mounted) return null;
  from = d1;
  final d2 = await showAppDatePicker(
    context: context,
    initialDate: to.isBefore(from) ? from : to,
    firstDate: from,
    lastDate: DateTime.now().add(const Duration(days: 365)),
    helpText: 'Hasta',
  );
  if (d2 == null) return null;
  to = d2;
  return (from, to);
}

String formatEncomiendasDateShort(DateTime d) => formatEsShortDateTime(
      DateTime(d.year, d.month, d.day),
    ).split(' ').first;
