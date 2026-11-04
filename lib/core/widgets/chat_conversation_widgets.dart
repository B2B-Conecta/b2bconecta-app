import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
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
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => IconButton.filled(
                    tooltip: 'Enviar mensaje',
                    onPressed: sending ||
                            (!hasAttachment && controller.text.trim().isEmpty)
                        ? null
                        : onSend,
                    icon: sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 19),
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
    this.icon = Icons.chat_bubble_outline_rounded,
    this.onRetry,
  });

  final String title;
  final String? description;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: AppColors.textSecondary),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(description!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
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
                      color: AppColors.textSecondary,
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
      return Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isAction
                  ? AppColors.card
                  : mine
                      ? AppColors.brandBlueContainer
                      : AppColors.surfaceTinted,
              border:
                  isAction ? Border.all(color: AppColors.borderSubtle) : null,
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
                      child: Text(author!,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          )),
                    ),
                  child,
                  if (time != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                          showDate
                              ? '${formatEsShortDate(local!)} · $time'
                              : time,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          )),
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
