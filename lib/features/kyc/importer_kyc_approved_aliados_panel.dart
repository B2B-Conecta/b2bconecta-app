import 'package:flutter/material.dart';

import 'kyc_approved_aliado_model.dart';
import 'kyc_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/orders/shared/order_flow_copy/order_section_help.dart';
import 'package:motolink_pro_app/features/profile/profile_section_helpers.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_counterparty_profile_section.dart';

/// Ficha de una tienda activa: nombre, RIF, ubicación y contacto.
/// El sello «Activa» vive en el listado, no se repite aquí.
Future<void> showImporterActiveStoreSheet(
  BuildContext context, {
  required KycApprovedAliadoModel aliado,
}) async {
  final theme = B2BThemeExtension.of(context);
  final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;

  Widget body(BuildContext ctx) {
    final sheet = B2BThemeExtension.of(ctx);
    final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
    final lines = <(String, String)>[
      if ((aliado.rif ?? '').trim().isNotEmpty) ('RIF', aliado.rif!.trim()),
      if (aliado.locationLine.isNotEmpty) ('Ubicación', aliado.locationLine),
      if ((aliado.direccion ?? '').trim().isNotEmpty)
        ('Dirección', aliado.direccion!.trim()),
      if ((aliado.phone ?? '').trim().isNotEmpty)
        ('Contacto', aliado.phone!.trim()),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  aliado.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: sheet.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(ctx),
                icon: Icon(Icons.close, color: sheet.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines) ...[
            Text(
              line.$1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: sheet.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              line.$2,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: sheet.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  if (wide) {
    await showDialog<void>(
      context: context,
      barrierColor: theme.textPrimary.withOpacity(0.45),
      builder: (ctx) => Dialog(
        backgroundColor: theme.dialogSurface,
        surfaceTintColor: theme.dialogSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.borderSubtle),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: body(ctx),
        ),
      ),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.dialogSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: body,
  );
}

Future<void> showImporterAliadoKycDetailSheet(
  BuildContext context, {
  required KycApprovedAliadoModel aliado,
}) async {
  final theme = B2BThemeExtension.of(context);
  final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
  Widget body(BuildContext ctx) {
    final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
    final sheet = B2BThemeExtension.of(ctx);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Expediente KYC',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: sheet.textPrimary,
                    ),
                  ),
                ),
                const ProfileInfoIcon(
                  title: 'Expediente KYC',
                  message: OrderSectionHelp.aliadoKycCredit,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(Icons.close, color: sheet.textPrimary),
                ),
              ],
            ),
            if (aliado.ratingAsPayerAvgRolling100 != null &&
                (aliado.ratingAsPayerCountRolling100 ?? 0) > 0) ...[
              Text(
                'Reputación como pagador: '
                '${aliado.ratingAsPayerAvgRolling100!.toStringAsFixed(1)} / 5 '
                '(${aliado.ratingAsPayerCountRolling100} valoraciones)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sheet.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
            ],
            TransactionRequestCounterpartyProfileSection(
              profileId: aliado.id,
              partyLabel: 'Tienda minorista',
              businessName: aliado.businessName,
              rif: aliado.rif,
              phone: aliado.phone,
              estado: aliado.estado,
              ciudad: aliado.ciudad,
              direccion: aliado.direccion,
              fiscalMapsUrl: aliado.fiscalMapsUrl,
              logoStoragePath: aliado.logoStoragePath,
              kycStatus: aliado.kycStatus ?? KycStatus.aprobado,
              loadApprovedDocuments: true,
            ),
          ],
        ),
      ),
    );
  }

  if (wide) {
    await showDialog<void>(
      context: context,
      barrierColor: theme.textPrimary.withOpacity(0.45),
      builder: (ctx) => Dialog(
        backgroundColor: theme.dialogSurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.82,
          ),
          child: body(ctx),
        ),
      ),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.dialogSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: body,
  );
}

/// Directorio de aliados con KYC aprobado (importador).
class ImporterKycApprovedAliadosPanel extends StatefulWidget {
  const ImporterKycApprovedAliadosPanel({super.key});

  @override
  State<ImporterKycApprovedAliadosPanel> createState() =>
      _ImporterKycApprovedAliadosPanelState();
}

class _ImporterKycApprovedAliadosPanelState
    extends State<ImporterKycApprovedAliadosPanel> {
  final _searchCtrl = TextEditingController();
  List<KycApprovedAliadoModel> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.listKycApprovedAliadosForImportador();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<KycApprovedAliadoModel> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((a) {
      final hay = [
        a.displayName,
        a.rif,
        a.estado,
        a.ciudad,
      ].whereType<String>().join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  String _sectionSubtitle() {
    if (_loading) return 'Cargando…';
    if (_error != null) return 'Error al cargar';
    final n = _rows.length;
    if (n == 0) return 'Ninguna tienda minorista';
    if (n == 1) return '1 tienda minorista';
    return '$n tiendas minoristas';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final theme = B2BThemeExtension.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tiendas activas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _sectionSubtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const ProfileInfoIcon(
                title: 'Tiendas activas',
                message: 'Nombre, RIF, ubicación y contacto de cada tienda.',
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: Icon(Icons.refresh, size: 18, color: theme.textSecondary),
                tooltip: 'Actualizar',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(Icons.close, size: 18, color: theme.textSecondary),
                tooltip: 'Cerrar',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            )
          else ...[
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, RIF o ciudad…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: theme.inputFill,
                border: OutlineInputBorder(
                  borderRadius: AppDecorations.radius12,
                  borderSide: BorderSide(color: theme.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppDecorations.radius12,
                  borderSide: BorderSide(color: theme.borderSubtle),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_rows.isEmpty)
              Text(
                'Aún no hay tiendas minoristas con KYC aprobado en la plataforma.',
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              )
            else if (filtered.isEmpty)
              Text(
                'Ninguna tienda minorista coincide con la búsqueda.',
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              )
            else
              PagedItems(
                items: filtered,
                embedded: true,
                separator: 8,
                itemBuilder: (a) => _AliadoKycListTile(
                  aliado: a,
                  onTap: () => showImporterActiveStoreSheet(
                    context,
                    aliado: a,
                  ),
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

class _AliadoKycListTile extends StatelessWidget {
  const _AliadoKycListTile({
    required this.aliado,
    required this.onTap,
  });

  final KycApprovedAliadoModel aliado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = aliado.locationLine;
    final rif = aliado.rif?.trim() ?? '';
    final phone = aliado.phone?.trim() ?? '';
    final theme = B2BThemeExtension.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.radius12,
          side: BorderSide(color: theme.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.brandContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: LucideIcon(
                        LucideGlyph.store,
                        size: 18,
                        color: theme.brand,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              aliado.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: theme.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.successBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              child: Text(
                                'Activa',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.successFg,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (rif.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          rif,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                      if (loc.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          loc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                LucideIcon(
                  LucideGlyph.chevronRight,
                  size: 16,
                  color: theme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
