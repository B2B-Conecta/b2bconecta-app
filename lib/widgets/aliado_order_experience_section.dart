import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// A6: calificación 1-5 y comentario breve (solo con pedido entregado; una vez).
class AliadoOrderExperienceSection extends StatefulWidget {
  const AliadoOrderExperienceSection({
    super.key,
    required this.request,
    required this.onChanged,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;

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
    if (oldWidget.request.id != widget.request.id) {
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
      await SupabaseService.aliadoSubmitOrderExperience(
        transactionRequestId: widget.request.id,
        stars: s,
        comment: _commentCtrl.text,
      );
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
    if (r.status != TransactionRequestStatus.entregado ||
        r.anuladoPorMotolink ||
        r.canceladoPorAliado) {
      return const SizedBox.shrink();
    }
    if (r.aliadoExperienceSubmittedAt != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu valoración de la experiencia',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(5, (i) {
                  final n = (r.aliadoExperienceStars ?? 0) > i ? 1.0 : 0.0;
                  return Icon(
                    n > 0 ? Icons.star : Icons.star_border,
                    size: 20,
                    color: Colors.amber.shade800,
                  );
                }),
              ),
              if ((r.aliadoExperienceComment ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  r.aliadoExperienceComment!.trim(),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.purple.shade900,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '¿Cómo fue tu experiencia con este pedido?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Calificá de 1 a 5 estrellas y, si querés, dejá un comentario breve.',
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
