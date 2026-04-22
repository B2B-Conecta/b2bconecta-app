import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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
