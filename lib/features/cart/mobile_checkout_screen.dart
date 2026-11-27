import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/desktop_workflow.dart';
import 'package:motolink_pro_app/core/widgets/b2b_header_title.dart';
import '../../app/theme/b2b_theme_extension.dart';
import '../../core/data/supabase_service.dart';
import '../../core/utils/ves_amount_format.dart';
import '../logistics/carrier_eta_format.dart';
import '../logistics/carrier_flete_pago_modo.dart';
import '../logistics/envio_politica.dart';
import '../logistics/importer_carrier_model.dart';
import '../orders/shared/mobile_chat_widgets.dart';
import '../profile/profile_model.dart';
import 'cart_service.dart';
import 'delivery_destination_dialog.dart';
import 'mobile_checkout_model.dart';
import 'checkout_delivery_data.dart';

typedef CheckoutCarrierLoader = Future<List<ImporterCarrierModel>> Function(
    String supplierId,
    {String? state,
    String? city,
    double? latitude,
    double? longitude});

Future<List<ImporterCarrierModel>> loadMobileCheckoutCarriers(String supplierId,
        {String? state, String? city, double? latitude, double? longitude}) =>
    SupabaseService.listImporterCarriersForCheckout(
        importadorId: supplierId,
        destEstado: state,
        destCiudad: city,
        destLatitude: latitude,
        destLongitude: longitude);

class MobileCheckoutExit {
  const MobileCheckoutExit({required this.orderId, this.viewOrder = false});
  final String orderId;
  final bool viewOrder;
}

class MobileCheckoutScreen extends StatefulWidget {
  const MobileCheckoutScreen(
      {super.key,
      required this.profile,
      required this.lines,
      required this.initialPayUsd,
      this.initialPayUsdBySupplier = const {},
      this.onCurrenciesChanged,
      required this.rate,
      required this.credits,
      required this.submit,
      this.loadAddresses,
      this.saveAddress,
      this.deleteAddress,
      this.loadPickups,
      this.loadCarriers = loadMobileCheckoutCarriers});
  final ProfileModel profile;
  final List<CartLine> lines;
  final bool initialPayUsd;
  final Map<String, bool> initialPayUsdBySupplier;
  final ValueChanged<Map<String, bool>>? onCurrenciesChanged;
  final double? rate;
  final Map<String, double> credits;
  final Future<String> Function(MobileCheckoutSubmission submission) submit;
  final CheckoutCarrierLoader loadCarriers;
  final Future<List<SavedDeliveryAddress>> Function()? loadAddresses;
  final Future<SavedDeliveryAddress> Function(SavedDeliveryAddress)?
      saveAddress;
  final Future<void> Function(String)? deleteAddress;
  final Future<List<CheckoutPickupOption>> Function(String)? loadPickups;
  @override
  State<MobileCheckoutScreen> createState() => _MobileCheckoutScreenState();
}

class _MobileCheckoutScreenState extends State<MobileCheckoutScreen> {
  final _form = GlobalKey<FormState>();
  final _addressLabel = TextEditingController();
  List<SavedDeliveryAddress> _addresses = [];
  String? _savedAddressId, _editingAddressId;
  bool _addressesLoading = false,
      _addressesFailed = false,
      _addressTouched = false;
  bool _rememberAddress = false,
      _defaultAddress = false,
      _savingAddress = false;
  bool _recoveredOrder = false;
  final _pickupOptions = <String, List<CheckoutPickupOption>>{};
  final _pickups = <String, CheckoutPickupOption>{};
  final _scroll = ScrollController();
  final _state = TextEditingController(),
      _city = TextEditingController(),
      _address = TextEditingController(),
      _maps = TextEditingController();
  late bool _payUsd = widget.initialPayUsd;
  late final Map<String, bool> _payUsdBySupplier = {
    for (final entry in _groups.entries)
      entry.key: entry.value.any((line) => line.part.ownerPagoSoloDivisas) ||
              (widget.rate ?? 0) <= 0
          ? true
          : widget.initialPayUsdBySupplier[entry.key] ?? widget.initialPayUsd,
  };
  bool _supplierPaysUsd(String id) => _payUsdBySupplier[id] ?? _payUsd;
  bool _profileAddress = true,
      _loading = false,
      _sending = false,
      _allowPop = false,
      _leaving = false;
  int _step = 0, _loadTicket = 0;
  String? _error, _orderId;
  String? _loadedDestination;
  final _options = <String, List<ImporterCarrierModel>>{};
  final _chosen = <String, ImporterCarrierModel>{};
  final _drivers = <String, String?>{};
  final _failed = <String>{};

  Map<String, List<CartLine>> get _groups {
    final groups = <String, List<CartLine>>{};
    for (final line in widget.lines) {
      groups.putIfAbsent(line.part.ownerId ?? '', () => []).add(line);
    }
    return groups;
  }

