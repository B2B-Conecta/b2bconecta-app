import 'package:motolink_pro_app/features/payments/pago_metodo.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo_instrucciones.dart';
import 'carrier_flete_pago_modo.dart';
import 'importer_carrier_driver_model.dart';

/// Empresa de transporte registrada por un importador.
class ImporterCarrierModel {
  const ImporterCarrierModel({
    required this.id,
    required this.importadorId,
    required this.companyName,
    required this.contactPhone,
    this.contactName,
    this.contactEmail,
    this.contactWhatsapp,
    this.coverageEstados = const [],
    this.coverageCiudades = const [],
    this.coverageNotes,
    this.baseEstado,
    this.baseCiudad,
    this.baseLatitude,
    this.baseLongitude,
    this.baseMapsUrl,
    this.acceptedPagoMetodos = const [],
    this.pagoMetodoInstrucciones = const {},
    this.fletePagoModo = CarrierFletePagoModo.incluidoFactura,
    this.etaBaseHours = 24,
    this.etaHoursPerKm = 0.15,
    this.maxCoverageKm,
    this.flatFeeUsd,
    this.pricePerKmUsd,
    this.notes,
    this.isActive = true,
    this.sortOrder = 0,
    this.distanceKm,
    this.etaHours,
    this.feeUsd,
    this.coversDestination = true,
    this.drivers = const [],
  });

  final String id;
  final String importadorId;
  final String companyName;
  final String? contactName;
  final String contactPhone;
  final String? contactEmail;
  final String? contactWhatsapp;
  final List<String> coverageEstados;
  final List<String> coverageCiudades;
  final String? coverageNotes;
  final String? baseEstado;
  final String? baseCiudad;
  final double? baseLatitude;
  final double? baseLongitude;
  final String? baseMapsUrl;
  final List<String> acceptedPagoMetodos;
  final Map<String, String> pagoMetodoInstrucciones;
  final String fletePagoModo;
  final double etaBaseHours;
  final double etaHoursPerKm;
  final double? maxCoverageKm;
  final double? flatFeeUsd;
  final double? pricePerKmUsd;
  final String? notes;
  final bool isActive;
  final int sortOrder;

  /// Calculado en checkout (`list_importer_carriers_for_checkout`).
  final double? distanceKm;
  final double? etaHours;
  final double? feeUsd;
  final bool coversDestination;
  final List<ImporterCarrierDriverModel> drivers;

  String get coverageLabel {
    final parts = <String>[];
    if (coverageEstados.isNotEmpty) {
      parts.add(coverageEstados.join(', '));
    }
    if (coverageCiudades.isNotEmpty) {
      parts.add(coverageCiudades.join(', '));
    }
    if (parts.isEmpty) return 'Toda Venezuela';
    return parts.join(' · ');
  }

  String get pagoMetodosLabel {
    if (acceptedPagoMetodos.isEmpty) return 'Consultar con transportista';
    return acceptedPagoMetodos.map(PagoMetodo.labelEs).join(', ');
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory ImporterCarrierModel.fromJson(Map<String, dynamic> json) {
    final driverRows = json['drivers'];
    final drivers = <ImporterCarrierDriverModel>[];
    if (driverRows is List) {
      for (final row in driverRows) {
        if (row is Map) {
          drivers.add(
            ImporterCarrierDriverModel.fromJson(
              Map<String, dynamic>.from(row),
            ),
          );
        }
      }
    }

    return ImporterCarrierModel(
      id: json['id']?.toString() ?? '',
      importadorId: json['importador_id']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      contactName: json['contact_name']?.toString(),
      contactPhone: json['contact_phone']?.toString() ?? '',
      contactEmail: json['contact_email']?.toString(),
      contactWhatsapp: json['contact_whatsapp']?.toString(),
      coverageEstados: _parseStringList(json['coverage_estados']),
      coverageCiudades: _parseStringList(json['coverage_ciudades']),
      coverageNotes: json['coverage_notes']?.toString(),
      baseEstado: json['base_estado']?.toString(),
      baseCiudad: json['base_ciudad']?.toString(),
      baseLatitude: _toDouble(json['base_latitude']),
      baseLongitude: _toDouble(json['base_longitude']),
      baseMapsUrl: json['base_maps_url']?.toString(),
      acceptedPagoMetodos: _parseStringList(json['accepted_pago_metodos']),
      pagoMetodoInstrucciones: PagoMetodoInstrucciones.parseMap(
        json['pago_metodo_instrucciones'],
      ),
      fletePagoModo: json['flete_pago_modo']?.toString() ??
          CarrierFletePagoModo.incluidoFactura,
      etaBaseHours: _toDouble(json['eta_base_hours']) ?? 24,
      etaHoursPerKm: _toDouble(json['eta_hours_per_km']) ?? 0.15,
      maxCoverageKm: _toDouble(json['max_coverage_km']),
      flatFeeUsd: _toDouble(json['flat_fee_usd']),
      pricePerKmUsd: _toDouble(json['price_per_km_usd']),
      notes: json['notes']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      distanceKm: _toDouble(json['distance_km']),
      etaHours: _toDouble(json['eta_hours']),
      feeUsd: _toDouble(json['fee_usd']),
      coversDestination: json['covers_destination'] as bool? ?? true,
      drivers: drivers,
    );
  }
}
