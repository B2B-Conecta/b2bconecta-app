import 'package:flutter/material.dart';

import '../models/profile_location_exception.dart';
import '../models/profile_model.dart';
import '../services/cart_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/ves_amount_format.dart';

/// Carrito multi-importador: agrupa por importador y confirma un solo pedido maestro.
class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.profile,
    this.liveTasaBcv,
  });

  final ProfileModel profile;
  final double? liveTasaBcv;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cart = CartService.instance;
  bool _submitting = false;
  double? _tasa;

  @override
  void initState() {
    super.initState();
    _tasa = widget.liveTasaBcv;
    _cart.addListener(_onCart);
    if (_tasa == null) {
      SupabaseService.fetchGlobalTasaBcv().then((v) {
        if (mounted) setState(() => _tasa = v);
      }).catchError((_) {});
    }
  }

  void _onCart() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cart.removeListener(_onCart);
    super.dispose();
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty || _submitting) return;

    final result = await showDialog<_DestinoEntregaResult?>(
      context: context,
      builder: (ctx) => _DestinoEntregaDialog(profile: widget.profile),
    );

    if (result == null || !mounted) return;

    setState(() => _submitting = true);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final lines = _cart.lines
          .map(
            (l) => <String, dynamic>{
              'product_id': l.part.id,
              'cantidad': l.quantity,
            },
          )
          .toList();

      await SupabaseService.checkoutMultiImportadorCart(
        lines: lines,
        destinoEntregaUsaPerfil: result.useProfile,
        destinoEntregaTexto: result.texto,
        destinoEntregaMapsUrl: result.mapsUrl,
        promoByImportador: _cart.promoAttributionPayloadForCheckout(),
      );

      _cart.clear();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Pedido registrado. Los importadores recibirán un aviso para confirmar stock.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      nav.pop(true);
    } on ProfileLocationException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _importerGroupHasPromo(List<CartLine> lines) {
    for (final line in lines) {
      if (_cart.importadorHasPromoAttribution(line.part.ownerId)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final tasa = _tasa;
    final totalRef = _cart.totalRef();
    final totalBs = tasa != null ? totalRef * tasa : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Carrito',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _cart.isEmpty
          ? Center(
              child: Text(
                'Agregue repuestos desde el catálogo.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      for (final entry
                          in _cart.linesGroupedByImporterName.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: AppColors.brandBlue,
                                  ),
                                ),
                              ),
                              if (_importerGroupHasPromo(entry.value))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Bajo promoción',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ...entry.value.map((line) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                line.part.nombre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${line.quantity} uds · '
                                '${(line.precioUnitarioAliadoRef * line.quantity).toStringAsFixed(2)} REF',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () =>
                                    _cart.removeProduct(line.part.id),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                Material(
                  elevation: 8,
                  color: Colors.white,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Total REF: ${formatRefAmount(totalRef)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (totalBs != null && tasa != null)
                            Text(
                              'Referencia en Bs (tasa ${formatTasaBcvDisplay(tasa, fractionDigits: 4)}): '
                              '${formatVesAmount(totalBs)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _submitting
                                ? null
                                : _checkout,
                            child: _submitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Confirmar pedido'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Resultado del diálogo de destino: se devuelve al confirmar (no al cancelar).
class _DestinoEntregaResult {
  const _DestinoEntregaResult({
    required this.useProfile,
    this.texto,
    this.mapsUrl,
  });

  final bool useProfile;
  final String? texto;
  final String? mapsUrl;
}

/// Destino: dirección fiscal del perfil, o formulario de ubicación alterna.
class _DestinoEntregaDialog extends StatefulWidget {
  const _DestinoEntregaDialog({required this.profile});

  final ProfileModel profile;

  @override
  State<_DestinoEntregaDialog> createState() => _DestinoEntregaDialogState();
}

class _DestinoEntregaDialogState extends State<_DestinoEntregaDialog> {
  bool _usaPerfil = true;
  final _estado = TextEditingController();
  final _ciudad = TextEditingController();
  final _domicilio = TextEditingController();
  final _maps = TextEditingController();

  @override
  void dispose() {
    _estado.dispose();
    _ciudad.dispose();
    _domicilio.dispose();
    _maps.dispose();
    super.dispose();
  }

  InputDecoration _field(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.fieldFill,
      border: OutlineInputBorder(
        borderRadius: AppDecorations.radius12,
        borderSide: BorderSide.none,
      ),
    );
  }

  String _armarTextoEntrega() {
    final e = _estado.text.trim();
    final c = _ciudad.text.trim();
    final d = _domicilio.text.trim();
    return [
      if (e.isNotEmpty) 'Estado: $e',
      if (c.isNotEmpty) 'Ciudad: $c',
      if (d.isNotEmpty) 'Domicilio: $d',
    ].join('\n');
  }

  void _confirmar() {
    if (_usaPerfil) {
      if (!widget.profile.hasFiscalMapsShareLink) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registre el enlace de Google Maps de su domicilio fiscal en Mi perfil.',
            ),
          ),
        );
        return;
      }
    } else {
      final e = _estado.text.trim();
      final c = _ciudad.text.trim();
      final d = _domicilio.text.trim();
      if (e.isEmpty || c.isEmpty || d.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Complete estado, ciudad y domicilio de la entrega alterna.',
            ),
          ),
        );
        return;
      }
      final m = _maps.text.trim();
      final u = Uri.tryParse(m);
      if (m.isEmpty ||
          u == null ||
          !u.hasScheme ||
          (u.scheme != 'http' && u.scheme != 'https')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Indique un enlace válido de Google Maps (http o https) para la entrega alterna.',
            ),
          ),
        );
        return;
      }
    }
    final text = _usaPerfil ? null : _armarTextoEntrega();
    final maps = _usaPerfil
        ? null
        : _maps.text.trim();
    Navigator.of(context).pop(
      _DestinoEntregaResult(
        useProfile: _usaPerfil,
        texto: text,
        mapsUrl: maps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Destino de entrega'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar dirección fiscal del perfil'),
              subtitle: Text(
                _usaPerfil
                    ? (widget.profile.hasFiscalMapsShareLink
                        ? 'El reparto usará su domicilio y el enlace Maps guardados en Mi perfil.'
                        : 'Debe completar el enlace de Google Maps en Mi perfil para usar esta opción.')
                    : 'Indique otra dirección y enlace Maps a continuación.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              value: _usaPerfil,
              onChanged: (v) => setState(() => _usaPerfil = v),
            ),
            if (!_usaPerfil) ...[
              const SizedBox(height: 4),
              const Text(
                'Ubicación alterna de entrega',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandBlue,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Esta dirección sustituye a la fiscal para este pedido. '
                'El enlace de Google Maps es obligatorio para ubicar el sitio con precisión.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _estado,
                textCapitalization: TextCapitalization.words,
                decoration: _field('Estado'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ciudad,
                textCapitalization: TextCapitalization.words,
                decoration: _field('Ciudad'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _domicilio,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: _field('Domicilio (calle, sector, ref.)'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _maps,
                keyboardType: TextInputType.url,
                decoration: _field(
                  'URL de Google Maps',
                  hint: 'https://…',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _confirmar(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmar,
          child: const Text('Confirmar pedido'),
        ),
      ],
    );
  }
}
