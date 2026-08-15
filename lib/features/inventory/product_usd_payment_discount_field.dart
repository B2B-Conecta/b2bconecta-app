import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Campo importador: % de descuento en la línea USD del catálogo aliado.
class ProductUsdPaymentDiscountField extends StatelessWidget {
  const ProductUsdPaymentDiscountField({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.attach_money, size: 20, color: Colors.green.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Descuento en precio USD (catálogo aliado)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Opcional. El aliado verá el precio REF y, aparte, un precio USD '
          'con este porcentaje de rebaja (ej. 2 → paga 2 % menos en USD). '
          'Use 0 para quitar el descuento USD del producto.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
          decoration: InputDecoration(
            labelText: 'Porcentaje de descuento USD',
            hintText: 'Ej. 2',
            suffixText: '%',
            filled: true,
            fillColor: AppColors.fieldFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

/// Parsea el texto del campo.
/// Vacío → no se envía %; `0` → quitar descuento USD; `>0` → aplicar %.
double? parseUsdPaymentDiscountPctField(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  final pct = double.tryParse(t.replaceAll(',', '.'));
  if (pct == null || pct < 0 || pct >= 100) return null;
  return pct;
}
