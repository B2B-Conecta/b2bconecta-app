import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/profile_model.dart';
import '../models/sub_order_model.dart';
import '../models/transaction_request_model.dart';

/// Extrae coordenadas de enlaces típicos de Google Maps (sin resolver acortadores goo.gl).
LatLng? parseLatLngFromGoogleMapsUrl(String? raw) {
  if (raw == null) return null;
  final u = raw.trim();
  if (u.isEmpty) return null;

  final at = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');
  final mAt = at.firstMatch(u);
  if (mAt != null) {
    final lat = double.tryParse(mAt.group(1)!);
    final lng = double.tryParse(mAt.group(2)!);
    if (lat != null && lng != null) return LatLng(lat, lng);
  }

  final d3 = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)');
  final m3 = d3.firstMatch(u);
  if (m3 != null) {
    final lat = double.tryParse(m3.group(1)!);
    final lng = double.tryParse(m3.group(2)!);
    if (lat != null && lng != null) return LatLng(lat, lng);
  }

  final qPair = RegExp(r'[?&](?:q|ll)=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)');
  final mQ = qPair.firstMatch(u);
  if (mQ != null) {
    final a = double.tryParse(mQ.group(1)!);
    final b = double.tryParse(mQ.group(2)!);
    if (a != null && b != null) {
      if (a.abs() <= 90 && b.abs() <= 180) {
        return LatLng(a, b);
      }
    }
  }

  return null;
}

/// Geometría aproximada por carretera (servicio público OSRM; límites de uso en producción).
Future<List<LatLng>?> fetchDrivingRouteOsrm(LatLng from, LatLng to) async {
  final uri = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/'
    '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
    '?overview=simplified&geometries=geojson',
  );
  try {
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) return null;
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final first = routes.first;
    if (first is! Map<String, dynamic>) return null;
    final geometry = first['geometry'];
    if (geometry is! Map<String, dynamic>) return null;
    final coords = geometry['coordinates'];
    if (coords is! List) return null;
    final out = <LatLng>[];
    for (final pair in coords) {
      if (pair is List && pair.length >= 2) {
        final lng = (pair[0] as num).toDouble();
        final lat = (pair[1] as num).toDouble();
        out.add(LatLng(lat, lng));
      }
    }
    return out.length >= 2 ? out : null;
  } catch (_) {
    return null;
  }
}

/// Google Maps direcciones: importador (`profiles.fiscal_maps_url` + domicilio) →
/// aliado (perfil fiscal o `destino_entrega_maps_url` del pedido).
/// [originOverride] / [destOverride] suelen ser coordenadas ya geocodificadas en la app.
Uri googleMapsDrivingDirectionsSupplierToAliado(
  TransactionRequestModel r, {
  LatLng? originOverride,
  LatLng? destOverride,
}) {
  final oCoord = originOverride ??
      parseLatLngFromGoogleMapsUrl(r.ownerFiscalMapsUrl?.trim());
  LatLng? dCoord = destOverride;
  dCoord ??= !r.destinoEntregaUsaPerfil
      ? parseLatLngFromGoogleMapsUrl(r.destinoEntregaMapsUrl?.trim())
      : parseLatLngFromGoogleMapsUrl(r.aliadoFiscalMapsUrl?.trim());

  final originText = r.ownerUbicacionUnaLineaParaMapa;
  final destinationText = r.destinoEntregaTextoParaMapa;

  if (oCoord != null && dCoord != null) {
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${oCoord.latitude},${oCoord.longitude}'
      '&destination=${dCoord.latitude},${dCoord.longitude}'
      '&travelmode=driving',
    );
  }
  if (oCoord != null) {
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${oCoord.latitude},${oCoord.longitude}'
      '&destination=${Uri.encodeComponent(destinationText)}'
      '&travelmode=driving',
    );
  }
  if (dCoord != null) {
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${Uri.encodeComponent(originText)}'
      '&destination=${dCoord.latitude},${dCoord.longitude}'
      '&travelmode=driving',
    );
  }

  return Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&origin=${Uri.encodeComponent(originText)}'
    '&destination=${Uri.encodeComponent(destinationText)}'
    '&travelmode=driving',
  );
}