  String _supplier(String id) =>
      _groups[id]?.first.part.ownerBusinessName ?? 'Proveedor';
  String get _profileSummary => [
        widget.profile.estado,
        widget.profile.ciudad,
        widget.profile.direccion
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
  String get _destinationText => _profileAddress
      ? _profileSummary
      : 'Estado: ${_state.text.trim()}\nCiudad: ${_city.text.trim()}\nDomicilio: ${_address.text.trim()}';
  String get _destinationKey =>
      '$_profileAddress|$_savedAddressId|$_destinationText|${_maps.text.trim()}';
  String get _addressSelection =>
      _profileAddress ? 'profile' : _savedAddressId ?? 'new';
  MobileCheckoutTotals get _totals => MobileCheckoutTotals(
      lines: widget.lines,
      payUsd: _payUsd,
      credits: widget.credits,
      carriers: _chosen,
      supplierCount: _groups.length,
      payUsdBySupplier: _payUsdBySupplier,
      pickupSuppliers: _pickups.keys.toSet(),
      rate: widget.rate);
  bool get _currencyValid => _groups.entries.every((entry) =>
      _supplierPaysUsd(entry.key) ||
      ((widget.rate ?? 0) > 0 &&
          !entry.value.any((l) => l.part.ownerPagoSoloDivisas)));
  bool get _deliveryValid =>
      !_loading &&
      _failed.isEmpty &&
      _groups.keys.every((id) =>
          _pickups.containsKey(id) ||
          (_options[id]?.isEmpty ?? false) ||
          _chosen.containsKey(id));

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final loader = widget.loadAddresses;
    if (loader == null) return;
    setState(() {
      _addressesLoading = true;
      _addressesFailed = false;
    });
    try {
      final addresses = await loader();
      if (!mounted) return;
      setState(() {
        _addresses = List.of(addresses);
        final preferred = addresses.where((a) => a.isDefault).firstOrNull;
        if (!_addressTouched && _step == 0 && preferred != null) {
          _selectSavedAddress(preferred);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _addressesFailed = true);
    } finally {
      if (mounted) setState(() => _addressesLoading = false);
    }
  }

  void _selectSavedAddress(SavedDeliveryAddress address) {
    _profileAddress = false;
    _savedAddressId = address.id;
    _editingAddressId = null;
    _rememberAddress = false;
    _state.text = address.state;
    _city.text = address.city;
    _address.text = address.address;
    _maps.text = address.mapsUrl;
    _error = null;
  }

  void _editAddress([SavedDeliveryAddress? address]) {
    setState(() {
      _addressTouched = true;
      _profileAddress = false;
      _savedAddressId = null;
      _editingAddressId = address?.id;
      _rememberAddress = address != null;
      _defaultAddress = address?.isDefault ?? false;
      _addressLabel.text = address?.label ?? '';
      _state.text = address?.state ?? '';
      _city.text = address?.city ?? '';
      _address.text = address?.address ?? '';
      _maps.text = address?.mapsUrl ?? '';
      _error = null;
    });
  }

  Future<void> _deleteSavedAddress(SavedDeliveryAddress address) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Eliminar dirección'),
                content: Text(
                    '¿Eliminar «${address.label}» de tus direcciones guardadas?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Eliminar'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _savingAddress = true);
    try {
      await widget.deleteAddress!(address.id!);
      if (!mounted) return;
      setState(() {
        _addresses.removeWhere((a) => a.id == address.id);
        if (_savedAddressId == address.id) {
          _savedAddressId = null;
          _profileAddress = true;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'No pudimos eliminar la dirección. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _savingAddress = false);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _state.dispose();
    _city.dispose();
    _address.dispose();
    _maps.dispose();
    _addressLabel.dispose();
    super.dispose();
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  Future<void> _exit([bool viewOrder = false]) async {
    if (_sending || _leaving || _savingAddress) return;
    _leaving = true;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      Navigator.pop(
          context,
          _orderId == null
              ? null
              : MobileCheckoutExit(orderId: _orderId!, viewOrder: viewOrder));
    }
  }

  void _back() {
    if (_sending || _savingAddress) return;
    if (_orderId != null || _step == 0) {
      _exit();
    } else {
      _go(_step - 1);
    }
  }

  Future<T> _queryDeliveryOptions<T>(
    String rpcName,
    Future<T> Function() load,
  ) async {
    try {
      return await load();
    } catch (error) {
      final code = error is PostgrestException ? error.code : error.runtimeType;
      debugPrint('Checkout: $rpcName falló ($code).');
      rethrow;
    }
  }

  Future<void> _loadDelivery() async {
    final key = _destinationKey;
    if (_loadedDestination == key && _failed.isEmpty) return;
    final ticket = ++_loadTicket;
    final previous = _loadedDestination == key
        ? Map<String, ImporterCarrierModel>.from(_chosen)
        : <String, ImporterCarrierModel>{};
    final previousDrivers = Map<String, String?>.from(_drivers);
    final previousPickups = Map<String, CheckoutPickupOption>.from(_pickups);
    setState(() {
      _loading = true;
      _error = null;
      _failed.clear();
      _options.clear();
      _chosen.clear();
      _drivers.clear();
      _pickups.clear();
      _pickupOptions.clear();
    });
    await Future.wait(_groups.keys.map((id) async {
      try {
        final results = await Future.wait<dynamic>([
          _queryDeliveryOptions(
            'list_importer_carriers_for_checkout',
            () => widget.loadCarriers(id,
                state:
                    _profileAddress ? widget.profile.estado : _state.text.trim(),
                city: _profileAddress ? widget.profile.ciudad : _city.text.trim(),
                latitude: _profileAddress ? widget.profile.latitude : null,
                longitude: _profileAddress ? widget.profile.longitude : null),
          ),
          _queryDeliveryOptions(
            'list_customer_pickup_for_checkout',
            () async => await widget.loadPickups?.call(id) ??
                <CheckoutPickupOption>[],
          ),
        ]);
        final options = results[0] as List<ImporterCarrierModel>;
        final pickupOptions = results[1] as List<CheckoutPickupOption>;
        if (!mounted || ticket != _loadTicket) return;
        final available = options
            .where((c) =>
                c.importadorId == id &&
                c.isActive &&
                c.coversDestination &&
                (c.feeUsd == null || (c.feeUsd!.isFinite && c.feeUsd! >= 0)))
            .toList();
        _options[id] = available;
        _pickupOptions[id] =
            pickupOptions.where((p) => p.supplierId == id).toList();
        final retainedPickup = _pickupOptions[id]!
            .where((p) => p.id == previousPickups[id]?.id)
            .firstOrNull;
        if (retainedPickup != null) {
          _pickups[id] = retainedPickup;
          return;
        }
        final retained =
            available.where((c) => c.id == previous[id]?.id).firstOrNull;
        if (retained != null) {
          _chosen[id] = retained;
          if (retained.drivers.any((d) => d.id == previousDrivers[id])) {
            _drivers[id] = previousDrivers[id];
          }
        } else if (available.length == 1) {
          _chosen[id] = available.first;
        }
      } catch (_) {
        if (mounted && ticket == _loadTicket) _failed.add(id);
      }
    }));
    if (mounted && ticket == _loadTicket) {
      setState(() {
        _loadedDestination = key;
        _loading = false;
      });
    }
  }

  Future<void> _next() async {
    if (_sending || _loading || _savingAddress) return;
    if (_step == 0) {
      if (_profileAddress &&
          (!widget.profile.hasFiscalMapsShareLink ||
              [
                widget.profile.estado,
                widget.profile.ciudad,
                widget.profile.direccion
              ].any((value) => value == null || value.trim().isEmpty))) {
        setState(() => _error =
            'Completa la dirección y el enlace de Google Maps de tu perfil, o agrega otra dirección.');
        return;
      }
      if (!_profileAddress &&
          _savedAddressId == null &&
          !_form.currentState!.validate()) {
        setState(() => _error =
            'Completa los campos de la dirección marcados para continuar.');
        return;
      }
      if (!_profileAddress &&
          _savedAddressId == null &&
          _rememberAddress &&
          widget.saveAddress != null) {
        setState(() => _savingAddress = true);
        try {
          final saved = await widget.saveAddress!(SavedDeliveryAddress(
              id: _editingAddressId,
              label: _addressLabel.text,
              state: _state.text,
              city: _city.text,
              address: _address.text,
              mapsUrl: _maps.text,
              isDefault: _defaultAddress));
          if (!mounted) return;
          setState(() {
            if (saved.isDefault) {
              _addresses = _addresses
                  .map((a) => SavedDeliveryAddress(
                      id: a.id,
                      label: a.label,
                      state: a.state,
                      city: a.city,
                      address: a.address,
                      mapsUrl: a.mapsUrl))
                  .toList();
            }
            _addresses.removeWhere((a) => a.id == saved.id);
            _addresses.add(saved);
            _selectSavedAddress(saved);
          });
        } catch (_) {
          if (mounted) {
            setState(() => _error =
                'No pudimos guardar la dirección. Reintenta o úsala solo para este pedido.');
          }
          return;
        } finally {
          if (mounted) setState(() => _savingAddress = false);
        }
      }
      _go(1);
      await _loadDelivery();
    } else if (_step == 1) {
      if (!_deliveryValid) {
        setState(() => _error =
            'Elige el transporte de cada proveedor o reintenta la carga.');
        return;
      }
      _go(2);
    } else {
      if (!_currencyValid || !_deliveryValid) return;
      setState(() {
        _sending = true;
        _error = null;
      });
      try {
        final id = await widget.submit(MobileCheckoutSubmission(
            destination: DeliveryDestinationResult(
                useProfile: _profileAddress,
                texto: _profileAddress ? null : _destinationText,
                mapsUrl: _profileAddress ? null : _maps.text.trim()),
            payUsd: _payUsd,
            payUsdBySupplier: Map.unmodifiable(_payUsdBySupplier),
            savedAddressId: _savedAddressId,
            pickups: {
              for (final entry in _pickups.entries) entry.key: entry.value.id
            },
            carriers: {
              for (final e in _chosen.entries)
                e.key: {'carrier_id': e.value.id, 'driver_id': _drivers[e.key]}
            }));
        if (!mounted) return;
        setState(() => _orderId = id);
        if (_scroll.hasClients) _scroll.jumpTo(0);
      } catch (error) {
        if (mounted) {
          if (error is MobileCheckoutRecovered) {
            setState(() {
              _orderId = error.orderId;
              _recoveredOrder = true;
            });
            if (_scroll.hasClients) _scroll.jumpTo(0);
            return;
          }
          setState(() => _error = error is MobileCheckoutException
              ? error.message
              : 'No se pudo confirmar el pedido. Conservamos los datos. Revisa Pedidos antes de volver a intentarlo.');
        }
      } finally {
        if (mounted) setState(() => _sending = false);
      }
    }
  }

  Widget _card(List<Widget> children, {bool selected = false}) {
    final theme = B2BThemeExtension.of(context);
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: selected ? theme.brandContainer : theme.surfaceCard,
            border:
                selected ? Border.all(color: mobileChatBlue, width: 1.2) : null,
            borderRadius: BorderRadius.circular(16)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children));
  }

  Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)));
  Widget _notice(String text, {bool warning = false}) {
    final theme = B2BThemeExtension.of(context);
    return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: warning ? theme.warningBg : theme.brandContainer,
            borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(warning ? Icons.info_outline : Icons.info_outline,
              size: 20, color: warning ? theme.warningFg : theme.brand),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: theme.textPrimary, fontSize: 13)))
        ]));
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500)))
      ]));
  String _amount(double amount) =>
      '${formatRefAmount(amount)} ${(_payUsdBySupplier.values.firstOrNull ?? _payUsd) ? 'USD' : 'REF'}';
  String _supplierAmount(String id, double amount) =>
      '${formatRefAmount(amount)} ${_supplierPaysUsd(id) ? 'USD' : 'REF'}';
  String get _shippingLabel {
    final totals = _totals;
    if (_loading) return 'Consultando…';
    if (_pickups.length == _groups.length) return 'Retiro sin costo';
    if (_options.entries.any((entry) =>
        entry.value.isNotEmpty &&
        !_chosen.containsKey(entry.key) &&
        !_pickups.containsKey(entry.key))) {
      return 'Selecciona el transporte';
    }
    if (totals.shippingPending && totals.quotedShippingUsd == 0) {
      return 'Por confirmar';
    }
    return '${formatRefAmount(totals.quotedShippingUsd)} USD${totals.shippingPending ? ' + por confirmar' : ' estimados'}';
  }

  String get _payableLabel {
    final totals = _totals;
    if (totals.mixedCurrencies) {
      final bs = (widget.rate ?? 0) > 0
          ? formatBsLabel(totals.netRef * widget.rate!)
          : '${formatRefAmount(totals.netRef)} REF';
      return '${formatRefAmount(totals.netUsd)} USD + $bs';
    }
    final usd = totals.suppliers.values.firstOrNull?.payUsd ?? _payUsd;
    return '${formatRefAmount(totals.estimatedTotal ?? totals.netProducts)} ${usd ? 'USD' : 'REF'}';
  }

  Widget _steps() => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        for (var i = 0; i < 3; i++)
          Expanded(
              child: Column(children: [
            Row(children: [
              Expanded(
                  child: Divider(
                      color: i == 0
                          ? Colors.transparent
                          : i <= _step
                              ? mobileChatBlue
                              : Colors.grey.shade300)),
              Icon(
                  i < _step
                      ? Icons.check_circle
                      : i == _step
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                  size: 22,
                  color: i <= _step ? mobileChatBlue : Colors.grey),
              Expanded(
                  child: Divider(
                      color: i == 2
                          ? Colors.transparent
                          : i < _step
                              ? mobileChatBlue
                              : Colors.grey.shade300))
            ]),
            const SizedBox(height: 4),
            Text(['Dirección', 'Entrega', 'Revisión'][i],
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        i == _step ? FontWeight.w700 : FontWeight.w400)),
          ])),
      ]));

  List<Widget> _addressStep() => [
        _heading('¿Dónde recibes tu pedido?'),
        _card([
          RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'profile',
              groupValue: _addressSelection,
              title: const Text('Mi tienda',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${widget.profile.businessName ?? 'Dirección de mi perfil'}\n$_profileSummary'),
              onChanged: (_) => setState(() {
                    _profileAddress = true;
                    _addressTouched = true;
                    _savedAddressId = null;
                    _error = null;
                  })),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () => setState(() {
                        _profileAddress = false;
                        _addressTouched = true;
                        _savedAddressId = null;
                        _editingAddressId = null;
                        _rememberAddress = false;
                        _state.text = widget.profile.estado ?? '';
                        _city.text = widget.profile.ciudad ?? '';
                        _address.text = widget.profile.direccion ?? '';
                        _maps.text = widget.profile.fiscalMapsUrl ?? '';
                        _error = null;
                      }),
                  child: const Text('Editar para este pedido')))
        ], selected: _profileAddress),
        if (_addressesLoading) const LinearProgressIndicator(minHeight: 2),
        if (_addressesFailed)
          Row(children: [
            const Expanded(
                child: Text(
                    'No pudimos cargar tus direcciones guardadas. Puedes usar otra dirección.',
                    style: TextStyle(fontSize: 12))),
            TextButton(
                onPressed: _loadAddresses, child: const Text('Reintentar')),
          ]),
        for (final saved in _addresses)
          _card([
            RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: saved.id!,
                groupValue: _addressSelection,
                title: Text(
                    '${saved.label}${saved.isDefault ? ' · Predeterminada' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(saved.summary),
                onChanged: _savingAddress
                    ? null
                    : (_) => setState(() {
                          _addressTouched = true;
                          _selectSavedAddress(saved);
                        })),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (widget.saveAddress != null)
                TextButton(
                    onPressed:
                        _savingAddress ? null : () => _editAddress(saved),
                    child: const Text('Editar')),
              if (widget.deleteAddress != null)
                TextButton(
                    onPressed: _savingAddress
                        ? null
                        : () => _deleteSavedAddress(saved),
                    child: const Text('Eliminar')),
            ]),
          ], selected: _savedAddressId == saved.id),
        _card([
          RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'new',
              groupValue: _addressSelection,
              title: const Text('Otra dirección',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(widget.saveAddress == null
                  ? 'Se usará solo para este pedido.'
                  : 'Puedes guardarla para próximas compras.'),
              onChanged: (_) => setState(() {
                    _profileAddress = false;
                    _addressTouched = true;
                    _savedAddressId = null;
                    _error = null;
                  })),
          if (!_profileAddress && _savedAddressId == null) ...[
            for (final field in [
              (_state, 'Estado'),
              (_city, 'Ciudad'),
              (_address, 'Dirección y referencia'),
              (_maps, 'Enlace de Google Maps')
            ])
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextFormField(
                      controller: field.$1,
                      decoration: InputDecoration(
                          labelText: field.$2, errorMaxLines: 2),
                      minLines: field.$1 == _address ? 2 : 1,
                      maxLines: field.$1 == _address ? 4 : 1,
                      keyboardType: field.$1 == _maps
                          ? TextInputType.url
                          : TextInputType.text,
                      textInputAction: field.$1 == _maps
                          ? TextInputAction.done
                          : TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Completa ${field.$2.toLowerCase()}.';
                        }
                        if (field.$1 == _maps) {
                          final uri = Uri.tryParse(value.trim());
                          if (uri == null ||
                              !uri.hasAuthority ||
                              uri.host.isEmpty ||
                              !['http', 'https'].contains(uri.scheme)) {
                            return 'Usa un enlace completo: https://…';
                          }
                        }
                        return null;
                      })),
            if (widget.saveAddress != null) ...[
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Guardar en mis direcciones'),
                  value: _rememberAddress,
                  onChanged: _savingAddress
                      ? null
                      : (value) =>
                          setState(() => _rememberAddress = value == true)),
              if (_rememberAddress) ...[
                TextFormField(
                    controller: _addressLabel,
                    decoration: const InputDecoration(
                        labelText: 'Nombre de la dirección',
                        hintText: 'Ej. Almacén',
                        errorMaxLines: 2),
                    maxLength: 80,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Escribe un nombre para guardar la dirección.'
                        : null),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usar como predeterminada'),
                    value: _defaultAddress,
                    onChanged: _savingAddress
                        ? null
                        : (value) =>
                            setState(() => _defaultAddress = value == true)),
              ],
            ],
          ]
        ], selected: !_profileAddress && _savedAddressId == null),
        _notice(
            'Esta dirección se usará para los envíos a domicilio. También podrás elegir retiro si el proveedor lo ofrece.'),
      ];

  List<Widget> _deliveryStep() => [
        _card([
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const Icon(Icons.location_on_outlined,
                color: mobileChatBlue, size: 22),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_profileAddress ? 'Mi tienda' : 'Otra dirección',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(_destinationText.replaceAll('\n', ', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ])),
            SizedBox(
                width: 96,
                child: TextButton(
                    onPressed: () => _go(0),
                    child: const Text('Cambiar dirección',
                        textAlign: TextAlign.center))),
          ]),
        ]),
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Revisa cómo recibir cada envío.')),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator())),
        if (!_loading)
          for (final id in _groups.keys)
            _card([
              Row(children: [
                const Icon(Icons.storefront_outlined,
                    color: mobileChatBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_supplier(id),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: mobileChatBlue)))
              ]),
              const SizedBox(height: 6),
              if (_failed.contains(id)) ...[
                const Text(
                    'No pudimos cargar las opciones de entrega o retiro de este proveedor.'),
                TextButton(
                    onPressed: _loadDelivery,
                    child: const Text('Reintentar transporte'))
              ] else if (_options[id]?.isEmpty ?? true) ...[
                if (_pickupOptions[id]?.isNotEmpty ?? false)
                  RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'delivery',
                      groupValue: _pickups[id] == null
                          ? 'delivery'
                          : 'pickup:${_pickups[id]!.id}',
                      title: const Text('Entrega a coordinar con el proveedor'),
                      subtitle: const Text('Costo por confirmar.'),
                      onChanged: (_) => setState(() => _pickups.remove(id)))
                else ...[
                  const Text('Entrega a coordinar con el proveedor',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Text(
                      'Costo por confirmar. El proveedor indicará la disponibilidad y las condiciones.'),
                  if (EnvioPolitica.notaConfirmacion(
                          tipo: _groups[id]!.first.part.ownerEnvioTipo,
                          proveedor: _supplier(id),
                          minimoGratis:
                              _groups[id]!.first.part.ownerEnvioGratisMinimo)
                      case final String note)
                    Text(note),
                ],
              ] else
                for (final carrier in _options[id]!) ...[
                  RadioListTile<String>(
                      value: carrier.id,
                      groupValue: _pickups[id] == null
                          ? _chosen[id]?.id
                          : 'pickup:${_pickups[id]!.id}',
                      contentPadding: EdgeInsets.zero,
                      title: Text(carrier.companyName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${carrier.feeUsd == null ? 'Costo por confirmar' : '${formatRefAmount(carrier.feeUsd!)} USD estimados'}\n${CarrierFletePagoModo.labelEs(carrier.fletePagoModo)}'
                          '${carrier.etaHours == null ? '' : '\n${CarrierEtaFormat.etaLabel(carrier.etaHours)}'}'),
                      onChanged: (_) => setState(() {
                            _chosen[id] = carrier;
                            _pickups.remove(id);
                            _drivers.remove(id);
                            _error = null;
                          })),
                  if (_chosen[id]?.id == carrier.id &&
                      carrier.drivers.isNotEmpty)
                    DropdownButtonFormField<String>(
                        key: ValueKey('driver-$id-${carrier.id}'),
                        value: _drivers[id],
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Conductor (opcional)'),
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Sin preferencia')),
                          for (final driver in carrier.drivers)
                            DropdownMenuItem(
                                value: driver.id,
                                child: Text(driver.driverName))
                        ],
                        onChanged: (value) => setState(() => _drivers[id] =
                            value?.isEmpty == true ? null : value)),
                ],
              if (!_failed.contains(id))
                for (final pickup
                    in _pickupOptions[id] ?? <CheckoutPickupOption>[])
                  RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      key: ValueKey('pickup-$id-${pickup.id}'),
                      value: 'pickup:${pickup.id}',
                      groupValue: _pickups[id] != null
                          ? 'pickup:${_pickups[id]!.id}'
                          : _chosen[id]?.id,
                      title: Text('Retiro en tienda · ${pickup.label}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${pickup.summary}\nSin costo${pickup.instructions.isEmpty ? '' : '\n${pickup.instructions}'}'),
                      onChanged: (_) => setState(() {
                            _pickups[id] = pickup;
                            _chosen.remove(id);
                            _drivers.remove(id);
                            _error = null;
                          })),
            ]),
        _notice(
            'Las tarifas de transporte son estimadas. Cada proveedor confirma disponibilidad, envío y factura.'),
      ];

  Future<void> _changeCurrency(String supplierId) async {
    if (_sending) return;
    final canPayBs =
        !_groups[supplierId]!.any((line) => line.part.ownerPagoSoloDivisas) &&
            (widget.rate ?? 0) > 0;
    final supplier = _totals.suppliers[supplierId]!;
    final choice = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Moneda de pago',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700))),
                    CloseButton(onPressed: () => Navigator.pop(sheetContext)),
                  ]),
                  Text(_supplier(supplierId),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bolívares · REF al BCV'),
                      value: false,
                      groupValue: _supplierPaysUsd(supplierId),
                      subtitle: canPayBs
                          ? null
                          : Text(_groups[supplierId]!
                                  .any((line) => line.part.ownerPagoSoloDivisas)
                              ? 'Hay proveedores que requieren pago en divisas.'
                              : 'No hay una tasa BCV disponible.'),
                      onChanged: canPayBs
                          ? (value) => Navigator.pop(sheetContext, value)
                          : null),
                  RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Divisas · USD'),
                      subtitle: Text(supplier.usdSavings > 0.009
                          ? 'Ahorra ${formatRefAmount(supplier.usdSavings)} USD con este proveedor.'
                          : 'Este proveedor no ofrece un ahorro adicional en USD.'),
                      value: true,
                      groupValue: _supplierPaysUsd(supplierId),
                      onChanged: (value) => Navigator.pop(sheetContext, value)),
                ]),
          )),
    );
    if (mounted && choice != null) {
      setState(() {
        _payUsdBySupplier[supplierId] = choice;
        if (_payUsdBySupplier.values.toSet().length == 1) _payUsd = choice;
      });
      widget.onCurrenciesChanged?.call(Map.unmodifiable(_payUsdBySupplier));
    }
  }

  Widget _supplierCurrency(String id) {
    final quote = _totals.suppliers[id]!;
    final usd = _supplierPaysUsd(id);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.payments_outlined, size: 22),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Moneda de pago',
              style: TextStyle(fontWeight: FontWeight.w700)),
          Text(usd ? 'USD' : 'Bolívares al BCV'),
        ])),
        TextButton(
            key: ValueKey('currency-$id'),
            onPressed: _sending ? null : () => _changeCurrency(id),
            child: const Text('Cambiar')),
      ]),
      if (quote.usdSavings > 0.009)
        Text(
            usd
                ? 'Ahorro en USD: ${formatRefAmount(quote.usdSavings)} USD'
                : 'Si pagas en USD, ahorras ${formatRefAmount(quote.usdSavings)} USD.',
            style: TextStyle(
                fontSize: 12,
                color: B2BThemeExtension.of(context).textPrimary)),
      if (_groups[id]!.any((line) => line.part.ownerPagoSoloDivisas))
        const Text('Este proveedor solo acepta divisas.',
            style: TextStyle(fontSize: 12)),
      _row('Subtotal a este proveedor', _supplierAmount(id, quote.net),
          bold: true),
      if (quote.credit > 0)
        Text('Incluye ${_supplierAmount(id, quote.credit)} de saldo a favor.',
            style: const TextStyle(fontSize: 12)),
      if (!usd && (widget.rate ?? 0) > 0)
        Text(formatBsLabel(quote.net * widget.rate!),
            style: const TextStyle(fontWeight: FontWeight.w600)),
    ]);
  }

  List<Widget> _reviewStep() => [
        _card([
          _heading(
              'Entrega en ${_profileAddress ? 'mi tienda' : 'otra dirección'}'),
          Text(_destinationText),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: _sending ? null : () => _go(0),
                  child: const Text('Editar dirección')))
        ]),
        for (final id in _groups.keys)
          _card([
            _heading(_supplier(id)),
            for (final line in _groups[id]!)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    _ProductPhoto(
                        url: line.part.imagenUrl ??
                            line.part.imageUrls.firstOrNull),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(line.part.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                              '${line.quantity} uds × ${_supplierAmount(id, checkoutUnitPrice(line, payUsd: _supplierPaysUsd(id)))}',
                              style: const TextStyle(fontSize: 12)),
                        ])),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(
                            _supplierAmount(
                                id,
                                checkoutUnitPrice(line,
                                        payUsd: _supplierPaysUsd(id)) *
                                    line.quantity),
                            textAlign: TextAlign.end,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                  ])),
            if (_pickups[id] case final CheckoutPickupOption pickup) ...[
              Text('Retiro en tienda · ${pickup.label}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(pickup.summary, style: const TextStyle(fontSize: 12)),
              const Text('Retiro sin costo', style: TextStyle(fontSize: 12)),
              if (pickup.instructions.isNotEmpty)
                Text(pickup.instructions, style: const TextStyle(fontSize: 12)),
            ] else
              Text(_chosen[id] == null
                  ? 'Entrega y costo por confirmar'
                  : 'Transporte: ${_chosen[id]!.companyName}'),
            const Divider(height: 24),
            _supplierCurrency(id),
          ]),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: _sending ? null : () => _go(1),
                child: const Text('Cambiar entrega'))),
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
                'Cada proveedor confirma su factura y recibe su pago en la moneda que elegiste para él.',
                style: TextStyle(fontSize: 12))),
        _summary(),
        _notice(
            'El pedido quedará pendiente de confirmación de los proveedores.',
            warning: true),
      ];

  Widget _summary({bool compact = false}) {
    final totals = _totals;
    if (totals.mixedCurrencies) {
      return _card([
        if (!compact) _heading('Resumen por moneda'),
        _row('Productos en USD', '${formatRefAmount(totals.netUsd)} USD',
            bold: true),
        _row('Productos en bolívares',
            formatBsLabel(totals.netRef * widget.rate!),
            bold: true),
        Text(
            'Base: ${formatRefAmount(totals.netRef)} REF · BCV ${formatRefAmount(widget.rate!)} Bs',
            style: const TextStyle(fontSize: 12)),
        _row('Envíos estimados', _shippingLabel),
        const Text(
            'Los importes en distintas monedas se pagan por separado. El transporte se confirma con cada proveedor.',
            style: TextStyle(fontSize: 12)),
      ]);
    }
    return _card([
      if (!compact) _heading('Resumen'),
      if (!compact) _row('Productos', _amount(totals.products)),
      if (totals.credit > 0)
        _row('Saldo a favor', '−${_amount(totals.credit)}'),
      _row(
          'Envíos estimados',
          totals.shippingPending && totals.quotedShippingUsd == 0
              ? 'Por confirmar'
              : '${formatRefAmount(totals.quotedShippingUsd)} USD${totals.shippingPending ? ' + por confirmar' : ''}'),
      if (!compact) const Divider(),
      _row(totals.shippingPending ? 'Subtotal productos' : 'Total estimado',
          _amount(totals.estimatedTotal ?? totals.netProducts),
          bold: true),
      if (!(totals.suppliers.values.firstOrNull?.payUsd ?? _payUsd) &&
          (widget.rate ?? 0) > 0) ...[
        _row(
            totals.shippingPending ? 'Productos en Bs' : 'Estimado en Bs',
            formatBsLabel(
                (totals.estimatedTotal ?? totals.netProducts) * widget.rate!),
            bold: true),
        if (!compact)
          Text('Tasa BCV: ${formatRefAmount(widget.rate!)} Bs por REF/USD',
              style: const TextStyle(fontSize: 12)),
      ],
      if (totals.shippingPending)
        const Text(
            'Falta confirmar uno o más envíos. El importe final puede variar.',
            style: TextStyle(fontSize: 12)),
      if (!compact)
        const Text(
            'El proveedor confirma el flete. El pago al transportista puede ser separado.',
            style: TextStyle(fontSize: 12)),
    ]);
  }

  List<Widget> _success() => _recoveredOrder
      ? [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
          _heading('Recuperamos tu pedido anterior'),
          Text('Referencia: #${_orderId!.substring(0, 8).toUpperCase()}',
              textAlign: TextAlign.center),
          _notice(
              'El pedido ya había sido creado. No se volvió a descontar stock ni saldo. Consulta sus datos en Pedidos.'),
        ]
      : [
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.check_circle_outline,
                  color: Colors.green, size: 64)),
          const Text('¡Tu pedido fue enviado!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Los proveedores revisarán tu solicitud.',
                  textAlign: TextAlign.center)),
          _card([
            Text(
                'Referencia: #${_orderId!.substring(0, _orderId!.length.clamp(0, 8)).toUpperCase()}',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Por confirmar', textAlign: TextAlign.center)
          ]),
          Text(
              '${widget.lines.length} repuestos · ${widget.lines.fold(0, (sum, l) => sum + l.quantity)} unidades · ${_groups.length} proveedores',
              textAlign: TextAlign.center),
          const SizedBox(height: 14),
          _summary(compact: true),
          _card([
            for (final id in _groups.keys)
              _row(_supplier(id),
                  '${_supplierPaysUsd(id) ? 'USD' : 'Bolívares'} · Por confirmar')
          ]),
          _notice('Puedes consultar los avances y las facturas en Pedidos.'),
        ];

  @override
  Widget build(BuildContext context) {
    final created = _orderId != null;
    final desktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
    final sideSummary = MediaQuery.sizeOf(context).width >= 1000 &&
        MediaQuery.textScalerOf(context).scale(14) <= 21;
    final title = created
        ? (_recoveredOrder ? 'Pedido recuperado' : 'Pedido creado')
        : [
            'Dirección de entrega',
            'Entrega por proveedor',
            'Revisa tu pedido'
          ][_step];
    return PopScope<Object?>(
        canPop: _allowPop && !_sending,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: B2BThemeExtension.of(context).background,
          appBar: desktop
              ? desktopWorkflowAppBar(context, title, onBack: _back)
              : AppBar(
                  backgroundColor: mobileChatBlue,
                  foregroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  toolbarHeight: 72,
                  shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(bottom: Radius.circular(24))),
                  leading: BackButton(onPressed: _sending ? null : _back),
                  title: B2bHeaderTitle(
                    title: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  )),
          body: SafeArea(
              top: false,
              child: DesktopWorkflow(
                header: created ? null : _steps(),
                body: AbsorbPointer(
                    absorbing: _sending || _savingAddress,
                    child: Form(
                        key: _form,
                        child: ListView(
                            controller: _scroll,
                            padding: const EdgeInsets.all(16),
                            children: created
                                ? _success()
                                : _step == 0
                                    ? _addressStep()
                                    : _step == 1
                                        ? _deliveryStep()
                                        : _reviewStep()))),
                actions: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (sideSummary && !created) ...[
                            Text('Resumen de tu compra',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            for (final entry in _totals.suppliers.entries)
                              _row(_supplier(entry.key),
                                  '${formatRefAmount(entry.value.net)} ${entry.value.payUsd ? 'USD' : 'REF'}'),
                            const Divider(),
                          ],
                          if (!created && _step == 1)
                            _row('Envíos (${_groups.length} proveedores)',
                                _shippingLabel,
                                bold: true),
                          if (!created && _step == 2) ...[
                            _row(
                                _totals.mixedCurrencies
                                    ? 'Productos por moneda'
                                    : _totals.shippingPending
                                        ? 'Subtotal productos'
                                        : 'Total estimado',
                                _payableLabel,
                                bold: true),
                            if (_totals.shippingPending)
                              const Padding(
                                  padding: EdgeInsets.only(bottom: 6),
                                  child: Text('Envíos por confirmar',
                                      style: TextStyle(fontSize: 12))),
                          ],
                          if (_error != null)
                            Semantics(
                                liveRegion: true,
                                child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(_error!,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                            fontSize: 13)))),
                          FilledButton(
                              onPressed: created
                                  ? () => _exit(true)
                                  : _sending ||
                                          _loading ||
                                          _savingAddress ||
                                          (_step == 1 && !_deliveryValid) ||
                                          (_step == 2 && !_currencyValid)
                                      ? null
                                      : _next,
                              style: FilledButton.styleFrom(
                                  backgroundColor: mobileChatBlue,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 50)),
                              child: _sending
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Text(created
                                      ? 'Ver pedido'
                                      : [
                                          'Continuar con la entrega →',
                                          'Revisar pedido →',
                                          'Confirmar pedido'
                                        ][_step])),
                          if (created)
                            OutlinedButton(
                                onPressed: () => _exit(),
                                child: const Text('Seguir comprando')),
                        ])),
              )),
        ));
  }
}

class MobileCheckoutException implements Exception {
  const MobileCheckoutException(this.message);
  final String message;
}

class MobileCheckoutRecovered implements Exception {
  const MobileCheckoutRecovered(this.orderId);
  final String orderId;
}

class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
          width: 54,
          height: 54,
          child: url == null
              ? const Icon(Icons.inventory_2_outlined)
              : Image.network(url!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.inventory_2_outlined))));
}
