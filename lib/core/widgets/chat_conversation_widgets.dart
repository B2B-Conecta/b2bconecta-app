import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.sending,
    this.hint = 'Escribe un mensaje…',
    this.leading,
    this.contextNote,
    this.hasAttachment = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final String hint;
  final Widget? leading;
  final Widget? contextNote;
  final bool hasAttachment;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        border: Border(top: BorderSide(color: theme.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (contextNote != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: contextNote,
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 4)],
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !sending,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: theme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(color: theme.textMuted),
                      filled: true,
                      fillColor: theme.surfaceSubtle,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
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
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => Tooltip(
                    message: 'Enviar mensaje',
                    child: Material(
                      color: theme.brand,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: sending ||
                                (!hasAttachment &&
                                    controller.text.trim().isEmpty)
                            ? null
                            : onSend,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: sending
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.surfaceCard,
                                    ),
                                  )
                                : Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                    color: theme.surfaceCard,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChatConversationNotice extends StatelessWidget {
  const ChatConversationNotice({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.onRetry,
  });

  final String title;
  final String? description;
  final IconData? icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon == null
                ? LucideIcon(
                    LucideGlyph.messageSquare,
                    size: 28,
                    color: theme.textMuted,
                  )
                : Icon(icon, size: 28, color: theme.textMuted),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: theme.textPrimary,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textSecondary, fontSize: 12),
              ),
            ],
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class ChatTimeline extends StatelessWidget {
  const ChatTimeline({
    super.key,
    required this.itemCount,
    required this.dateAt,
    required this.messageAt,
  });

  final int itemCount;
  final DateTime? Function(int index) dateAt;
  final Widget Function(int index) messageAt;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return ListView.builder(
      reverse: true,
      primary: false,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final i = itemCount - 1 - index;
        final date = dateAt(i)?.toLocal();
        final previous = i == 0 ? null : dateAt(i - 1)?.toLocal();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              if (date != null && !DateUtils.isSameDay(date, previous))
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                  child: Text(
                    formatEsShortDate(date),
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              messageAt(i),
            ],
          ),
        );
      },
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.mine,
    required this.at,
    required this.child,
    this.author,
    this.isAction = false,
    this.showDate = false,
  });

  final bool mine;
  final DateTime? at;
  final String? author;
  final bool isAction;
  final bool showDate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final local = at?.toLocal();
    final formats = MaterialLocalizations.of(context);
    final time = local == null
        ? null
        : formats.formatTimeOfDay(
            TimeOfDay.fromDateTime(local),
            alwaysUse24HourFormat: true,
          );
    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = (constraints.maxWidth * (isAction ? 0.96 : 0.86))
          .clamp(0.0, 500.0)
          .toDouble();
      final Color bubbleBg;
      if (isAction) {
        bubbleBg = theme.surfaceCard;
      } else if (mine) {
        bubbleBg = theme.brandContainer;
      } else {
        bubbleBg = theme.surfaceSubtle;
      }
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bubbleBg,
              border: isAction
                  ? Border.all(color: theme.borderSubtle)
                  : Border.all(
                      color: mine
                          ? theme.brand.withOpacity(0.18)
                          : theme.borderSubtle,
                    ),
              borderRadius: BorderRadius.circular(isAction ? 14 : 12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (author != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        author!,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                    child: child,
                  ),
                  if (time != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        showDate
                            ? '${formatEsShortDate(local!)} · $time'
                            : time,
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
