import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/aliado_experience_utils.dart';
import 'aliado_order_experience_display.dart';

/// A6: calificación 1-5 y comentario breve (solo con pedido entregado; una vez).
class AliadoOrderExperienceSection extends StatefulWidget {
  const AliadoOrderExperienceSection({
    super.key,
    required this.request,
    required this.onChanged,
    this.bundleCheckoutGroupId,
    this.bundleImportadorId,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;

  /// Si se informa junto con [bundleImportadorId], la valoración aplica a todas las
  /// líneas del mismo importador dentro del carrito (un solo cuestionario).
  final String? bundleCheckoutGroupId;
  final String? bundleImportadorId;

  @override
  State<AliadoOrderExperienceSection> createState() =>
      _AliadoOrderExperienceSectionState();
}

class _AliadoOrderExperienceSectionState
    extends State<AliadoOrderExperienceSection> {
  int? _estrellas;
  final _commentCtrl = TextEditingController();
  bool _busy = false;

  @override
  void didUpdateWidget(covariant AliadoOrderExperienceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.request.aliadoExperienceSubmittedAt !=
            widget.request.aliadoExperienceSubmittedAt) {
      _estrellas = null;
      _commentCtrl.clear();
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final s = _estrellas;
    if (s == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique de 1 a 5 estrellas.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final bcg = widget.bundleCheckoutGroupId?.trim();
      final bid = widget.bundleImportadorId?.trim();
      if (bcg != null &&
          bcg.isNotEmpty &&
          bid != null &&
          bid.isNotEmpty) {
        await SupabaseService.aliadoSubmitOrderExperienceImportadorGrupo(
          checkoutGroupId: bcg,
          importadorId: bid,
          stars: s,
          comment: _commentCtrl.text,
        );
      } else {
        await SupabaseService.aliadoSubmitOrderExperience(
          transactionRequestId: widget.request.id,
          stars: s,
          comment: _commentCtrl.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gracias. Su comentario queda registrado para MotoLink.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      final msg = _experienceErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      if (msg.contains('ya fue registrada')) {
        widget.onChanged();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _experienceErrorMessage(Object e) {
    final raw = e is PostgrestException ? e.message : e.toString();
    if (raw.contains('No se puede registrar la valoración') ||
        raw.contains('ya valorados')) {
      return 'La valoración de este pedido ya fue registrada. '
          'Actualizamos la ficha para mostrarla.';
    }
    if (raw.contains('Calificación inválida')) {
      return 'Indique de 1 a 5 estrellas.';
    }
    return 'No se pudo enviar la valoración. Inténtelo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (r.status != TransactionRequestStatus.entregado ||
        r.anuladoPorMotolink ||
        r.canceladoPorAliado) {
      return const SizedBox.shrink();
    }
    if (aliadoTieneValoracionRegistrada(r)) {
      final scope = widget.bundleImportadorId != null &&
              widget.bundleImportadorId!.trim().isNotEmpty
          ? 'Valoración de este proveedor en el pedido'
          : 'Valoración de este pedido';
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AliadoOrderExperienceRegisteredCard(
          request: r,
          scopeLabel: scope,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.bundleCheckoutGroupId != null &&
                  widget.bundleCheckoutGroupId!.trim().isNotEmpty
              ? '¿Cómo fue tu experiencia con este proveedor en este pedido?'
              : '¿Cómo fue tu experiencia con este pedido?',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Calificá de 1 a 5 estrellas y, si querés, dejá un comentario breve. '
          'Al enviar, quedará registrada en este pedido y no podrá editarse.',
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.grey.shade700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final n = i + 1;
            final sel = (_estrellas ?? 0) >= n;
            return IconButton(
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _estrellas = n;
                      }),
              icon: Icon(
                sel ? Icons.star : Icons.star_border,
                size: 28,
                color: sel ? Colors.amber.shade800 : Colors.grey.shade500,
              ),
            );
          }),
        ),
        TextField(
          controller: _commentCtrl,
          minLines: 1,
          maxLines: 4,
          maxLength: 500,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Comentario (opcional)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 6),
        FilledButton.tonal(
          onPressed: _busy ? null : _enviar,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar valoración'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
