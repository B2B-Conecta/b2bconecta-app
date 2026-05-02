import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/profile_model.dart';
import '../models/sub_order_model.dart';
import '../models/transaction_request_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/maps_route_utils.dart';

/// Ruta en tránsito estática: base del transportista → almacenes pendientes → destino.
/// OSRM multi-parada; botón para abrir la misma secuencia en Google Maps.
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
  List<LatLng> _waypoints = const [];
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
    final a = oldWidget.request;
    final b = widget.request;
    if (a.id != b.id ||
        a.status != b.status ||
        a.subOrdersRecogidasAlmacenCount != b.subOrdersRecogidasAlmacenCount ||
        a.transportistaRecogioAlmacenSimple != b.transportistaRecogioAlmacenSimple ||
        a.adminRutaMapsUrl != b.adminRutaMapsUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _routePoints = const [];
      _waypoints = const [];
      _usedRoadGeometry = false;
    });
    final r = widget.request;

    ProfileModel? tp;
    if (r.hasAssignedTransportista) {
      tp = await SupabaseService.fetchProfileById(
        r.assignedTransportistaId!.trim(),
      );
    }

    final waypoints = buildRemainingShipmentWaypoints(
      request: r,
      transportista: tp,
      livePosition: null,
    );

    List<LatLng> line = const [];
    var usedRoad = false;
    if (waypoints.length >= 2) {
      final road = await fetchDrivingRouteOsrmWaypoints(waypoints);
      if (road != null && road.length >= 2) {
        line = road;
        usedRoad = true;
      } else {
        line = waypoints;
      }
    }

    if (!mounted) return;
    setState(() {
      _waypoints = waypoints;
      _routePoints = line;
      _usedRoadGeometry = usedRoad;
      _busy = false;
    });
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

  List<Marker> _buildMarkers(TransactionRequestModel r) {
    if (_waypoints.isEmpty) return const [];
    final out = <Marker>[];
    for (var i = 0; i < _waypoints.length; i++) {
      final p = _waypoints[i];
      final isLast = i == _waypoints.length - 1;
      final isFirst = i == 0;
      if (isLast) {
        out.add(
          Marker(
            width: 40,
            height: 40,
            point: p,
            alignment: Alignment.topCenter,
            child: Icon(
              Icons.place,
              color: Colors.green.shade800,
              size: 32,
            ),
          ),
        );
      } else if (isFirst) {
        out.add(
          Marker(
            width: 40,
            height: 40,
            point: p,
            alignment: Alignment.topCenter,
            child: Icon(
              Icons.home_work_outlined,
              color: Colors.deepPurple.shade800,
              size: 30,
            ),
          ),
        );
      } else {
        out.add(
          Marker(
            width: 40,
            height: 40,
            point: p,
            alignment: Alignment.topCenter,
            child: Icon(
              Icons.warehouse_outlined,
              color: Colors.blue.shade800,
              size: 30,
            ),
          ),
        );
      }
    }
    return out;
  }

  Future<void> _openExterno(TransactionRequestModel r) async {
    if (r.hasAdminRutaMapsUrl) {
      final pub = Uri.tryParse(r.adminRutaMapsUrl!.trim());
      if (pub != null &&
          pub.hasScheme &&
          (pub.scheme == 'http' || pub.scheme == 'https')) {
        final ok = await launchUrl(pub, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir Google Maps.')),
          );
        }
        return;
      }
    }
    ProfileModel? tp;
    if (r.hasAssignedTransportista) {
      tp = await SupabaseService.fetchProfileById(
        r.assignedTransportistaId!.trim(),
      );
    }
    final fallback = googleMapsRemainingRouteUrl(
      request: r,
      transportista: tp,
      livePosition: null,
    );
    final uri = fallback ??
        googleMapsDrivingDirectionsSupplierToAliado(
          r,
          originOverride: _waypoints.isNotEmpty ? _waypoints.first : null,
          destOverride: _waypoints.isNotEmpty ? _waypoints.last : null,
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
          'https://www.google.maps/search/?api=1'
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
    if (r.isMasterOrder && r.subOrders.isNotEmpty) {
      final sorted = List<SubOrderModel>.from(r.subOrders)
        ..sort((a, b) => a.id.compareTo(b.id));
      final pending =
          sorted.where((s) => !s.transportistaRecogioEnAlmacen).toList();
      final targets = pending.isNotEmpty ? pending : sorted;
      final s = targets.first;

      Uri? uri;
      final fu = s.importadorFiscalMapsUrl?.trim();
      if (fu != null && fu.isNotEmpty) {
        uri = Uri.tryParse(fu);
      }
      if (uri != null &&
          uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https')) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el almacén.')),
          );
        }
        return;
      }

      final la = s.importadorLatitude;
      final lo = s.importadorLongitude;
      if (la != null && lo != null) {
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$la,$lo',
        );
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el almacén.')),
          );
        }
        return;
      }

      final q = [
        s.importadorBusinessName,
        s.importadorDireccion,
        s.importadorCiudad,
        s.importadorEstado,
      ]
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .join(', ');
      if (q.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Este almacén no tiene dirección ni enlace en perfil. Use «Abrir ruta en Google Maps».',
              ),
            ),
          );
        }
        return;
      }
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1'
        '&query=${Uri.encodeComponent(q)}',
      );
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el almacén.')),
        );
      }
      return;
    }

    Uri? uri;
    if (r.ownerFiscalMapsUrl != null &&
        r.ownerFiscalMapsUrl!.trim().isNotEmpty) {
      uri = Uri.tryParse(r.ownerFiscalMapsUrl!.trim());
    }
    uri ??= Uri.parse(
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

  String _progresoRecogidaLine(TransactionRequestModel r) {
    if (!r.isMasterOrder || r.subOrders.isEmpty) {
      if (r.transportistaRecogioAlmacenSimple) {
        return 'Recogida en almacén confirmada · tramo hacia el aliado.';
      }
      return 'Pendiente confirmar recogida en almacén del importador.';
    }
    final done = r.subOrdersRecogidasAlmacenCount;
    final total = r.subOrders.length;
    if (done >= total) {
      return 'Retiros en almacén: $total/$total · ruta hacia el aliado.';
    }
    return 'Retiros en almacén: $done/$total · el mapa omite almacenes ya marcados como recogidos.';
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
          '${_progresoRecogidaLine(r)} '
          'La línea sigue carretera cuando OSRM lo permite; el enlace inferior abre la ruta con las mismas paradas.',
          style: TextStyle(fontSize: 11, height: 1.35, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        _bloqueUbicacion(
          icon: Icons.home_work_outlined,
          titulo: r.isMasterOrder && r.subOrders.isNotEmpty
              ? 'Origen · recolección (almacenes)'
              : 'Origen · recolección (importador)',
          texto: r.transportistaOrigenRecoleccionTextoEs,
          subtitulo: r.isMasterOrder && r.subOrders.isNotEmpty
              ? '«Ubicación en mapa» abre el primer almacén pendiente (o el primero si ya recogió todos). '
                  'Use «Abrir ruta en Google Maps» para la ruta completa con paradas.'
              : 'Almacén del importador. Pendiente de recogida aparece en el mapa hasta confirmar.',
          mapsUrlAvailable: r.transportistaOrigenPermiteAbrirMapa,
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
                  if (_buildMarkers(r).isNotEmpty)
                    MarkerLayer(markers: _buildMarkers(r)),
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
                      'Faltan coordenadas para trazar la ruta restante (perfiles / enlaces Maps). '
                      'Use los botones de ubicación o Google Maps abajo.',
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
                ? 'Trazado por carretera (aprox.). La navegación turn-by-turn sigue siendo en Google Maps.'
                : 'Línea simplificada entre paradas. Abra el enlace de Google Maps para guiado.',
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _openExterno(r),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(
              r.hasAdminRutaMapsUrl
                  ? 'Abrir ruta en Google Maps (paradas actualizadas)'
                  : 'Abrir ruta en Google Maps',
            ),
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
