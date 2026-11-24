import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/widgets/b2b_header_title.dart';
import '../../../app/theme/b2b_theme_extension.dart';
import '../../catalog/importer_catalog_logo.dart';
import '../../inventory/product_images.dart';
import 'order_chat_thread.dart';
import 'transaction_request_status.dart';

const mobileChatBlue = Color(0xFF004BDD);

class ChatBusinessAvatar extends StatelessWidget {
  const ChatBusinessAvatar(
      {super.key, required this.name, this.logoPath, this.size = 52});
  final String name;
  final String? logoPath;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
          child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border:
                Border.all(color: B2BThemeExtension.of(context).borderSubtle)),
        clipBehavior: Clip.antiAlias,
        child: ImporterCatalogLogo(
            storagePath: logoPath,
            size: size,
            fallback: Center(
                child: Text(
                    name.trim().isEmpty
                        ? '?'
                        : name.trim().characters.first.toUpperCase(),
                    style: TextStyle(
                        fontSize: size * .38,
                        fontWeight: FontWeight.w700,
                        color: mobileChatBlue)))),
      ));
}

class MobileChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MobileChatAppBar(
      {super.key,
      required this.title,
      this.subtitle,
      this.logoPath,
      this.showAvatar = false,
      this.actions,
      this.bottom,
      this.automaticallyImplyLeading = true});
  final String title;
  final String? subtitle, logoPath;
  final bool showAvatar, automaticallyImplyLeading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(72 + (bottom?.preferredSize.height ?? 0));
  @override
  Widget build(BuildContext context) => AppBar(
      backgroundColor: mobileChatBlue,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 72,
      automaticallyImplyLeading: automaticallyImplyLeading,
      titleSpacing: 0,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
      title: Row(children: [
        if (showAvatar) ...[
          ChatBusinessAvatar(name: title, logoPath: logoPath, size: 42),
          const SizedBox(width: 10)
        ],
        Expanded(
            child: B2bHeaderTitle(
          title: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700)),
          subtitle: switch (subtitle) {
            final text? => Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFE5EFFF), fontSize: 12)),
            null => null,
          },
        )),
      ]),
      actions: actions,
      bottom: bottom);
}

/// Real order data; a group with mixed statuses retains its aggregate label.
class MobileOrderChatCard extends StatelessWidget {
  const MobileOrderChatCard(
      {super.key, required this.thread, this.onOpenOrder});
  final OrderChatThread thread;
  final VoidCallback? onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final cover =
        thread.lines.expand((line) => line.productImageUrls).firstOrNull;
    final image = cover == null ? null : productCoverImageUrl([cover]);
    final statusIcon = switch (thread.status) {
      TransactionRequestStatus.enTransito ||
      TransactionRequestStatus.enviado =>
        Icons.local_shipping_outlined,
      TransactionRequestStatus.entregado => Icons.check_circle_outline,
      TransactionRequestStatus.enPreparacion => Icons.inventory_2_outlined,
      TransactionRequestStatus.pedidoListo => Icons.storefront_outlined,
      TransactionRequestStatus.pendiente => Icons.schedule,
      _ => null,
    };
    return Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: theme.brandContainer,
            borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 58,
              height: 64,
              decoration: BoxDecoration(
                  color: theme.surfaceCard,
                  borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: image == null
                  ? Icon(Icons.inventory_2_outlined, color: theme.textSecondary)
                  : Image.network(image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.inventory_2_outlined,
                          color: theme.textSecondary))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${thread.reference} · ${thread.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 5),
                Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: theme.surfaceCard,
                              borderRadius: BorderRadius.circular(9)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (statusIcon != null) ...[
                              Icon(statusIcon,
                                  size: 16, color: theme.textPrimary),
                              const SizedBox(width: 5)
                            ],
                            Flexible(
                                child: Text(thread.statusLabel,
                                    style: TextStyle(
                                        color: theme.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)))
                          ])),
                      if (onOpenOrder != null)
                        TextButton(
                            onPressed: onOpenOrder,
                            style: TextButton.styleFrom(
                                foregroundColor: theme.brand,
                                minimumSize: const Size(0, 44),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4)),
                            child: const Text('Ver pedido →')),
                    ]),
              ])),
        ]));
  }
}
