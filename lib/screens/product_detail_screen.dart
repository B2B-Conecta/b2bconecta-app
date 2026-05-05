import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/credit_limit_exception.dart';
import '../models/cash_phase_exception.dart';
import '../models/kyc_verification_exception.dart';
import '../models/pedidos_suspendidos_morosidad_exception.dart';
import '../models/profile_location_exception.dart';
import '../models/stock_insufficient_exception.dart';
import '../models/part_model.dart';
import '../models/profile_model.dart';
import '../services/cart_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Ficha de producto (aliado): imagen, specs, solicitud de pedido vía broker.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.part});

  final PartModel part;

  static String heroImageTag(PartModel p) => 'product-image-${p.id}';

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _submitting = false;
  ProfileModel? _profile;

  PartModel get part => widget.part;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await SupabaseService.fetchMyProfile();
    if (mounted) setState(() => _profile = p);
  }

  bool get _faseContado => _profile?.esAliadoEnFaseContado ?? false;

  bool get _pedidosSuspendidosMorosidad =>
      _profile?.pedidosSuspendidosMorosidad ?? false;

  double get _precioVentaUnit =>
      part.precioUnitarioParaAliado(faseContado: _faseContado);

  String get _direccionFiscalParaDialogo {
    final p = _profile;
    if (p == null) return '';
    final e = p.estado?.trim();
    final c = p.ciudad?.trim();
    final d = p.direccion?.trim();
    final parts = <String>[];
    if (e != null && e.isNotEmpty) parts.add(e);
    if (c != null && c.isNotEmpty) parts.add(c);
    if (d != null && d.isNotEmpty) parts.add(d);
    return parts.join(', ');
  }

  String get _skuDisplay {
    final sku = part.sku?.trim();
    if (sku != null && sku.isNotEmpty) return sku;
    final id = part.id;
    if (id.length <= 14) return id;
    return id.substring(0, 12);
  }

  Future<void> _addToCart() async {
    final ownerId = part.ownerId?.trim();
    if (ownerId == null || ownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar al importador.')),
      );
      return;
    }
    if (_pedidosSuspendidosMorosidad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'MotoLink suspendió nuevos pedidos en su cuenta por morosidad.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (part.stock < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin stock disponible.')),
      );
      return;
    }

    final maxQty = part.stock;
    final qtyCtrl = TextEditingController(text: '1');
    bool? ok;
    var qtyRaw = '1';
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Agregar al carrito'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Indique cuántas unidades desea añadir (disponibles: $maxQty).',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      hintText: '1',
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: AppDecorations.radius12,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      );
      qtyRaw = qtyCtrl.text.trim();
    } finally {
      qtyCtrl.dispose();
    }

    if (ok != true || !mounted) return;

    var requested = int.tryParse(qtyRaw) ?? 1;
    if (requested < 1) requested = 1;

    var q = requested;
    if (requested > maxQty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stock limitado'),
          content: Text(
            'Actualmente hay $maxQty unidad(es) disponible(s). '
            'Indicó $requested. ¿Desea agregar $maxQty al carrito?',
            style: const TextStyle(height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Agregar $maxQty'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      q = maxQty;
    }

    CartService.instance.addOrIncrement(
      part,
      precioUnitarioAliadoRef: _precioVentaUnit,
      delta: q,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          q == 1
              ? '1 unidad añadida al carrito.'
              : '$q unidades añadidas al carrito.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openRequestDialog() async {
    final ownerId = part.ownerId?.trim();
    if (ownerId == null || ownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar al importador.')),
      );
      return;
    }

    if (_pedidosSuspendidosMorosidad) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'MotoLink suspendió nuevos pedidos en su cuenta por morosidad. '
            'Regularice los pagos de entregas pendientes; cuando reactivemos su cuenta, podrá solicitar de nuevo.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (part.stock < 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay unidades disponibles. El importador debe actualizar el inventario.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final qtyController = TextEditingController(text: '1');
    final destinoCtrl = TextEditingController();
    final mapsCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final maxQty = part.stock;

    bool? ok;
    var qtyText = '1';
    var usaDestinoPerfil = true;
    var savedDestinoTexto = '';
    var savedMapsUrl = '';
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final fiscal = _direccionFiscalParaDialogo;
              return AlertDialog(
                title: const Text('Solicitar pedido'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        part.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_precioVentaUnit.toStringAsFixed(2)} REF / u.',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Cantidad (máx. $maxQty)',
                          filled: true,
                          fillColor: AppColors.fieldFill,
                          border: OutlineInputBorder(
                            borderRadius: AppDecorations.radius12,
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: qtyController,
                        builder: (context, v, _) {
                          final q = int.tryParse(v.text) ?? 0;
                          final safe = q.clamp(1, maxQty);
                          final total = _precioVentaUnit * safe;
                          return Text(
                            'Total: ${total.toStringAsFixed(2)} REF',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.brandOrange,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '¿Dónde entregar?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      RadioListTile<bool>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: true,
                        groupValue: usaDestinoPerfil,
                        onChanged: (v) {
                          if (v != null) setDialogState(() => usaDestinoPerfil = v);
                        },
                        title: const Text(
                          'Dirección fiscal de Mi perfil',
                          style: TextStyle(fontSize: 13),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (fiscal.isNotEmpty)
                              Text(
                                fiscal,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                  height: 1.25,
                                ),
                              ),
                            if (_profile != null &&
                                !_profile!.hasFiscalMapsShareLink)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Debe guardar el enlace «Compartir» de Google Maps en Mi perfil para solicitar el pedido.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade900,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      RadioListTile<bool>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: false,
                        groupValue: usaDestinoPerfil,
                        onChanged: (v) {
                          if (v != null) setDialogState(() => usaDestinoPerfil = v);
                        },
                        title: const Text(
                          'Otro destino (esta orden)',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      if (!usaDestinoPerfil) ...[
                        TextField(
                          controller: destinoCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Dirección o referencia de entrega',
                            hintText:
                                'Ej.: Av. Principal, local, zona, punto de referencia',
                            filled: true,
                            fillColor: AppColors.fieldFill,
                            border: OutlineInputBorder(
                              borderRadius: AppDecorations.radius12,
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: mapsCtrl,
                          decoration: InputDecoration(
                            labelText: 'Enlace Google Maps (obligatorio)',
                            hintText: 'https://maps.google.com/...',
                            filled: true,
                            fillColor: AppColors.fieldFill,
                            border: OutlineInputBorder(
                              borderRadius: AppDecorations.radius12,
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              final q = destinoCtrl.text.trim();
                              if (q.isEmpty) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Escriba primero una dirección o referencia.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final uri = Uri.parse(
                                'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}',
                              );
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            },
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('Buscar en Google Maps'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'La cantidad quedará fija para todo el pedido; el stock se descuenta cuando el aliado confirma la entrega.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'La solicitud quedará pendiente de aprobación por MotoLink. '
                        'El importador solo la verá tras validación.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (usaDestinoPerfil) {
                        if (_profile == null ||
                            !_profile!.hasFiscalMapsShareLink) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Complete el enlace de Google Maps de su domicilio fiscal en Mi perfil.',
                              ),
                            ),
                          );
                          return;
                        }
                      } else {
                        if (destinoCtrl.text.trim().isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Indique la dirección cuando el destino no es el del perfil.',
                              ),
                            ),
                          );
                          return;
                        }
                        final m = mapsCtrl.text.trim();
                        final u = Uri.tryParse(m);
                        if (m.isEmpty ||
                            u == null ||
                            !u.hasScheme ||
                            (u.scheme != 'http' && u.scheme != 'https')) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Indique un enlace válido de Google Maps (http o https) para la entrega alterna.',
                              ),
                            ),
                          );
                          return;
                        }
                      }
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('Enviar solicitud'),
                  ),
                ],
              );
            },
          );
        },
      );
      qtyText = qtyController.text;
      savedDestinoTexto = destinoCtrl.text.trim();
      savedMapsUrl = mapsCtrl.text.trim();
    } finally {
      qtyController.dispose();
      destinoCtrl.dispose();
      mapsCtrl.dispose();
    }

    if (ok != true || !mounted) return;

    var requested = int.tryParse(qtyText.trim()) ?? 1;
    if (requested < 1) requested = 1;

    var q = requested;
    if (requested > maxQty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stock limitado'),
          content: Text(
            'Actualmente hay $maxQty unidad(es) disponible(s). '
            'Indicó $requested. La solicitud se enviará solo por $maxQty unidades.',
            style: const TextStyle(height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Continuar con $maxQty'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      q = maxQty;
    } else {
      q = requested;
    }

    setState(() => _submitting = true);
    try {
      await SupabaseService.insertTransactionRequest(
        productId: part.id,
        ownerId: ownerId,
        cantidad: q,
        precioUnitarioProveedor: part.precio,
        destinoEntregaUsaPerfil: usaDestinoPerfil,
        destinoEntregaTexto:
            usaDestinoPerfil ? null : savedDestinoTexto,
        destinoEntregaMapsUrl:
            usaDestinoPerfil ? null : savedMapsUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada. MotoLink la revisará.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on CreditLimitException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PedidosSuspendidosMorosidadException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadProfile();
    } on KycVerificationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on CashPhaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ProfileLocationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on StockInsufficientException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final importer = (part.ownerBusinessName ?? '').trim().toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Material(
                          color: Colors.white,
                          child: Hero(
                            tag: ProductDetailScreen.heroImageTag(part),
                            child: part.imagenUrl != null &&
                                    part.imagenUrl!.isNotEmpty
                                ? Image.network(
                                    part.imagenUrl!,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    errorBuilder: (_, __, ___) =>
                                        _imagePlaceholder(),
                                  )
                                : _imagePlaceholder(),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 4,
                        right: 8,
                        child: Material(
                          color: Colors.white.withOpacity(0.92),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            color: AppColors.textPrimary,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'SKU: $_skuDisplay',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (importer.isNotEmpty)
                        Text(
                          importer,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (importer.isNotEmpty) const SizedBox(height: 6),
                      Text(
                        part.nombre,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Precio',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_precioVentaUnit.toStringAsFixed(2)} REF',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Stock: ${part.stock} uds',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if ((part.descripcion ?? '').trim().isNotEmpty)
                        _SpecBlock(
                          label: 'Descripción',
                          child: Text(
                            part.descripcion!.trim(),
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      if ((part.descripcion ?? '').trim().isNotEmpty)
                        const SizedBox(height: 12),
                      if ((part.compatibilidad ?? '').trim().isNotEmpty)
                        _SpecBlock(
                          label: 'Compatibilidad',
                          child: Text(
                            part.compatibilidad!.trim(),
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      if ((part.compatibilidad ?? '').trim().isNotEmpty)
                        const SizedBox(height: 12),
                      _SpecBlock(
                        label: 'Referencia interna (ID)',
                        child: SelectableText(
                          part.id,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Puedes copiar el ID para soporte o seguimiento interno.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ServicePill(
                            icon: Icons.inventory_2_outlined,
                            label: 'Envío B2B',
                          ),
                          _ServicePill(
                            icon: Icons.local_shipping_outlined,
                            label: 'Despacho 24h',
                          ),
                          _ServicePill(
                            icon: Icons.verified_user_outlined,
                            label: 'Garantía',
                          ),
                        ],
                      ),
                      SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 100,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.paddingOf(context).bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (part.stock < 1) ...[
                  Text(
                    'Sin stock disponible',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_pedidosSuspendidosMorosidad) ...[
                  Text(
                    'Nuevos pedidos suspendidos por MotoLink (morosidad). Complete pagos en pedidos entregados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade900,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(
                  onPressed: (_submitting ||
                          part.stock < 1 ||
                          _pedidosSuspendidosMorosidad)
                      ? null
                      : _addToCart,
                  child: const Text('Agregar al carrito'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: (_submitting ||
                          part.stock < 1 ||
                          _pedidosSuspendidosMorosidad)
                      ? null
                      : _openRequestDialog,
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Solicitar solo este ítem'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return ColoredBox(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          Icons.precision_manufacturing_outlined,
          size: 72,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

class _SpecBlock extends StatelessWidget {
  const _SpecBlock({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: AppDecorations.radius12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ServicePill extends StatelessWidget {
  const _ServicePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 26, color: AppColors.textSecondary),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
