import 'package:flutter/material.dart';

import 'kyc_approved_aliado_model.dart';
import 'kyc_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/profile/profile_section_helpers.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_counterparty_profile_section.dart';

Future<void> showImporterAliadoKycDetailSheet(
  BuildContext context, {
  required KycApprovedAliadoModel aliado,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Expediente KYC',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const ProfileInfoIcon(
                    title: 'Expediente KYC',
                    message: OrderSectionHelp.aliadoKycCredit,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
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
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TransactionRequestCounterpartyProfileSection(
                profileId: aliado.id,
                partyLabel: 'Aliado',
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
    },
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
    if (n == 0) return 'Ningún aliado verificado';
    if (n == 1) return '1 aliado verificado';
    return '$n aliados verificados';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return ProfileCollapsibleSection(
      title: 'Aliados verificados (KYC)',
      subtitle: _sectionSubtitle(),
      initiallyExpanded: false,
      infoMessage:
          'Aliados con KYC aprobado',
      trailingActions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: 'Actualizar',
          visualDensity: VisualDensity.compact,
        ),
      ],
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
              style: TextStyle(color: Colors.red.shade800, fontSize: 12),
            )
          else ...[
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, RIF o ciudad…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: AppColors.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: AppDecorations.radius12,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_rows.isEmpty)
              Text(
                'Aún no hay aliados con KYC aprobado en la plataforma.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            else if (filtered.isEmpty)
              Text(
                'Ningún aliado coincide con la búsqueda.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            else
              ...filtered.map((a) => _AliadoKycListTile(
                    aliado: a,
                    onTap: () => showImporterAliadoKycDetailSheet(
                      context,
                      aliado: a,
                    ),
                  )),
          ],
        ],
      ),
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
    final rating = aliado.ratingAsPayerAvgRolling100;
    final ratingCount = aliado.ratingAsPayerCountRolling100 ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.brandBlueContainer.withOpacity(0.25),
        borderRadius: AppDecorations.radius12,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aliado.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                      if (loc.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          loc,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '${aliado.approvedDocumentCount} doc. aprobados'
                        '${rating != null && ratingCount > 0 ? ' · Pago ${rating.toStringAsFixed(1)}/5' : ''}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.brandBlue,
                  size: 20,
                ),
                Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
