import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Solo MotoLink: preparación de ruta en `pedido_listo` y publicación del enlace;
/// en `en_transito` solo el editor del enlace (por si debe corregirse).
class TransactionRequestAdminPedidoListoRoutePrepSection extends StatefulWidget {
  const TransactionRequestAdminPedidoListoRoutePrepSection({
    super.key,
    required this.request,
    this.onSaved,
  });

  final TransactionRequestModel request;
  final VoidCallback? onSaved;

  static const _blankDirectionsUri =
      'https://www.google.com/maps/dir/?api=1&travelmode=driving';

  @override
  State<TransactionRequestAdminPedidoListoRoutePrepSection> createState() =>
      _TransactionRequestAdminPedidoListoRoutePrepSectionState();
}

class _TransactionRequestAdminPedidoListoRoutePrepSectionState
    extends State<TransactionRequestAdminPedidoListoRoutePrepSection> {
  late final TextEditingController _urlCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.request.adminRutaMapsUrl ?? '');
  }

  @override
  void didUpdateWidget(TransactionRequestAdminPedidoListoRoutePrepSection old) {
    super.didUpdateWidget(old);
    if (old.request.id != widget.request.id ||
        old.request.adminRutaMapsUrl != widget.request.adminRutaMapsUrl) {
      _urlCtrl.text = widget.request.adminRutaMapsUrl ?? '';
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  Future<void> _openHttpUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El enlace no es una URL http(s) válida.')),
      );
      return;
    }
    await _launchUri(context, uri);
  }

  Future<void> _openAliado(BuildContext context) async {
    final r = widget.request;
    final u = r.aliadoFiscalMapsUrl?.trim();
    if (u != null && u.isNotEmpty) {
      await _openHttpUrl(context, u);
      return;
    }
    if (!r.destinoEntregaUsaPerfil) {
      final alt = r.destinoEntregaMapsUrl?.trim();
      if (alt != null && alt.isNotEmpty) {
        await _openHttpUrl(context, alt);
        return;
      }
    }
    final q = r.destinoEntregaUsaPerfil
        ? (r.aliadoDireccionFiscalMultilineaEs ??
            r.aliadoBusinessName ??
            'Taller aliado')
        : (r.destinoEntregaTexto?.trim().isNotEmpty == true
            ? r.destinoEntregaTexto!.trim()
            : (r.aliadoBusinessName ?? 'Destino aliado'));
    await _launchUri(
      context,
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}',
      ),
    );
  }

  Future<void> _openImportador(BuildContext context) async {
    final r = widget.request;
    final u = r.ownerFiscalMapsUrl?.trim();
    if (u != null && u.isNotEmpty) {
      await _openHttpUrl(context, u);
      return;
    }
    final q = r.ownerUbicacionUnaLineaParaMapa;
    await _launchUri(
      context,
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}',
      ),
    );
  }

  Future<void> _openBlankDirectionsTemplate(BuildContext context) async {
    await _launchUri(
      context,
      Uri.parse(TransactionRequestAdminPedidoListoRoutePrepSection._blankDirectionsUri),
    );
  }

  Future<void> _openSavedRoute(BuildContext context) async {
    final u = widget.request.adminRutaMapsUrl?.trim();
    if (u == null || u.isEmpty) return;
    await _openHttpUrl(context, u);
  }

  Future<void> _guardarEnlace(BuildContext context) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.adminSetTransactionRequestRutaMapsUrl(
        requestId: widget.request.id,
        urlOrNull: _urlCtrl.text,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace de ruta guardado.')),
      );
      widget.onSaved?.call();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildEnlaceEditor(BuildContext context, {required bool compactIntro}) {
    final r = widget.request;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compactIntro) ...[
          Text(
            'Enlace de ruta publicado',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Colors.indigo.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Aliado e importador lo verán en tránsito cuando guarde una URL http(s) válida.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
        ] else ...[
          const Divider(height: 20),
          Text(
            'Publicar enlace de la ruta unificada',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: Colors.indigo.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pegue aquí la URL de Google Maps (direcciones) que verán aliado e importador en la ficha '
            'cuando el pedido esté en tránsito. Puede dejarlo vacío para ocultar el botón.',
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _urlCtrl,
          maxLines: 2,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            hintText: 'https://www.google.com/maps/...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _guardarEnlace(context),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 20),
                label: Text(_saving ? 'Guardando…' : 'Guardar enlace'),
              ),
            ),
            if (r.hasAdminRutaMapsUrl) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Abrir enlace guardado',
                onPressed: () => _openSavedRoute(context),
                icon: const Icon(Icons.open_in_new, size: 20),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final listo = r.status == TransactionRequestStatus.pedidoListo;
    final transito = r.status == TransactionRequestStatus.enTransito;
    if (!listo && !transito) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.indigo.shade50,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (listo) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.admin_panel_settings_outlined,
                      color: Colors.indigo.shade900, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preparación de ruta (solo MotoLink)',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.indigo.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pedido listo para recolección. Use los mapas de referencia y la plantilla para '
                          'armar la ruta; luego pegue y guarde el enlace unificado para aliado e importador.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openAliado(context),
                icon: const Icon(Icons.place_outlined, size: 20),
                label: const Text('Google Maps · ubicación aliado'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _openImportador(context),
                icon: const Icon(Icons.warehouse_outlined, size: 20),
                label: const Text('Google Maps · almacén importador'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () => _openBlankDirectionsTemplate(context),
                icon: const Icon(Icons.edit_road_outlined, size: 20),
                label: const Text('Plantilla Google Maps (ruta manual y ETA)'),
                style: FilledButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
              _buildEnlaceEditor(context, compactIntro: false),
            ] else
              _buildEnlaceEditor(context, compactIntro: true),
          ],
        ),
      ),
    );
  }
}
