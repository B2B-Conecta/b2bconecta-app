import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../config/referral_invite_config.dart';
import '../theme/app_theme.dart';

/// Escanea un QR de referido (URL `?ref=` o código plano).
/// Disponible en app nativa y en web (pide permiso de cámara del navegador).
class ReferralQrScanSheet extends StatefulWidget {
  const ReferralQrScanSheet({super.key});

  /// Abre el escáner y devuelve el código normalizado, o null.
  static Future<String?> scan(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const ReferralQrScanSheet(),
    );
  }

  @override
  State<ReferralQrScanSheet> createState() => _ReferralQrScanSheetState();
}

class _ReferralQrScanSheetState extends State<ReferralQrScanSheet> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _parseCode(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    if (t.isEmpty) return null;
    final uri = Uri.tryParse(t);
    if (uri != null && (uri.hasQuery || uri.fragment.isNotEmpty)) {
      final fromUri = ReferralInviteConfig.codeFromUri(uri);
      if (fromUri != null && fromUri.isNotEmpty) return fromUri;
    }
    // Código plano en el QR
    final plain = ReferralInviteConfig.normalizeCode(t);
    return plain.isEmpty ? null : plain;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final b in capture.barcodes) {
      final code = _parseCode(b.rawValue);
      if (code == null) continue;
      _handled = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Escanear QR de referido',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Apunte la cámara al código QR del vendedor. '
                'También puede escribir el código manualmente.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    return ColoredBox(
                      color: Colors.black87,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'No se pudo abrir la cámara.\n'
                            'Permita el acceso en el navegador o escriba el código.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