/// Ruta con varias paradas (transportista → almacenes → destino). Mínimo 2 puntos.
Uri googleMapsDirLatLngStops(List<LatLng> stops) {
  if (stops.length < 2) {
    return Uri.parse('https://www.google.com/maps/dir/?api=1&travelmode=driving');
  }
  final path = stops
      .map((p) => '${p.latitude},${p.longitude}')
      .join('/');
  return Uri.parse(
    'https://www.google.com/maps/dir/$path?api=1&travelmode=driving',
  );
}

LatLng? _latLngFromProfile(ProfileModel? p) {
  if (p == null) return null;
  final la = p.latitude;
  final lo = p.longitude;
  if (la != null && lo != null) return LatLng(la, lo);
  return parseLatLngFromGoogleMapsUrl(p.fiscalMapsUrl);
}

LatLng? _latLngSubImporter(SubOrderModel s) {
  final la = s.importadorLatitude;
  final lo = s.importadorLongitude;
  if (la != null && lo != null) return LatLng(la, lo);
  return parseLatLngFromGoogleMapsUrl(s.importadorFiscalMapsUrl);
}

/// Ruta sugerida: base transportista (si hay coords) → almacén(es) importador → destino aliado.
/// Devuelve `null` si no hay al menos dos puntos resueltos.
Uri? googleMapsAutoRutaForAssignedPedido({
  required TransactionRequestModel request,
  ProfileModel? transportista,
}) {
  final stops = <LatLng>[];

  final base = _latLngFromProfile(transportista);
  if (base != null) stops.add(base);

  if (request.isMasterOrder && request.subOrders.isNotEmpty) {
    final sorted = List<SubOrderModel>.from(request.subOrders)
      ..sort((a, b) => a.id.compareTo(b.id));
    final seen = <String>{};
    for (final s in sorted) {
      final iid = s.importadorId.trim();
      if (iid.isEmpty || seen.contains(iid)) continue;
      seen.add(iid);
      final imp = _latLngSubImporter(s);
      if (imp != null) stops.add(imp);
    }
  } else {
    final oLa = request.ownerLatitude;
    final oLo = request.ownerLongitude;
    LatLng? imp;
    if (oLa != null && oLo != null) {
      imp = LatLng(oLa, oLo);
    } else {
      imp = parseLatLngFromGoogleMapsUrl(request.ownerFiscalMapsUrl);
    }
    if (imp != null) stops.add(imp);
  }

  LatLng? dest;
  if (!request.destinoEntregaUsaPerfil) {
    dest = parseLatLngFromGoogleMapsUrl(request.destinoEntregaMapsUrl);
  } else {
    final aLa = request.aliadoLatitude;
    final aLo = request.aliadoLongitude;
    if (aLa != null && aLo != null) {
      dest = LatLng(aLa, aLo);
    } else {
      dest = parseLatLngFromGoogleMapsUrl(request.aliadoFiscalMapsUrl);
    }
  }
  if (dest != null) stops.add(dest);

  if (stops.length < 2) return null;
  return googleMapsDirLatLngStops(stops);
}

/// Varias paradas como texto (dirección o etiqueta); Google Maps resuelve sobre la marcha.
Uri googleMapsDirAddressStops(List<String> stops) {
  final clean = stops
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (clean.isEmpty) {
    return Uri.parse('https://www.google.com/maps');
  }
  if (clean.length == 1) {
    return Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(clean.first)}',
    );
  }
  final o = Uri.encodeComponent(clean.first);
  final d = Uri.encodeComponent(clean.last);
  if (clean.length == 2) {
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$o&destination=$d&travelmode=driving',
    );
  }
  final mid = clean
      .sublist(1, clean.length - 1)
      .map(Uri.encodeComponent)
      .join('%7C');
  return Uri.parse(
    'https://www.google.com/maps/dir/?api=1&origin=$o&destination=$d&waypoints=$mid&travelmode=driving',
  );
}

