import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/transaction_request_model.dart';
import '../theme/app_theme.dart';
import '../utils/maps_route_utils.dart';

/// Ruta origen (importador) → destino (Bloque A2): mapa + OSRM + Google Maps externo.
/// La pantalla de detalle solo monta este widget cuando el pedido está `en_transito`.
class TransactionRequestRouteMapSection extends StatefulWidget {
  const TransactionRequestRouteMapSection({
    super.key,
    required this.request,
  });

  final TransactionRequestModel request;

  @override
  State<TransactionRequestRouteMapSection> createState() =>
      _TransactionRequestRouteMapSectionState();
}

class _TransactionRequestRouteMapSectionState
    extends State<TransactionRequestRouteMapSection> {
  List<LatLng> _routePoints = const [];
  LatLng? _origin;
  LatLng? _dest;
  bool _busy = true;
  bool _usedRoadGeometry = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TransactionRequestRouteMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.request.status != widget.request.status) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _routePoints = const [];
      _origin = null;
      _dest = null;
      _usedRoadGeometry = false;
    });
    final r = widget.request;

    final origin = await _resolveOriginLatLng(r);
    final dest = await _resolveDestLatLng(r);

    List<LatLng> line = const [];
    var usedRoad = false;
    if (origin != null && dest != null) {
      final road = await fetchDrivingRouteOsrm(origin, dest);
      if (road != null && road.length >= 2) {
        line = road;
        usedRoad = true;
      } else {
        line = [origin, dest];
      }
    }

    if (!mounted) return;
    setState(() {
      _origin = origin;
      _dest = dest;
      _routePoints = line;
      _usedRoadGeometry = usedRoad;
      _busy = false;
    });
  }

  static Future<LatLng?> _tryGeocode(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final query = trimmed.toLowerCase().contains('venezuela')
        ? trimmed
        : '$trimmed, Venezuela';
    try {
      final locs = await locationFromAddress(query);
      if (locs.isEmpty) return null;
      final l = locs.first;
      return LatLng(l.latitude, l.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<LatLng?> _resolveOriginLatLng(TransactionRequestModel r) async {
    final fromUrl = parseLatLngFromGoogleMapsUrl(r.ownerFiscalMapsUrl);
    if (fromUrl != null) return fromUrl;
    return _tryGeocode(r.ownerUbicacionUnaLineaParaMapa);
  }

  Future<LatLng?> _resolveDestLatLng(TransactionRequestModel r) async {
    if (!r.destinoEntregaUsaPerfil) {
      final fromAlt = parseLatLngFromGoogleMapsUrl(r.destinoEntregaMapsUrl);
      if (fromAlt != null) return fromAlt;
    } else {
      final fromFiscal = parseLatLngFromGoogleMapsUrl(r.aliadoFiscalMapsUrl);
      if (fromFiscal != null) return fromFiscal;
    }
    return _tryGeocode(r.destinoEntregaTextoParaMapa);
  }

  static LatLng _mid(List<LatLng> pts) {
    if (pts.isEmpty) return const LatLng(10.5, -66.9);
    var la = 0.0;
    var lo = 0.0;
    for (final p in pts) {
      la += p.latitude;
      lo += p.longitude;
    }
    return LatLng(la / pts.length, lo / pts.length);
  }

  static MapOptions _mapOptionsForRoute(List<LatLng> pts) {
    final b = _boundsFor(pts);
    if (b != null) {
      return MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: b,
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      );
    }
    return MapOptions(
      initialCenter: _mid(pts),
      initialZoom: 8,
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all,
      ),
    );
  }

  static LatLngBounds? _boundsFor(List<LatLng> pts) {
    if (pts.isEmpty) return null;
    var minLat = pts.first.latitude;
    var maxLat = pts.first.latitude;
    var minLng = pts.first.longitude;
    var maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  Future<void> _openExterno(TransactionRequestModel r) async {
    final uri = googleMapsDrivingDirectionsSupplierToAliado(
      r,
      originOverride: _origin,
      destOverride: _dest,
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps.')),
      );
    }
  }

  Future<void> _openDestino(TransactionRequestModel r) async {
    Uri? uri;
    if (!r.destinoEntregaUsaPerfil && r.destinoEntregaMapsUrl != null) {
      uri = Uri.tryParse(r.destinoEntregaMapsUrl!.trim());
    } else if (r.aliadoFiscalMapsUrl != null &&
        r.aliadoFiscalMapsUrl!.trim().isNotEmpty) {
      uri = Uri.tryParse(r.aliadoFiscalMapsUrl!.trim());
    }
    uri ??=
        Uri.parse(
          'https://www.google.com/maps/search/?api=1'
          '&query=${Uri.encodeComponent(r.destinoEntregaTextoParaMapa)}',
        );
    if (!uri.hasScheme ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el destino.')),
      );
    }
  }

  Future<void> _openOrigen(TransactionRequestModel r) async {
    Uri? uri;
    if (r.ownerFiscalMapsUrl != null &&
        r.ownerFiscalMapsUrl!.trim().isNotEmpty) {
      uri = Uri.tryParse(r.ownerFiscalMapsUrl!.trim());
    }
    uri ??=
        Uri.parse(
          'https://www.google.com/maps/search/?api=1'
          '&query=${Uri.encodeComponent(r.ownerUbicacionUnaLineaParaMapa)}',
        );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el origen.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ruta del envío (en tránsito)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Origen: almacén del importador · Destino: entrega según Bloque A2. '
          'La línea violeta sigue carretera cuando es posible (OSRM); use Google Maps para navegación GPS en vivo.',
          style: TextStyle(fontSize: 11, height: 1.35, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        _bloqueUbicacion(
          icon: Icons.home_work_outlined,
          titulo: 'Origen · recolección (importador)',
          texto: r.ownerUbicacionFiscalMultilineaEs ??
              (r.ownerBusinessName ?? 'Sin dirección en perfil'),
          subtitulo: 'Punto A del envío.',
          mapsUrlAvailable: r.ownerFiscalMapsUrl?.trim().isNotEmpty == true ||
              r.ownerUbicacionFiscalMultilineaEs != null,
          onMaps: () => _openOrigen(r),
        ),
        const SizedBox(height: 10),
        _bloqueUbicacion(
          icon: Icons.flag_outlined,
          titulo: 'Destino · entrega (aliado)',
          texto: r.destinoEntregaUsaPerfil
              ? (r.aliadoDireccionFiscalMultilineaEs ??
                  'Dirección fiscal del perfil del aliado')
              : (r.destinoEntregaTexto?.trim().isNotEmpty == true
                  ? r.destinoEntregaTexto!.trim()
                  : 'Sin texto de destino'),
          subtitulo: r.destinoEntregaUsaPerfil
              ? 'Bloque A2 · dirección fiscal (o enlace Maps del perfil)'
              : 'Bloque A2 · dirección alternativa y enlace Maps si aplica',
          mapsUrlAvailable:
              r.destinoEntregaMapsUrl?.trim().isNotEmpty == true ||
                  r.aliadoFiscalMapsUrl?.trim().isNotEmpty == true ||
                  r.destinoEntregaUsaPerfil,
          onMaps: () => _openDestino(r),
        ),
        const SizedBox(height: 12),
        if (_busy)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey.shade600,
              ),
            ),
          )
        else if (_routePoints.length >= 2)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 240,
              child: FlutterMap(
                options: _mapOptionsForRoute(_routePoints),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.motolink.pro',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: _usedRoadGeometry ? 5 : 4,
                        color: AppColors.brand.withOpacity(0.75),
                      ),
                    ],
                  ),
                  if (_origin != null && _dest != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 40,
                          height: 40,
                          point: _origin!,
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.warehouse_outlined,
                            color: Colors.blue.shade800,
                            size: 32,
                          ),
                        ),
                        Marker(
                          width: 40,
                          height: 40,
                          point: _dest!,
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.place,
                            color: Colors.green.shade800,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '© OpenStreetMap · ruta OSRM',
                        onTap: () async {
                          await launchUrl(
                            Uri.parse('https://openstreetmap.org/copyright'),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, color: Colors.grey.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No se pudieron obtener ambos puntos (perfil sin dirección o enlace Maps sin coordenadas). '
                      'Complete dirección fiscal del importador y del aliado, o use los botones de mapa y Google Maps.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!_busy && _routePoints.length >= 2) ...[
          const SizedBox(height: 6),
          Text(
            _usedRoadGeometry
                ? 'Trazado por carretera (aprox.). Para ETA y navegación en vivo use el botón de «Destino de entrega» o el enlace de abajo.'
                : 'Línea recta entre puntos. Para ETA y navegación use el botón de «Destino de entrega» o el enlace de abajo.',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _openExterno(r),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Abrir misma ruta importador → aliado (Google Maps)'),
          ),
        ),
      ],
    );
  }

  Widget _bloqueUbicacion({
    required IconData icon,
    required String titulo,
    required String texto,
    required String subtitulo,
    required bool mapsUrlAvailable,
    required VoidCallback onMaps,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: AppColors.brandBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitulo,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                color: Colors.grey.shade600,
              ),
            ),
            if (mapsUrlAvailable) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onMaps,
                icon: const Icon(Icons.map_outlined, size: 17),
                label: const Text('Ubicación en mapa'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
