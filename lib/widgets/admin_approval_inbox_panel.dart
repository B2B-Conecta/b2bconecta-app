import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Bandeja de aprobación broker (rol administrador).
class AdminApprovalInboxPanel extends StatefulWidget {
  const AdminApprovalInboxPanel({super.key});

  @override
  State<AdminApprovalInboxPanel> createState() => _AdminApprovalInboxPanelState();
}

class _AdminApprovalInboxPanelState extends State<AdminApprovalInboxPanel> {
  late Future<List<TransactionRequestModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.fetchTransactionRequestsForAdmin();
  }

  void _reload() {
    setState(() {
      _future = SupabaseService.fetchTransactionRequestsForAdmin();
    });
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pendiente':
        return 'Pendiente';
      case 'aprobado_admin':
        return 'Aprobado';
      case 'rechazado':
        return 'Rechazado';
      case 'completado':
        return 'Completado';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TransactionRequestModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Reintentar')),
                ],
              ),
            ),
          );
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No hay solicitudes.')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final r = rows[i];
              final pending = r.status == 'pendiente';
              final approved = r.status == 'aprobado_admin';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.productName ?? 'Producto',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              _statusLabel(r.status),
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      if (r.productSku != null)
                        Text(
                          'SKU: ${r.productSku}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Aliado: ${r.aliadoBusinessName ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (r.aliadoRif != null)
                        Text('RIF: ${r.aliadoRif}', style: const TextStyle(fontSize: 13)),
                      if (r.aliadoCreditScore != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.credit_score_outlined,
                                size: 18,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Credit score: ${r.aliadoCreditScore}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brandBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Cantidad: ${r.cantidad} · Total estimado (aliado): '
                        '\$${r.precioTotal.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                      ),
                      if (r.notasAdmin != null && r.notasAdmin!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Notas: ${r.notasAdmin}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      if (pending)
                        Row(
                          children: [
                            FilledButton(
                              onPressed: () async {
                                try {
                                  await SupabaseService.adminUpdateTransactionRequest(
                                    id: r.id,
                                    status: 'aprobado_admin',
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Solicitud aprobada.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  _reload();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              },
                              child: const Text('Aprobar solicitud'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () async {
                                try {
                                  await SupabaseService.adminUpdateTransactionRequest(
                                    id: r.id,
                                    status: 'rechazado',
                                  );
                                  if (!context.mounted) return;
                                  _reload();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              },
                              child: const Text('Rechazar'),
                            ),
                          ],
                        ),
                      if (approved) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            final name = r.ownerBusinessName ?? 'el mayorista';
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Contactar mayorista'),
                                content: Text(
                                  'Coordina con $name fuera de la app '
                                  '(teléfono, correo o WhatsApp). '
                                  'Luego puedes marcar como completado si aplica.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cerrar'),
                                  ),
                                  FilledButton(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      try {
                                        await SupabaseService
                                            .adminUpdateTransactionRequest(
                                          id: r.id,
                                          status: 'completado',
                                        );
                                        if (!context.mounted) return;
                                        _reload();
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    },
                                    child: const Text('Marcar completado'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.phone_in_talk_outlined, size: 18),
                          label: const Text('Contactar mayorista / completar'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
