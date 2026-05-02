import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/geolocator_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Opcional: el transportista comparte coordenadas del teléfono para este envío (`en_transito`).
class TransportistaLiveEnvioTrackingSection extends StatefulWidget {
  const TransportistaLiveEnvioTrackingSection({
    super.key,
    required this.request,
    this.onChanged,
  });

  final TransactionRequestModel request;
  final VoidCallback? onChanged;

  @override
  State<TransportistaLiveEnvioTrackingSection> createState() =>
      _TransportistaLiveEnvioTrackingSectionState();
}

class _TransportistaLiveEnvioTrackingSectionState
    extends State<TransportistaLiveEnvioTrackingSection> {
  Timer? _tick;
  bool _busy = false;
  bool _localOptIn = false;

  @override
  void initState() {
    super.initState();
    _localOptIn = widget.request.transportistaLiveLocationOptIn;
    if (_localOptIn) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startTicker();
      });
    }
  }

  @override
  void didUpdateWidget(TransportistaLiveEnvioTrackingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.request.transportistaLiveLocationOptIn !=
            widget.request.transportistaLiveLocationOptIn) {
      _localOptIn = widget.request.transportistaLiveLocationOptIn;
      if (_localOptIn) {
        _startTicker();
      } else {
        _tick?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool get _visible =>
      widget.request.status == TransactionRequestStatus.enTransito &&
      widget.request.hasAssignedTransportista &&
      SupabaseService.currentUserId?.trim() ==
          widget.request.assignedTransportistaId?.trim();

  void _startTicker() {
    _tick?.cancel();
    if (!_localOptIn || !_visible) return;
    _tick = Timer.periodic(const Duration(seconds: 55), (_) => _pushLocation());
    _pushLocation();
  }

  Future<void> _pushLocation() async {
    if (!_localOptIn || !mounted) return;
    final loc = await GeolocatorService.getCurrentLatLng();
    if (loc == null || !mounted) return;
    try {
      await SupabaseService.transportistaReportLiveLocation(
        requestId: widget.request.id,
        lat: loc.lat,
        lng: loc.lng,
      );
      widget.onChanged?.call();
    } catch (_) {
      /* permisos / red: no spamear snackbars en cada tick */
    }
  }

  Future<void> _setOptIn(bool v) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.transportistaSetLiveTrackingOptIn(
        requestId: widget.request.id,
        enabled: v,
      );
      if (!mounted) return;
      setState(() => _localOptIn = v);
      if (v) {
        _startTicker();
        final loc = await GeolocatorService.getCurrentLatLng();
        if (loc != null && mounted) {
          await SupabaseService.transportistaReportLiveLocation(
            requestId: widget.request.id,
            lat: loc.lat,
            lng: loc.lng,
          );
          await SupabaseService.transportistaTryRefreshRutaMapsRemaining(
            widget.request.id,
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Seguimiento activo. MotoLink y el aliado verán su posición en el mapa del pedido.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _tick?.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Seguimiento en vivo desactivado para este envío.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Material(
      color: Colors.deepOrange.shade50.withOpacity(0.65),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gps_fixed, size: 20, color: Colors.deepOrange.shade900),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Seguimiento en vivo (opcional)',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Si activa esta opción, la app enviará periódicamente la ubicación de este teléfono '
              'para mostrar su posición en el mapa del pedido. Consume batería y requiere permiso de ubicación. '
              'La ruta en Google Maps también puede usar su posición como primer punto.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _localOptIn ? 'Compartir ubicación' : 'No compartir',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              value: _localOptIn,
              onChanged: _busy ? null : _setOptIn,
            ),
          ],
        ),
      ),
    );
  }
}
