import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

import '../services/supabase_service.dart';

/// Admin: suspender o reactivar nuevos pedidos de un aliado moroso.
class AdminAliadoMorosidadActions extends StatefulWidget {
  const AdminAliadoMorosidadActions({
    super.key,
    required this.aliadoId,
    required this.aliadoName,
    required this.pedidosSuspendidosMorosidad,
    required this.onChanged,
  });

  final String aliadoId;
  final String aliadoName;
  final bool pedidosSuspendidosMorosidad;
  final VoidCallback onChanged;

  @override
  State<AdminAliadoMorosidadActions> createState() =>
      _AdminAliadoMorosidadActionsState();
}

class _AdminAliadoMorosidadActionsState extends State<AdminAliadoMorosidadActions> {
  bool _busy = false;

  Future<void> _toggleSuspend(bool suspend) async {
    final verb = suspend ? 'suspender' : 'reactivar';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(suspend ? 'Suspender por morosidad' : 'Reactivar cuenta'),
        content: Text(
          suspend
              ? '¿Suspender nuevos pedidos de ${widget.aliadoName} por morosidad? '
                  'Se notificará al aliado.'
              : '¿Permitir que ${widget.aliadoName} vuelva a crear pedidos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(suspend ? 'Suspender' : 'Reactivar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await SupabaseService.adminSetAliadoPedidosSuspendidosMorosidad(
        aliadoId: widget.aliadoId,
        suspend: suspend,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            suspend
                ? 'Cuenta suspendida por morosidad. Se notificó al aliado.'
                : 'Cuenta reactivada.',
          ),
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo $verb: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suspended = widget.pedidosSuspendidosMorosidad;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: suspended ? Colors.red.shade50 : AppColors.brandBlueContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: suspended ? Colors.red.shade200 : AppColors.brandAccent.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                suspended ? Icons.block : Icons.warning_amber_rounded,
                size: 20,
                color: suspended ? Colors.red.shade800 : AppColors.brandBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suspended
                      ? 'Cuenta suspendida por morosidad'
                      : 'Aliado con pago pendiente (moroso)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: suspended ? Colors.red.shade900 : AppColors.brandBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_busy)
            const LinearProgressIndicator(minHeight: 3)
          else
            Align(
              alignment: Alignment.centerLeft,
              child: suspended
                  ? OutlinedButton.icon(
                      onPressed: () => _toggleSuspend(false),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Reactivar nuevos pedidos'),
                    )
                  : FilledButton.icon(
                      onPressed: () => _toggleSuspend(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Suspender por morosidad'),
                    ),
            ),
        ],
      ),
    );
  }
}
