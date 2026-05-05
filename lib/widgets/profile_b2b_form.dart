import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cash_phase_policy.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'motolink_pro_logo.dart';
import 'main_shell_tab.dart';
import 'aliado_kyc_documents_section.dart';
import 'aliado_solicitar_credito_sheet.dart';
import 'authorization_status_section.dart';
import 'profile_kyc_documents_info.dart';

/// Formulario perfil B2B (referencia: Mi Perfil B2B). Dirección fiscal → `profiles.direccion`.
class ProfileB2BForm extends StatefulWidget {
  const ProfileB2BForm({
    super.key,
    required this.initial,
    required this.onSaved,
    this.showCloseBar = false,
    this.onClose,
    this.onRelatedDataChanged,
  });

  final ProfileModel? initial;
  final VoidCallback onSaved;

  /// Si es true, muestra una barra superior con botón cerrar (edición empujada).
  final bool showCloseBar;
  final VoidCallback? onClose;

  /// Tras subir documentos KYC u otra acción que requiera refrescar el perfil.
  final VoidCallback? onRelatedDataChanged;

  @override
  State<ProfileB2BForm> createState() => _ProfileB2BFormState();
}

class _ProfileB2BFormState extends State<ProfileB2BForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessNameController;
  late final TextEditingController _rifController;
  late final TextEditingController _phoneController;
  late final TextEditingController _estadoController;
  late final TextEditingController _ciudadController;
  late final TextEditingController _fiscalAddressController;
  late final TextEditingController _fiscalMapsUrlController;
  late final TextEditingController _emailDisplayController;
  String _role = 'importador';
  bool _saving = false;
  bool _logoBusy = false;
  double? _openExposure;
  /// Corte con el servidor (mismo request que [saldo activo]); ver [_loadOpenExposure].
  double? _imputadoServidor;
  bool _loadingExposure = false;

  /// Recrea [AuthorizationStatusSection] al actualizar documentos KYC.
  int _authSectionTick = 0;

  /// Ancla scroll desde notificaciones KYC → sección documentación aliado.
  final GlobalKey _kycDocumentationSectionKey = GlobalKey();

  /// Rol ya persistido: el selector no puede cambiarse (RLS / negocio).
  bool get _roleLocked {
    final r = widget.initial?.role?.trim();
    return r != null && r.isNotEmpty;
  }

  /// Solo cuentas ya registradas como broker en BD; el autoregistro no ofrece este rol.
  bool get _showAdministradorRoleOption {
    return widget.initial?.role?.trim().toLowerCase() == 'administrador';
  }

  bool get _persistedAsAliado {
    return widget.initial?.role?.trim().toLowerCase() == 'aliado';
  }

  bool get _persistedAsImportador {
    return widget.initial?.role?.trim().toLowerCase() == 'importador';
  }

  bool get _persistedAsTransportista {
    return widget.initial?.role?.trim().toLowerCase() == 'transportista';
  }

  /// Estado, ciudad, dirección fiscal y enlace Maps (misma sección que importador/aliado).
  bool get _requiereUbicacionFiscalCompleta {
    final r = _role.trim().toLowerCase();
    return r == 'importador' || r == 'aliado' || r == 'transportista';
  }

  void _bumpAuthorizationSection() {
    setState(() => _authSectionTick++);
  }

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _businessNameController =
        TextEditingController(text: i?.businessName ?? '');
    _rifController = TextEditingController(text: i?.rif ?? '');
    _phoneController = TextEditingController(text: i?.phone ?? '');
    _estadoController = TextEditingController(text: i?.estado ?? '');
    _ciudadController = TextEditingController(text: i?.ciudad ?? '');
    _fiscalAddressController = TextEditingController(text: i?.direccion ?? '');
    _fiscalMapsUrlController =
        TextEditingController(text: i?.fiscalMapsUrl ?? '');
    _emailDisplayController = TextEditingController(
      text: Supabase.instance.client.auth.currentUser?.email ?? '',
    );
    final r = i?.role?.trim().toLowerCase();
    if (r == 'importador' ||
        r == 'aliado' ||
        r == 'administrador' ||
        r == 'transportista') {
      _role = r!;
    }
    if (_persistedAsAliado) {
      _loadOpenExposure();
      MainShellTabController.registerKycDocumentationSectionKey(
        _kycDocumentationSectionKey,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ProfileB2BForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_persistedAsAliado) return;
    if (oldWidget.initial?.id != widget.initial?.id ||
        oldWidget.initial?.creditoConsumidoAcumulado !=
            widget.initial?.creditoConsumidoAcumulado ||
        oldWidget.initial?.creditLimit != widget.initial?.creditLimit ||
        oldWidget.initial?.creditoPreactivadoPorAdmin !=
            widget.initial?.creditoPreactivadoPorAdmin) {
      _loadOpenExposure();
    }
  }

  void _scrollToKycDocumentation() {
    final target = _kycDocumentationSectionKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  void _onSolicitarCreditoContinuar() {
    final p = widget.initial;
    if (p == null) return;
    final rifOk = p.rif?.trim().isNotEmpty ?? false;
    if (!rifOk || !p.hasRegisteredLocation || !p.hasFiscalMapsShareLink) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Indique RIF, domicilio fiscal (estado, ciudad y dirección) y enlace de Google Maps '
            'en este formulario antes de cargar la documentación.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _scrollToKycDocumentation();
  }

  void _openSolicitarCreditoSheet() {
    final p = widget.initial;
    if (p == null) return;
    AliadoSolicitarCreditoSheet.show(
      context,
      profile: p,
      onContinuar: _onSolicitarCreditoContinuar,
    );
  }

  Future<void> _loadOpenExposure() async {
    setState(() => _loadingExposure = true);
    try {
      final s = await SupabaseService.fetchAliadoMotoLinkCupoSnapshot();
      if (s != null) {
        if (!mounted) return;
        setState(() {
          _openExposure = s.saldoActivoExposicion;
          _imputadoServidor = s.imputadoAcumulado;
          _loadingExposure = false;
        });
        return;
      }
      final v = await SupabaseService.fetchOpenCreditExposureForCurrentAliado();
      if (!mounted) return;
      setState(() {
        _imputadoServidor = null;
        _openExposure = v;
        _loadingExposure = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _imputadoServidor = null;
        _openExposure = null;
        _loadingExposure = false;
      });
    }
  }

  @override
  void dispose() {
    if (_persistedAsAliado) {
      MainShellTabController.registerKycDocumentationSectionKey(null);
    }
    _businessNameController.dispose();
    _rifController.dispose();
    _phoneController.dispose();
    _estadoController.dispose();
    _ciudadController.dispose();
    _fiscalAddressController.dispose();
    _fiscalMapsUrlController.dispose();
    _emailDisplayController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileLogo() async {
    setState(() => _logoBusy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.single;
      final bytes = f.bytes;
      if (bytes == null || bytes.isEmpty) return;
      final name = f.name.toLowerCase();
      String ext = 'png';
      if (name.endsWith('.jpg') || name.endsWith('.jpeg')) ext = 'jpg';
      if (name.endsWith('.webp')) ext = 'webp';
      await SupabaseService.uploadMyProfileLogo(
        bytes: bytes,
        fileExtension: ext,
      );
      if (!mounted) return;
      widget.onSaved();
      widget.onRelatedDataChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo actualizado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo subir el logo: $e')),
      );
    } finally {
      if (mounted) setState(() => _logoBusy = false);
    }
  }

  Future<void> _clearProfileLogo() async {
    setState(() => _logoBusy = true);
    try {
      await SupabaseService.clearMyProfileLogo();
      if (!mounted) return;
      widget.onSaved();
      widget.onRelatedDataChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _logoBusy = false);
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.fieldFill,
      border: OutlineInputBorder(
        borderRadius: AppDecorations.radius12,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppDecorations.radius12,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppDecorations.radius12,
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _aliadoCreditSummary() {
    final limMostrado = widget.initial?.limiteCreditoMostradoAliado;
    final limRaw = widget.initial?.creditLimit;
    final exp = _openExposure ?? 0.0;
    final cons = _imputadoServidor ?? widget.initial?.creditoConsumidoAcumulado ?? 0.0;
    final disponible =
        ((limMostrado ?? 0) - exp - cons).clamp(0.0, double.infinity);
    final pce = widget.initial?.primerosPedidosContadoEntregados ?? 0;
    final enFaseContado = pce < CashPhasePolicy.entregasRequeridas;
    final preact =
        widget.initial?.puedeUsarLineaCreditoMotoLinkPreactivada ?? false;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (enFaseContado) ...[
              Text(
                'Primeros pedidos (contado): $pce de '
                '${CashPhasePolicy.entregasRequeridas} entregas registradas. '
                'Mientras tanto, solo un pedido activo a la vez.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (preact) ...[
                const SizedBox(height: 8),
                const Text(
                  'MotoLink le habilitó el cupo desde el inicio: puede usar la línea de crédito '
                  'en pedidos y pagos aun en esta fase.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.brandBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
            Text(
              limRaw == null && !enFaseContado
                  ? 'Sin cupo asignado: puede solicitar pedidos pagando al contado (transferencia o efectivo). '
                      'MotoLink puede asignar límite cuando lo solicite (pestaña Crédito).'
                  : enFaseContado && !preact
                      ? 'Límite mostrado (fase contado): ${(limMostrado ?? 0).toStringAsFixed(2)} REF'
                      : 'Límite autorizado: ${(limMostrado ?? 0).toStringAsFixed(2)} REF',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (limRaw != null || enFaseContado || preact) ...[
              const SizedBox(height: 10),
              if (_loadingExposure)
                const LinearProgressIndicator(minHeight: 3)
              else ...[
                Text(
                  'Compromiso (saldo activo vía cupo / plan): ${exp.toStringAsFixed(2)} REF',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Imputado acumulado (lo ya “cerrado” y descontado en disponible): '
                  '${cons.toStringAsFixed(2)} REF (entregas a crédito sin plan, o al aprobar la última cuota de un plan).',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Disponible estimado: ${disponible.toStringAsFixed(2)} REF',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fórmula: límite mostrado − saldo activo (compromiso) − imputado acumulado. '
                  'El saldo activo baja con cada cuota; el imputado sube una sola vez al completar el plan.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _fiscalMapsSectionTitle() {
    switch (_role.trim().toLowerCase()) {
      case 'importador':
        return 'ENLACE GOOGLE MAPS · ALMACÉN / DOMICILIO FISCAL';
      case 'aliado':
        return 'ENLACE GOOGLE MAPS · TALLER / DOMICILIO FISCAL';
      case 'transportista':
        return 'ENLACE GOOGLE MAPS · BASE OPERATIVA / DOMICILIO FISCAL';
      default:
        return 'ENLACE GOOGLE MAPS (OPCIONAL)';
    }
  }

  String _fiscalMapsSectionDescription() {
    switch (_role.trim().toLowerCase()) {
      case 'importador':
        return 'Pegue el enlace «Compartir» de Google Maps apuntando a su almacén o domicilio fiscal. '
            'MotoLink lo usa como origen al armar la ruta en vivo hacia el taller del aliado cuando el pedido '
            'está en tránsito (junto con el enlace del aliado en su perfil).';
      case 'aliado':
        return 'Pegue el enlace «Compartir» de Google Maps apuntando a su taller o domicilio fiscal. '
            'MotoLink lo usa como destino al armar la ruta en vivo desde el importador cuando el pedido '
            'está en tránsito (junto con el enlace del importador en su perfil).';
      case 'transportista':
        return 'Pegue el enlace «Compartir» de Google Maps apuntando a su base operativa o domicilio fiscal. '
            'Debe coincidir con la dirección indicada arriba: MotoLink usa esas coordenadas para asignación '
            'por proximidad y las rutas en tránsito.';
      default:
        return 'Pegue un enlace público (compartir ubicación) para que MotoLink y los participantes '
            'abran su domicilio fiscal en el mapa.';
    }
  }

  String _ubicacionFiscalIntroText() {
    switch (_role.trim().toLowerCase()) {
      case 'transportista':
        return 'Indique la ubicación de su base operativa o casa matriz. Estado, ciudad y domicilio '
            'son obligatorios; al guardar, MotoLink geocodifica la dirección para registrar coordenadas '
            'en su perfil y en su expediente de transportista (proximidad a almacenes).';
      case 'importador':
      case 'aliado':
        return 'Visible en el catálogo para ubicar proveedores y talleres. '
            'Complete también la dirección fiscal más abajo: estado, ciudad y domicilio '
            'son obligatorios para solicitar pedidos.';
      default:
        return '';
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await SupabaseService.upsertMyProfile(
        businessName: _businessNameController.text,
        rif: _rifController.text,
        role: _role,
        phone: _phoneController.text,
        estado: _estadoController.text,
        ciudad: _ciudadController.text,
        direccion: _fiscalAddressController.text,
        fiscalMapsUrl: _fiscalMapsUrlController.text,
      );
      await _tryGeocodeAndSaveCoordinates();
      if (!mounted) return;
      widget.onSaved();
    } catch (e, st) {
      debugPrint('upsertMyProfile error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el perfil: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
  }

  /// Geocodifica el domicilio fiscal (importador/aliado: catálogo; transportista: perfil + transportista_info).
  Future<void> _tryGeocodeAndSaveCoordinates() async {
    final role = _role.trim().toLowerCase();
    if (role != 'importador' &&
        role != 'aliado' &&
        role != 'transportista') {
      return;
    }
    final dir = _fiscalAddressController.text.trim();
    final ci = _ciudadController.text.trim();
    final es = _estadoController.text.trim();
    if (dir.isEmpty || ci.isEmpty || es.isEmpty) return;
    try {
      final loc = await locationFromAddress('$dir, $ci, $es, Venezuela');
      if (loc.isEmpty) return;
      final first = loc.first;
      await SupabaseService.updateMyGeolocation(
        latitude: first.latitude,
        longitude: first.longitude,
      );
      if (role == 'transportista') {
        await SupabaseService.syncTransportistaInfoBaseFromProfileCoordinates(
          latitude: first.latitude,
          longitude: first.longitude,
          rifAlignedWithProfile: _rifController.text,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailDisplayController.text.trim().isEmpty
        ? '—'
        : _emailDisplayController.text.trim();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showCloseBar) ...[
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  color: AppColors.textPrimary,
                ),
                const Expanded(
                  child: Text(
                    'Mi Perfil B2B',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: AppDecorations.radius12,
                  child: Container(
                    width: 88,
                    height: 88,
                    color: AppColors.brand.withOpacity(0.08),
                    child: _ProfileLogoBox(
                      storagePath: widget.initial?.logoStoragePath,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: (_saving || _logoBusy) ? null : _pickProfileLogo,
                      icon: _logoBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_outlined, size: 18),
                      label: Text(
                        widget.initial?.logoStoragePath != null &&
                                widget.initial!.logoStoragePath!.trim().isNotEmpty
                            ? 'Cambiar logo'
                            : 'Subir logo (opcional)',
                      ),
                    ),
                    if (widget.initial?.logoStoragePath != null &&
                        widget.initial!.logoStoragePath!.trim().isNotEmpty)
                      TextButton(
                        onPressed: (_saving || _logoBusy) ? null : _clearProfileLogo,
                        child: Text(
                          'Quitar',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                  ],
                ),
                Text(
                  'Si no sube imagen, se muestra el logo MotoLink en la barra superior.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Mi Perfil B2B',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _sectionLabel('TIPO DE CUENTA'),
          if (_persistedAsTransportista)
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.local_shipping_outlined,
                    size: 18, color: AppColors.brandBlue),
                label: const Text('Transportista · despacho'),
                backgroundColor: AppColors.fieldFill,
                side: BorderSide(color: Colors.grey.shade300),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _RoleChoiceTile(
                    label: 'Importador',
                    icon: Icons.local_shipping_outlined,
                    selected: _role == 'importador',
                    enabled: !_roleLocked,
                    onTap: _saving || _roleLocked
                        ? null
                        : () => setState(() => _role = 'importador'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RoleChoiceTile(
                    label: 'Aliado',
                    icon: Icons.person_outline,
                    selected: _role == 'aliado',
                    enabled: !_roleLocked,
                    onTap: _saving || _roleLocked
                        ? null
                        : () => setState(() => _role = 'aliado'),
                  ),
                ),
              ],
            ),
            if (_showAdministradorRoleOption) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: _RoleChoiceTile(
                  label: 'Administrador (broker)',
                  icon: Icons.admin_panel_settings_outlined,
                  selected: _role == 'administrador',
                  enabled: !_roleLocked,
                  onTap: _saving || _roleLocked
                      ? null
                      : () => setState(() => _role = 'administrador'),
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          _sectionLabel('NOMBRE DEL NEGOCIO'),
          TextFormField(
            controller: _businessNameController,
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDecoration('Ej: Repuestos La Victoria C.A.'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _sectionLabel('RIF'),
          TextFormField(
            controller: _rifController,
            decoration: _fieldDecoration('J-12345678-9'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _sectionLabel('CORREO ELECTRÓNICO'),
          TextFormField(
            controller: _emailDisplayController,
            readOnly: true,
            decoration: _fieldDecoration(''),
          ),
          const SizedBox(height: 16),
          _sectionLabel('TELÉFONO'),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: _fieldDecoration('+58 412 1234567'),
          ),
          if (_requiereUbicacionFiscalCompleta) ...[
            const SizedBox(height: 16),
            _sectionLabel('UBICACIÓN (ESTADO / CIUDAD)'),
            Text(
              _ubicacionFiscalIntroText(),
              style: TextStyle(fontSize: 12, height: 1.35, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _estadoController,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration('Estado (ej: Miranda)'),
              validator: (v) {
                if (!_requiereUbicacionFiscalCompleta) return null;
                if (v == null || v.trim().isEmpty) return 'Indique el estado';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ciudadController,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration('Ciudad (ej: Los Teques)'),
              validator: (v) {
                if (!_requiereUbicacionFiscalCompleta) return null;
                if (v == null || v.trim().isEmpty) return 'Indique la ciudad';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _sectionLabel('DIRECCIÓN FISCAL'),
            TextFormField(
              controller: _fiscalAddressController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: _fieldDecoration(
                'Av. Principal, Local 12, Zona Industrial...',
              ),
              validator: (v) {
                if (!_requiereUbicacionFiscalCompleta) return null;
                if (v == null || v.trim().isEmpty) {
                  return 'Indique la dirección fiscal (domicilio de la empresa)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _sectionLabel(_fiscalMapsSectionTitle()),
            Text(
              _fiscalMapsSectionDescription(),
              style: TextStyle(fontSize: 12, height: 1.35, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fiscalMapsUrlController,
              keyboardType: TextInputType.url,
              decoration: _fieldDecoration('https://maps.app.goo.gl/... o maps.google.com/...'),
              validator: (v) {
                if (!_requiereUbicacionFiscalCompleta) return null;
                final t = v?.trim() ?? '';
                if (t.isEmpty) {
                  return 'Indique el enlace «Compartir» de Google Maps de su domicilio fiscal';
                }
                final u = Uri.tryParse(t);
                if (u == null ||
                    !u.hasScheme ||
                    (u.scheme != 'http' && u.scheme != 'https')) {
                  return 'Use una URL que empiece por http(s)://';
                }
                return null;
              },
            ),
          ],
          if (!_requiereUbicacionFiscalCompleta) ...[
            const SizedBox(height: 16),
            _sectionLabel('DIRECCIÓN FISCAL'),
            TextFormField(
              controller: _fiscalAddressController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: _fieldDecoration(
                'Av. Principal, Local 12, Zona Industrial...',
              ),
            ),
          ],
          if (_roleLocked && (_persistedAsAliado || _persistedAsImportador)) ...[
            const SizedBox(height: 20),
            AuthorizationStatusSection(
              key: ValueKey<int>(_authSectionTick),
              profile: widget.initial,
            ),
          ],
          if (_persistedAsAliado) ...[
            const SizedBox(height: 20),
            _sectionLabel('CUPO AUTORIZADO (MOTOLINK)'),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: widget.initial == null ? null : _openSolicitarCreditoSheet,
                icon: const Icon(Icons.credit_score_outlined, size: 22),
                label: const Text(
                  'Solicitar crédito MotoLink',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Revise requisitos, su progreso en la fase inicial y la documentación requerida.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            _aliadoCreditSummary(),
            const SizedBox(height: 20),
            KeyedSubtree(
              key: _kycDocumentationSectionKey,
              child: AliadoKycDocumentsSection(
                kycStatus: widget.initial?.kycStatus,
                esAliadoEnFaseContado:
                    widget.initial?.esAliadoEnFaseContado ?? false,
                primerosPedidosContadoEntregados:
                    widget.initial?.primerosPedidosContadoEntregados,
                onChanged: () {
                  _bumpAuthorizationSection();
                  widget.onRelatedDataChanged?.call();
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
          const ProfileKycDocumentsInfo(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Guardar Perfil'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _saving ? null : _signOut,
            icon: Icon(Icons.logout, color: Colors.grey.shade600, size: 20),
            label: Text(
              'Cerrar Sesión',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLogoBox extends StatelessWidget {
  const _ProfileLogoBox({this.storagePath});

  final String? storagePath;

  @override
  Widget build(BuildContext context) {
    final p = storagePath?.trim();
    if (p == null || p.isEmpty) {
      return Center(
        child: MotoLinkProLogo(height: 48),
      );
    }
    return FutureBuilder<String>(
      future: SupabaseService.createSignedUrlForProfileLogo(p),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final url = snap.data;
        if (url == null || snap.hasError) {
          return const Center(
            child: Icon(Icons.business_outlined, size: 40, color: AppColors.brand),
          );
        }
        return Image.network(
          url,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: MotoLinkProLogo(height: 48),
          ),
        );
      },
    );
  }
}

class _RoleChoiceTile extends StatelessWidget {
  const _RoleChoiceTile({
    required this.label,
    required this.icon,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.brand.withOpacity(0.08) : Colors.white,
        borderRadius: AppDecorations.radius12,
        border: Border.all(
          color: selected ? AppColors.brand : Colors.grey.shade300,
          width: selected ? 2.5 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: selected ? AppColors.brand : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: selected ? AppColors.brand : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppDecorations.radius12,
          child: content,
        ),
      ),
    );
  }
}
