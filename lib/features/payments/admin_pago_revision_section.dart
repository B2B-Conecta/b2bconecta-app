import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/stored_file_page.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/unified_action_dialog.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';

String adminEstadoPagoLabelEs(TransactionRequestModel r) {
  final pe = r.pagoEstadoRevisionEfectivo;
  final m = r.pagoMetodo?.trim();
  final efectivo = m == PagoMetodo.efectivo;

  switch (pe) {
    case PagoRevisionEstado.pendiente:
      return efectivo
          ? 'Pendiente de comprobante de efectivo de la tienda minorista'
          : 'Pendiente de comprobante de la tienda minorista';
    case PagoRevisionEstado.enRevision:
      if (efectivo && !r.hasComprobantePago) {
        return 'Pago en efectivo en revisión';
      }
      return 'Comprobante en revisión';
    case PagoRevisionEstado.aprobado:
      return efectivo ? 'Pago en efectivo aprobado' : 'Pago aprobado';
    case PagoRevisionEstado.rechazado:
      return efectivo
          ? 'Comprobante de efectivo rechazado (tienda minorista puede reenviar)'
          : 'Comprobante rechazado (tienda minorista puede reenviar)';
    default:
      return pe;
  }
}

ButtonStyle _softOutlineStyle(
  B2BThemeExtension theme, {
  required Color fg,
  required Color bg,
}) {
  return OutlinedButton.styleFrom(
    foregroundColor: fg,
    backgroundColor: bg,
    side: BorderSide(color: fg.withOpacity(0.35)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    minimumSize: const Size(0, 36),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
  );
}

/// Revisión del pago del aliado (comprobante / efectivo): ver archivo y aprobar o rechazar.
class AdminPagoRevisionSection extends StatefulWidget {
  const AdminPagoRevisionSection({
    super.key,
    required this.request,
    required this.onRefresh,
    this.highlightEntregadoPagado = false,
    this.includeSectionTitle = true,
  });

  final TransactionRequestModel request;
  final VoidCallback onRefresh;
  final bool highlightEntregadoPagado;
  final bool includeSectionTitle;

  /// Etiqueta legible del estado de pago (usada también fuera del panel).
  static String estadoPagoLabelEs(TransactionRequestModel r) =>
      adminEstadoPagoLabelEs(r);

  @override
  State<AdminPagoRevisionSection> createState() =>
      _AdminPagoRevisionSectionState();
}

class _AdminPagoRevisionSectionState extends State<AdminPagoRevisionSection> {
  bool _busyAprobar = false;
  bool _busyRechazar = false;

  Future<void> _openUrl(
    BuildContext context,
    Future<String> Function() signed, {
    String? fileName,
  }) {
    return openStoredFile(
      context,
      signedUrl: signed,
      fileName: fileName,
    );
  }

  Future<void> _aprobarPago(BuildContext context) async {
    setState(() => _busyAprobar = true);
    try {
      await SupabaseService.adminAprobarPagoAliado(widget.request.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago aprobado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _busyAprobar = false);
    }
  }

  Future<void> _rechazarPago(BuildContext context) async {
    final theme = B2BThemeExtension.of(context);
    final ctrl = TextEditingController();
    try {
      final ok = await UnifiedActionDialog.show<bool>(
        context: context,
        builder: (ctx) => UnifiedActionDialog(
          title: 'Rechazar comprobante',
          subtitle: 'La tienda podrá enviar uno nuevo.',
          glyph: LucideGlyph.circleAlert,
          tone: UnifiedActionTone.warning,
          primaryLabel: 'Rechazar comprobante',
          onPrimary: () => Navigator.of(ctx).pop(true),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Motivo opcional con indicaciones para la tienda minorista.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 3,
                autofocus: true,
                style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  labelText: 'Motivo / indicaciones',
                  filled: true,
                  fillColor: theme.inputFill,
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
              ),
            ],
          ),
        ),
      );
      if (ok != true || !context.mounted) return;

      final nota = ctrl.text;
      setState(() => _busyRechazar = true);
      try {
        await SupabaseService.adminRechazarComprobantePago(
          requestId: widget.request.id,
          nota: nota,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comprobante rechazado.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onRefresh();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) setState(() => _busyRechazar = false);
      }
    } finally {
      ctrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final r = widget.request;
    if (!r.hasProveedorFactura) return const SizedBox.shrink();

    final pe = r.pagoEstadoRevisionEfectivo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.includeSectionTitle) ...[
          Text(
            'Pago de la tienda minorista',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'Estado: ${adminEstadoPagoLabelEs(r)}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: theme.brand,
          ),
        ),
        if (widget.highlightEntregadoPagado &&
            pe == PagoRevisionEstado.aprobado &&
            r.status == TransactionRequestStatus.entregado) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: theme.successBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.successFg.withOpacity(0.28)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LucideIcon(
                  LucideGlyph.circleCheck,
                  size: 18,
                  color: theme.successFg,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pedido entregado y pagado.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: theme.successFg,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (r.pagoMetodo != null && r.pagoMetodo!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Método declarado: ${PagoMetodo.labelEs(r.pagoMetodo!)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textPrimary,
            ),
          ),
        ],
        if (r.hasComprobantePago) ...[
          const SizedBox(height: 4),
          Text(
            'Comprobante: ${r.comprobantePagoFileName ?? 'archivo'} · '
            '${formatEsShortDateTime(r.comprobantePagoSubmittedAt)}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _openUrl(
                context,
                () => SupabaseService.createSignedUrlForComprobantePago(
                  r.comprobantePagoStoragePath!.trim(),
                ),
                fileName: r.comprobantePagoFileName,
              ),
              icon: LucideIcon(
                LucideGlyph.fileText,
                size: 15,
                color: theme.brand,
              ),
              label: const Text('Ver comprobante'),
              style: _softOutlineStyle(
                theme,
                fg: theme.brand,
                bg: theme.brandContainer,
              ),
            ),
          ),
        ],
        if (r.pagoComprobanteRechazoNota != null &&
            r.pagoComprobanteRechazoNota!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Último rechazo: ${r.pagoComprobanteRechazoNota}',
            style: TextStyle(
              fontSize: 11.5,
              color: Theme.of(context).colorScheme.error,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (pe == PagoRevisionEstado.enRevision) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busyAprobar ? null : () => _aprobarPago(context),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.brand,
                  foregroundColor: theme.surfaceCard,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _busyAprobar
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.surfaceCard,
                        ),
                      )
                    : LucideIcon(
                        LucideGlyph.check,
                        size: 15,
                        color: theme.surfaceCard,
                      ),
                label: Text(_busyAprobar ? 'Aprobando…' : 'Aprobar pago'),
              ),
              OutlinedButton.icon(
                onPressed: _busyRechazar ? null : () => _rechazarPago(context),
                style: _softOutlineStyle(
                  theme,
                  fg: Theme.of(context).colorScheme.error,
                  bg: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0x26DC2626)
                      : const Color(0xFFFEF2F2),
                ),
                icon: _busyRechazar
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : LucideIcon(
                        LucideGlyph.close,
                        size: 15,
                        color: Theme.of(context).colorScheme.error,
                      ),
                label: Text(
                  _busyRechazar ? 'Rechazando…' : 'Rechazar comprobante',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
