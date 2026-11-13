import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

/// Contenedor estándar de tablas/listados (modelo Cuentas).
///
/// Usa [B2BThemeExtension]: `surfaceCard`, `borderSubtle`, radio 12.
class B2bDataTableShell extends StatelessWidget {
  const B2bDataTableShell({
    super.key,
    this.child,
    this.toolbar,
    this.header,
    this.rows = const <Widget>[],
    this.footer,
    this.padding = const EdgeInsets.all(16),
    this.empty,
    this.rowsBusy = false,
  });

  /// Contenido libre (si no se usa [header]/[rows]).
  final Widget? child;

  final Widget? toolbar;
  final Widget? header;
  final List<Widget> rows;
  final Widget? footer;
  final Widget? empty;
  final EdgeInsetsGeometry padding;

  /// Atenúa las filas + barra de progreso al paginar (fetch remoto).
  final bool rowsBusy;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final tableBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) header!,
        if (rowsBusy)
          LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: theme.surfaceSubtle,
            color: theme.brand,
          ),
        if (rows.isEmpty && empty != null)
          empty!
        else
          AnimatedOpacity(
            opacity: rowsBusy ? 0.55 : 1,
            duration: const Duration(milliseconds: 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
      ],
    );
    final body = child ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (toolbar != null) ...[
              toolbar!,
              const SizedBox(height: 12),
            ],
            Material(
              color: theme.tableRowEven,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.borderSubtle),
              ),
              child: tableBody,
            ),
            if (footer != null) ...[
              const SizedBox(height: 8),
              footer!,
            ],
          ],
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: theme.textPrimary.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.06,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(padding: padding, child: body),
    );
  }
}

/// Toolbar: buscador + píldoras + acción primaria (derecha).
class B2bDataTableToolbar extends StatelessWidget {
  const B2bDataTableToolbar({
    super.key,
    required this.searchController,
    this.searchHint = 'Buscar…',
    this.searchShortcutHint,
    this.onSearchChanged,
    this.filters = const <Widget>[],
    this.primaryAction,
    this.trailing,
  });

  final TextEditingController searchController;
  final String searchHint;

  /// Atajo visual opcional (p. ej. «⌘K»).
  final String? searchShortcutHint;
  final ValueChanged<String>? onSearchChanged;
  final List<Widget> filters;
  final Widget? primaryAction;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final search = TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: theme.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: searchHint,
        hintStyle: TextStyle(color: theme.textMuted, fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: theme.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 10, right: 6),
          child: LucideIcon(
            LucideGlyph.search,
            size: 16,
            color: theme.textMuted,
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
        suffixIcon: searchShortcutHint == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text(
                    searchShortcutHint!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.textMuted,
                    ),
                  ),
                ),
              ),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 640;
            final actions = <Widget>[
              ...?trailing,
              if (primaryAction != null) primaryAction!,
            ];
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  search,
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: actions,
                    ),
                  ],
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ...[
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      actions[i],
                    ],
                  ],
                ],
              ],
            );
          },
        ),
        if (filters.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < filters.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  filters[i],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Píldora de filtro rápido (segmentación inmediata).
class B2bDataTableFilterPill extends StatelessWidget {
  const B2bDataTableFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.glyph,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final LucideGlyph? glyph;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final bg = selected ? theme.brand : theme.brandContainer;
    final fg = selected ? theme.surfaceCard : theme.brand;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (glyph != null) ...[
                  LucideIcon(glyph!, size: 13, color: fg),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
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

class B2bDataTableHeaderCell {
  const B2bDataTableHeaderCell({
    required this.label,
    this.flex = 1,
    this.width,
  });

  final String label;
  final int flex;

  /// Si se define, la celda usa ancho fijo en lugar de [flex].
  final double? width;
}

/// Cabecera sticky visual (fondo `tableHeaderBg`).
class B2bDataTableHeader extends StatelessWidget {
  const B2bDataTableHeader({
    super.key,
    required this.cells,
    this.trailingWidth = 48,
    this.showTrailingSlot = true,
  });

  final List<B2bDataTableHeaderCell> cells;
  final double trailingWidth;
  final bool showTrailingSlot;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.tableHeaderBg,
        border: Border(bottom: BorderSide(color: theme.borderStrong)),
      ),
      child: Row(
        children: [
          for (final cell in cells)
            cell.width != null
                ? SizedBox(
                    width: cell.width,
                    child: _label(theme, cell.label),
                  )
                : Expanded(
                    flex: cell.flex,
                    child: _label(theme, cell.label),
                  ),
          if (showTrailingSlot) SizedBox(width: trailingWidth),
        ],
      ),
    );
  }

  Widget _label(B2BThemeExtension theme, String label) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: theme.textSecondary,
      ),
    );
  }
}

/// Fila con zebra dinámico.
class B2bDataTableZebraRow extends StatelessWidget {
  const B2bDataTableZebraRow({
    super.key,
    required this.zebra,
    required this.child,
    this.isLast = false,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 8, 12),
  });

  final bool zebra;
  final Widget child;
  final bool isLast;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: zebra ? theme.tableRowOdd : theme.tableRowEven,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(bottom: BorderSide(color: theme.borderSubtle)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Ítem tipado para [B2bDataRowActionsMenu].
class B2bDataRowAction {
  const B2bDataRowAction({
    required this.id,
    required this.label,
    this.glyph,
    this.destructive = false,
    this.enabled = true,
  });

  final String id;
  final String label;
  final LucideGlyph? glyph;
  final bool destructive;
  final bool enabled;
}

/// Menú de acciones por fila (Lucide + tokens de diálogo).
class B2bDataRowActionsMenu extends StatelessWidget {
  const B2bDataRowActionsMenu({
    super.key,
    required this.actions,
    required this.onSelected,
    this.tooltip = 'Acciones',
    this.busy = false,
  });

  final List<B2bDataRowAction> actions;
  final ValueChanged<String> onSelected;
  final String tooltip;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    if (busy) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.brand,
          ),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: tooltip,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.borderStrong),
      ),
      color: theme.dialogSurface,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final a in actions)
          PopupMenuItem<String>(
            value: a.id,
            enabled: a.enabled,
            child: Row(
              children: [
                if (a.glyph != null) ...[
                  LucideIcon(
                    a.glyph!,
                    size: 16,
                    color: a.destructive
                        ? Theme.of(context).colorScheme.error
                        : theme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    a.label,
                    style: TextStyle(
                      color: a.destructive
                          ? Theme.of(context).colorScheme.error
                          : theme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: LucideIcon(
          LucideGlyph.slidersHorizontal,
          size: 18,
          color: theme.textSecondary,
        ),
      ),
    );
  }
}

/// Badge de estado compacto (tokens dinámicos).
class B2bDataStatusBadge extends StatelessWidget {
  const B2bDataStatusBadge({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
