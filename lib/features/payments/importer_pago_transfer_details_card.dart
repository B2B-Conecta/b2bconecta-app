import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pago_metodo.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Datos de transferencia del importador para el método elegido (vista aliado).
class ImporterPagoTransferDetailsCard extends StatelessWidget {
  const ImporterPagoTransferDetailsCard({
    super.key,
    required this.metodo,
    required this.instrucciones,
    this.importadorNombre,
    this.sinDatosMensaje,
  });

  final String metodo;
  final String? instrucciones;
  final String? importadorNombre;
  final String? sinDatosMensaje;

  @override
  Widget build(BuildContext context) {
    final text = instrucciones?.trim();
    final hasText = text != null && text.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer.withOpacity(0.45),
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: AppColors.brandBlue.withOpacity(0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Datos para ${PagoMetodo.labelEs(metodo)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandBlue,
                        ),
                      ),
                      if (importadorNombre != null &&
                          importadorNombre!.trim().isNotEmpty)
                        Text(
                          importadorNombre!.trim(),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasText)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copiar datos',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Datos copiados al portapapeles.'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasText)
              SelectableText(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              Text(
                sinDatosMensaje?.trim().isNotEmpty == true
                    ? sinDatosMensaje!.trim()
                    : 'El importador aún no registró los datos de esta cuenta. '
                        'Confirme por chat antes de transferir.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.brandBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
