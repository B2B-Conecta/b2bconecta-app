import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Tarjeta de consulta con ficha del contacto (aliado) y CTA futuro de chat.
class InquiryMessageCard extends StatelessWidget {
  const InquiryMessageCard({
    super.key,
    required this.message,
    this.showProductMeta = false,
  });

  final ProductMessageRow message;
  final bool showProductMeta;

  static String _formatDateTime(DateTime d) {
    final x = d.toLocal();
    final dd = x.day.toString().padLeft(2, '0');
    final mm = x.month.toString().padLeft(2, '0');
    final hh = x.hour.toString().padLeft(2, '0');
    final min = x.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${x.year} · $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(message.senderDisplayName);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showProductMeta) ...[
            Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (message.productSku != null &&
                message.productSku!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 26),
                child: Text(
                  'SKU: ${message.productSku}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.brandBlue.withOpacity(0.15),
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.brandBlue,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.senderDisplayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aliado · consulta',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (message.senderRif != null &&
                        message.senderRif!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _InfoLine(
                        icon: Icons.badge_outlined,
                        text: 'RIF: ${message.senderRif}',
                      ),
                    ],
                    if (message.senderPhone != null &&
                        message.senderPhone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _InfoLine(
                        icon: Icons.phone_outlined,
                        text: message.senderPhone!,
                      ),
                    ],
                    if ((message.senderRif == null ||
                            message.senderRif!.isEmpty) &&
                        (message.senderPhone == null ||
                            message.senderPhone!.isEmpty))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Datos de contacto incompletos en el perfil del aliado.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              message.body,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDateTime(message.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Chat con ${message.senderDisplayName} estará disponible '
                    'cuando activemos el módulo de mensajes.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            label: const Text('Hablar con el contacto'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    final parts = p.take(2).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].length >= 2
          ? parts[0].substring(0, 2).toUpperCase()
          : parts[0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
