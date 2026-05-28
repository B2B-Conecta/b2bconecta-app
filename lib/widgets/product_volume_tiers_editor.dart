import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/product_volume_tiers.dart';

/// Editor simple de tramos E4 (min_units + %).
class ProductVolumeTiersEditor extends StatefulWidget {
  const ProductVolumeTiersEditor({
    super.key,
    required this.tiers,
    required this.onChanged,
  });

  final List<ProductVolumeTier> tiers;
  final ValueChanged<List<ProductVolumeTier>> onChanged;

  @override
  State<ProductVolumeTiersEditor> createState() =>
      _ProductVolumeTiersEditorState();
}

class _ProductVolumeTiersEditorState extends State<ProductVolumeTiersEditor> {
  late List<ProductVolumeTier> _tiers;

  @override
  void initState() {
    super.initState();
    _tiers = [...widget.tiers];
  }

  void _emit() {
    widget.onChanged([..._tiers]..sort((a, b) => a.minUnits.compareTo(b.minUnits)));
  }

  Future<void> _addTier() async {
    final minCtrl = TextEditingController();
    final pctCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tramo por volumen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Unidades mínimas (mismo SKU)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pctCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Descuento adicional (%)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final min = int.tryParse(minCtrl.text.trim());
    final pct = double.tryParse(pctCtrl.text.trim().replaceAll(',', '.'));
    if (min == null || min < 1 || pct == null || pct <= 0 || pct > 100) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unidades ≥ 1 y porcentaje entre 0 y 100.'),
        ),
      );
      return;
    }
    setState(() {
      _tiers.add(ProductVolumeTier(minUnits: min, percentDiscount: pct));
      _tiers.sort((a, b) => a.minUnits.compareTo(b.minUnits));
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Descuento por cantidad (mismo SKU)',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ej.: desde 12 unidades, 5 % adicional sobre el precio mayorista. '
          'Se suma en checkout antes de la comisión MotoLink.',
          style: TextStyle(fontSize: 11.5, height: 1.35, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        if (_tiers.isEmpty)
          Text(
            'Sin tramos configurados.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          )
        else
          ..._tiers.map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Desde ${t.minUnits} unidades: '
                '${t.percentDiscount.toStringAsFixed(t.percentDiscount.truncateToDouble() == t.percentDiscount ? 0 : 1)} % de descuento',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () {
                  setState(() => _tiers.remove(t));
                  _emit();
                },
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addTier,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Añadir tramo'),
          ),
        ),
      ],
    );
  }
}
