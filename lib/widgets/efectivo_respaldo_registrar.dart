import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/transaction_request_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Foto de respaldo del cobro en efectivo (transportista o MotoLink).
/// Puede registrarse durante tránsito o después de entregado (solo una vez).
class EfectivoRespaldoRegistrar extends StatefulWidget {
  const EfectivoRespaldoRegistrar({
    super.key,
    required this.request,
    required this.onRegistered,
  });

  final TransactionRequestModel request;
  final VoidCallback onRegistered;

  @override
  State<EfectivoRespaldoRegistrar> createState() =>
      _EfectivoRespaldoRegistrarState();
}

class _EfectivoRespaldoRegistrarState extends State<EfectivoRespaldoRegistrar> {
  bool _busy = false;

  Future<void> _tomarYSubir(BuildContext context) async {
    final r = widget.request;
    if (!r.puedeRegistrarRespaldoEfectivo) return;

    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 2200,
    );
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    if (bytes.isEmpty) return;
    final name = xfile.name.trim().isEmpty ? 'efectivo_respaldo.jpg' : xfile.name;

    setState(() => _busy = true);
    try {
      await SupabaseService.registrarRespaldoCobroEfectivo(
        transactionRequestId: r.id,
        bytes: bytes,
        fileName: name,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Respaldo de cobro en efectivo registrado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onRegistered();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (!r.puedeRegistrarRespaldoEfectivo) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cobro en efectivo',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Adjunte una foto clara como respaldo del cobro en efectivo (solo una vez por pedido).',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.25),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _tomarYSubir(context),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.photo_camera_outlined, size: 20),
            label: Text(
              _busy ? 'Subiendo…' : 'Registrar cobro en efectivo',
            ),
          ),
        ),
      ],
    );
  }
}
