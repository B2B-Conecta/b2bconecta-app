import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'inventory_qr_label.dart';

class InventoryQrScanSheet extends StatefulWidget {
  const InventoryQrScanSheet({super.key});

  @override
  State<InventoryQrScanSheet> createState() => _InventoryQrScanSheetState();
}

class _InventoryQrScanSheetState extends State<InventoryQrScanSheet> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _handled = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _detect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;
    final values = capture.barcodes
        .map((code) => code.rawValue)
        .whereType<String>()
        .toSet();
    if (values.length != 1) {
      _show('Apunta a una sola etiqueta.');
      return;
    }
    final id = InventoryQrLabel.productId(values.single);
    if (id == null) {
      _show('Usa una etiqueta QR generada en Inventario.');
      return;
    }
    _handled = true;
    Navigator.pop(context, id);
  }

  void _show(String message) {
    if (_message != message) setState(() => _message = message);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              Text('Escanear etiqueta de inventario',
                  style: Theme.of(context).textTheme.titleMedium),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_message ??
                    'Coloca una sola etiqueta dentro del encuadre.'),
              ),
              Expanded(
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _detect,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text(
                        'No se pudo abrir la cámara. Revisa el permiso de acceso.'),
                  ),
                ),
              ),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
            ],
          ),
        ),
      );
}