/// Respaldo si faltan lat/long: base transportista, almacén(es) y destino como texto.
Uri? googleMapsAutoRutaAddressFallback({
  required TransactionRequestModel request,
  ProfileModel? transportista,
}) {
  final parts = <String>[];

  void addDistinct(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    if (parts.isNotEmpty && parts.last.toLowerCase() == t.toLowerCase()) {
      return;
    }
    parts.add(t);
  }

  if (transportista != null) {
    final tp = [
      transportista.direccion,
      transportista.ciudad,
      transportista.estado,
      transportista.businessName,
    ]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');
    if (tp.isNotEmpty) addDistinct('$tp, Venezuela');
  }

  if (request.isMasterOrder && request.subOrders.isNotEmpty) {
    final sorted = List<SubOrderModel>.from(request.subOrders)
      ..sort((a, b) => a.id.compareTo(b.id));
    final seen = <String>{};
    for (final s in sorted) {
      final iid = s.importadorId.trim();
      if (iid.isEmpty || seen.contains(iid)) continue;
      seen.add(iid);
      final line = [
        s.importadorBusinessName,
        s.importadorCiudad,
        s.importadorEstado,
      ]
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .join(', ');
      if (line.isNotEmpty) addDistinct('$line, Venezuela');
    }
  } else {
    final o = request.ownerUbicacionUnaLineaParaMapa.trim();
    if (o.isNotEmpty) addDistinct(o);
  }

  final dest = request.destinoEntregaTextoParaMapa.trim();
  if (dest.isNotEmpty) addDistinct(dest);

  if (parts.length < 2) return null;
  return googleMapsDirAddressStops(parts);
}

List<LatLng> _dedupeConsecutiveStops(List<LatLng> stops) {
  if (stops.isEmpty) return stops;
  const eps = 1e-5;
  final out = <LatLng>[stops.first];
  for (var i = 1; i < stops.length; i++) {
    final b = stops[i];
    final a = out.last;
    if ((a.latitude - b.latitude).abs() < eps &&
        (a.longitude - b.longitude).abs() < eps) {
      continue;
    }
    out.add(b);
  }
  return out;
}

/// Paradas del envío que faltan: opcional posición en vivo o base del transportista,
/// almacenes **pendientes** de recogida, y destino aliado.
List<LatLng> buildRemainingShipmentWaypoints({
  required TransactionRequestModel request,
  ProfileModel? transportista,
  LatLng? livePosition,
}) {
  final stops = <LatLng>[];

  if (livePosition != null) {
    stops.add(livePosition);
  } else {
    final base = _latLngFromProfile(transportista);
    if (base != null) stops.add(base);
  }

  if (request.isMasterOrder && request.subOrders.isNotEmpty) {
    final sorted = List<SubOrderModel>.from(request.subOrders)
      ..sort((a, b) => a.id.compareTo(b.id));
    final seen = <String>{};
    for (final s in sorted) {
      if (s.transportistaRecogioEnAlmacen) continue;
      final iid = s.importadorId.trim();
      if (iid.isEmpty || seen.contains(iid)) continue;
      seen.add(iid);
      final imp = _latLngSubImporter(s);
      if (imp != null) stops.add(imp);
    }
  } else {
    if (!request.transportistaRecogioAlmacenSimple) {
      final oLa = request.ownerLatitude;
      final oLo = request.ownerLongitude;
      LatLng? imp;
      if (oLa != null && oLo != null) {
        imp = LatLng(oLa, oLo);
      } else {
        imp = parseLatLngFromGoogleMapsUrl(request.ownerFiscalMapsUrl);
      }
      if (imp != null) stops.add(imp);
    }
  }

  LatLng? dest;
  if (!request.destinoEntregaUsaPerfil) {
    dest = parseLatLngFromGoogleMapsUrl(request.destinoEntregaMapsUrl);
  } else {
    final aLa = request.aliadoLatitude;
    final aLo = request.aliadoLongitude;
    if (aLa != null && aLo != null) {
      dest = LatLng(aLa, aLo);
    } else {
      dest = parseLatLngFromGoogleMapsUrl(request.aliadoFiscalMapsUrl);
    }
  }
  if (dest != null) stops.add(dest);

  return _dedupeConsecutiveStops(stops);
}

