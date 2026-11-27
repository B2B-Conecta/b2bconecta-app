import 'package:flutter/material.dart';
import '../../app/theme/b2b_theme_extension.dart';
import '../../core/widgets/b2b_header_title.dart';
import '../../core/widgets/lucide_icon.dart';
import 'support_ticket_status.dart';

const supportMobileBlue = Color(0xFF004BDD);
const supportOpenLimit = 3;

String supportReference(String id) {
  final value = id.trim().replaceAll('-', '').toUpperCase();
  return '#SOP-${value.substring(0, value.length < 8 ? value.length : 8)}';
}

bool supportLimitReached(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('3 reclamos abiertos');
}

String supportFailureMessage(Object error) {
  if (supportLimitReached(error)) {
    return 'Ya tienes tres reclamos abiertos. Puedes continuar en uno de ellos o cerrar un caso que ya no necesites.';
  }
  final text = error.toString().toLowerCase();
  if (text.contains('sesión activa') || text.contains('jwt expired')) {
    return 'Tu sesión venció. Vuelve a iniciar sesión para continuar.';
  }
  if (text.contains('pedido vinculado no pertenece')) {
    return 'No pudimos vincular ese pedido a tu cuenta. Abre soporte desde el pedido correspondiente.';
  }
  return 'No pudimos enviar tu reclamo. Conservamos lo que escribiste para que puedas reintentar.';
}

PreferredSizeWidget mobileSupportAppBar(BuildContext context, String title,
        {List<Widget>? actions, VoidCallback? onBack, bool avatar = false}) =>
    AppBar(
      backgroundColor: supportMobileBlue,
      foregroundColor: Colors.white,
      titleTextStyle:
          Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: MediaQuery.textScalerOf(context).scale(18) > 23 ? 96 : 72,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
      leading: BackButton(onPressed: onBack),
      titleSpacing: 0,
      title: Row(children: [
        if (avatar) ...[
          Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Center(
                  child: LucideIcon(LucideGlyph.headset,
                      size: 22, color: supportMobileBlue))),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: B2bHeaderTitle(
            title: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ]),
      actions: actions,
    );

class SupportStatusChip extends StatelessWidget {
  const SupportStatusChip({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final closed = status == SupportTicketStatus.cerrado;
    final reviewing = status == SupportTicketStatus.enRevision;
    final bg = closed
        ? theme.surfaceSubtle
        : reviewing
            ? theme.warningBg
            : theme.brandContainer;
    final fg = closed
        ? theme.textSecondary
        : reviewing
            ? theme.warningFg
            : theme.brand;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(SupportTicketStatus.labelEs(status),
            style: TextStyle(
                color: fg, fontSize: 12, fontWeight: FontWeight.w700)));
  }
}

class SupportInfoNotice extends StatelessWidget {
  const SupportInfoNotice(this.text, {super.key, this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: error ? theme.warningBg : theme.brandContainer,
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(error ? Icons.error_outline : Icons.info_outline,
              size: 20, color: error ? theme.warningFg : theme.brand),
          const SizedBox(width: 9),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: theme.textPrimary, fontSize: 13, height: 1.35))),
        ]));
  }
}