/// URL Google Maps con paradas restantes (misma convención que al asignar transportista).
Uri? googleMapsRemainingRouteUrl({
  required TransactionRequestModel request,
  ProfileModel? transportista,
  LatLng? livePosition,
}) {
  final w = buildRemainingShipmentWaypoints(
    request: request,
    transportista: transportista,
    livePosition: livePosition,
  );
  if (w.length < 2) return null;
  return googleMapsDirLatLngStops(w);
}

/// Igual que [googleMapsRemainingRouteUrl] pero con direcciones si faltan coordenadas.
Uri? googleMapsRemainingRouteAddressFallback({
  required TransactionRequestModel request,
  ProfileModel? transportista,
}) {
  final parts = <String>[];

  void addDistinct(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    if (parts.isNotEmpty && parts.last.toLowerCase() == t.toLowerCase()) {
      return;
    }
    parts.add(t);
  }

  if (transportista != null) {
    final tp = [
      transportista.direccion,
      transportista.ciudad,
      transportista.estado,
      transportista.businessName,
    ]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');
    if (tp.isNotEmpty) addDistinct('$tp, Venezuela');
  }

  if (request.isMasterOrder && request.subOrders.isNotEmpty) {
    final sorted = List<SubOrderModel>.from(request.subOrders)
      ..sort((a, b) => a.id.compareTo(b.id));
    final seen = <String>{};
    for (final s in sorted) {
      if (s.transportistaRecogioEnAlmacen) continue;
      final iid = s.importadorId.trim();
      if (iid.isEmpty || seen.contains(iid)) continue;
      seen.add(iid);
      final line = [
        s.importadorBusinessName,
        s.importadorCiudad,
        s.importadorEstado,
      ]
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .join(', ');
      if (line.isNotEmpty) addDistinct('$line, Venezuela');
    }
  } else {
    if (!request.transportistaRecogioAlmacenSimple) {
      final o = request.ownerUbicacionUnaLineaParaMapa.trim();
      if (o.isNotEmpty) addDistinct(o);
    }
  }

  final dest = request.destinoEntregaTextoParaMapa.trim();
  if (dest.isNotEmpty) addDistinct(dest);

  if (parts.length < 2) return null;
  return googleMapsDirAddressStops(parts);
}

/// Ruta por carretera aproximada pasando por [waypoints] en orden (OSRM público).
Future<List<LatLng>?> fetchDrivingRouteOsrmWaypoints(List<LatLng> waypoints) async {
  if (waypoints.length < 2) return null;
  final coordPath = waypoints
      .map((p) => '${p.longitude},${p.latitude}')
      .join(';');
  final uri = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/$coordPath'
    '?overview=simplified&geometries=geojson',
  );
  try {
    final resp = await http.get(uri).timeout(const Duration(seconds: 18));
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) return null;
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final first = routes.first;
    if (first is! Map<String, dynamic>) return null;
    final geometry = first['geometry'];
    if (geometry is! Map<String, dynamic>) return null;
    final coords = geometry['coordinates'];
    if (coords is! List) return null;
    final out = <LatLng>[];
    for (final pair in coords) {
      if (pair is List && pair.length >= 2) {
        final lng = (pair[0] as num).toDouble();
        final lat = (pair[1] as num).toDouble();
        out.add(LatLng(lat, lng));
      }
    }
    return out.length >= 2 ? out : null;
  } catch (_) {
    return null;
  }
}
