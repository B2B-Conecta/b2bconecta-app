import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_access_status.dart';
import '../models/kyc_status.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../utils/document_pick_utils.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'motolink_pro_logo.dart';
import 'main_shell_tab.dart';
import 'profile_kyc_documents_section.dart';
import 'importer_accepted_pago_metodos_section.dart';
import 'importer_commission_settlements_section.dart';
import 'authorization_status_section.dart';
import 'media_pick_action_chips.dart';
import 'profile_section_helpers.dart';
import 'terms_acceptance_section.dart';

/// Formulario perfil B2B (referencia: Mi Perfil B2B). Dirección fiscal → `profiles.direccion`.
class ProfileB2BForm extends StatefulWidget {
  const ProfileB2BForm({
    super.key,
    required this.initial,
    required this.onSaved,
    this.showCloseBar = false,
    this.onClose,
    this.onRelatedDataChanged,
    this.onTermsAccepted,
    this.afterReputation,
    this.beforeSignOut,
    this.onEnterApp,
  });

  final ProfileModel? initial;
  final VoidCallback onSaved;

  /// Si es true, muestra una barra superior con botón cerrar (edición empujada).
  final bool showCloseBar;
  final VoidCallback? onClose;

  /// Tras subir documentos KYC u otra acción que requiera refrescar el perfil.
  final VoidCallback? onRelatedDataChanged;

  /// Tras registrar aceptación legal en BD (sin refrescar todo el formulario).
  final VoidCallback? onTermsAccepted;

  /// Contenido opcional justo después de «Ver reputación» (importador).
  final Widget? afterReputation;

  /// Contenido opcional justo encima del botón «Cerrar sesión» (aliado).
  final Widget? beforeSignOut;

  /// Cuando el perfil ya puede entrar al panel (cuenta aprobada / activa).
  final VoidCallback? onEnterApp;

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

  /// Recrea [AuthorizationStatusSection] al actualizar documentos KYC.
  int _authSectionTick = 0;

  bool _termsAccepted = false;

  /// Ancla scroll desde notificaciones KYC → sección documentación aliado.
  final GlobalKey _kycDocumentationSectionKey = GlobalKey();

  /// Rol ya persistido: el selector no puede cambiarse (RLS / negocio).
  bool get _roleLocked {
    final r = widget.initial?.role?.trim();
    return r != null && r.isNotEmpty;
  }

  /// Onboarding inicial: ocultar secciones del panel principal (p. ej. reputación).
  bool get _isOnboarding => widget.onEnterApp != null;

  /// Solo cuentas ya registradas como broker en BD; el autoregistro no ofrece este rol.
  bool get _showAdministradorRoleOption {
    return widget.initial?.role?.trim().toLowerCase() == 'administrador';
  }

  bool get _persistedAsAliado {
    return widget.initial?.role?.trim().toLowerCase() == 'aliado';
  }

  bool get _showAliadoKycSection =>
      _role.trim().toLowerCase() == 'aliado' || _persistedAsAliado;

  /// Aliados usan «Enviar registro inicial»; no muestran «Guardar Perfil».
  bool get _showGuardarPerfilButton => !_showAliadoKycSection;

  bool get _aliadoRegistrationLocked {
    if (!_showAliadoKycSection) return false;
    final kyc = widget.initial?.kycStatus?.trim().toLowerCase();
    final access = widget.initial?.accountAccessStatus?.trim().toLowerCase();
    return kyc == KycStatus.enRevision ||
        kyc == KycStatus.aprobado ||
        access == AccountAccessStatus.pendingReview ||
        access == AccountAccessStatus.active;
  }

  bool get _persistedAsImportador {
    return widget.initial?.role?.trim().toLowerCase() == 'importador';
  }

  bool get _requiresTerms {
    final r = _role.trim().toLowerCase();
    return r == 'importador' || r == 'aliado';
  }

  bool get _hasAcceptedTerms => _termsAccepted;

  /// Solo durante el primer registro; oculto si ya aceptó términos vigentes.
  bool get _showTermsSection =>
      _requiresTerms &&
      !_showAliadoKycSection &&
      !(widget.initial?.hasAcceptedCurrentTerms ?? false);

  /// Estado, ciudad, dirección fiscal y enlace Maps (misma sección que importador/aliado).
  bool get _requiereUbicacionFiscalCompleta {
    final r = _role.trim().toLowerCase();
    return r == 'importador' || r == 'aliado';
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
    if (r == 'importador' || r == 'aliado' || r == 'administrador') {
      _role = r!;
    }
    _termsAccepted = widget.initial?.hasAcceptedCurrentTerms ?? false;
    if (_persistedAsAliado) {
      MainShellTabController.registerKycDocumentationSectionKey(
        _kycDocumentationSectionKey,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ProfileB2BForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial?.termsAcceptedAt !=
            widget.initial?.termsAcceptedAt ||
        oldWidget.initial?.termsVersion != widget.initial?.termsVersion) {
      if (widget.initial?.hasAcceptedCurrentTerms == true) {
        _termsAccepted = true;
      }
    }
    if (oldWidget.initial?.id != widget.initial?.id ||
        oldWidget.initial?.kycStatus != widget.initial?.kycStatus ||
        oldWidget.initial?.accountAccessStatus !=
            widget.initial?.accountAccessStatus) {
      _bumpAuthorizationSection();
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

  Future<void> _pickProfileLogo({
    DocumentPickChannel? channel,
  }) async {
    setState(() => _logoBusy = true);
    try {
      final picked = channel == null
          ? await pickProfileImageBytes(context)
          : await pickKycDocument(channel: channel).then((doc) {
              if (doc == null) return null;
              final n = doc.fileName.toLowerCase();
              if (n.endsWith('.pdf')) {
                throw ArgumentError('El logo debe ser una imagen (JPG, PNG, WEBP).');
              }
              return doc;
            });
      if (picked == null) return;
      final name = picked.fileName.toLowerCase();
      String ext = 'png';
      if (name.endsWith('.jpg') || name.endsWith('.jpeg')) ext = 'jpg';
      if (name.endsWith('.webp')) ext = 'webp';
      await SupabaseService.uploadMyProfileLogo(
        bytes: picked.bytes,
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

  InputDecoration _fieldDecoration(
    String hint, {
    String? label,
    bool readOnly = false,
  }) {
    final radius = BorderRadius.circular(10);
    final side = BorderSide(color: AppColors.borderSubtle);
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior:
          label == null ? FloatingLabelBehavior.never : FloatingLabelBehavior.auto,
      hintText: hint.isEmpty ? null : hint,
      hintStyle: AppColors.hintStyle.copyWith(fontSize: 14),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      floatingLabelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.brandAccent,
      ),
      filled: true,
      fillColor: readOnly
          ? AppColors.surfaceTinted
          : AppColors.fieldFill,
      border: OutlineInputBorder(borderRadius: radius, borderSide: side),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: side),
      disabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: side),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.brandAccent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  String? _ubicacionFiscalHelp() {
    switch (_role.trim().toLowerCase()) {
      case 'aliado':
        return 'Estado, ciudad y domicilio fiscal son obligatorios para solicitar pedidos.';
      case 'importador':
        return 'Estado y ciudad aparecen en el catálogo. La dirección fiscal y el enlace Maps son obligatorios para operar.';
      default:
        return null;
    }
  }

  String? _fiscalMapsHelp() {
    switch (_role.trim().toLowerCase()) {
      case 'importador':
        return 'Enlace «Compartir» de Google Maps de su almacén o domicilio fiscal. '
            'Ubica su negocio en el catálogo y permite abrir la dirección desde la app.';
      case 'aliado':
        return 'Enlace «Compartir» de Google Maps de su taller. '
            'Es obligatorio junto con RIF y dirección fiscal.';
      default:
        return 'Enlace público para abrir su domicilio fiscal en el mapa.';
    }
  }

  String _ubicacionSectionSubtitle() {
    final es = _estadoController.text.trim();
    final ci = _ciudadController.text.trim();
    if (es.isEmpty && ci.isEmpty) return 'Toque para completar ubicación';
    if (es.isNotEmpty && ci.isNotEmpty) return '$es · $ci';
    return es.isNotEmpty ? es : ci;
  }

  Widget _reputationTabHint(BuildContext context) {
    return Material(
      color: AppColors.brandBlueContainer.withOpacity(0.35),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => MainShellTabController.navigateToReputationTab(),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.star_outline, color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ver reputación',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const ProfileInfoIcon(
                message:
                    'Valoraciones recibidas, cierres semanales y comentarios están en la pestaña Reputación.',
                title: 'Reputación',
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiresTerms &&
        !_hasAcceptedTerms &&
        _role.trim().toLowerCase() != 'aliado') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debe aceptar los términos y la política de privacidad para continuar.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final mapsUrl = SupabaseService.normalizeHttpUrl(
        _fiscalMapsUrlController.text,
      );
      if (mapsUrl != null &&
          mapsUrl != _fiscalMapsUrlController.text.trim()) {
        _fiscalMapsUrlController.text = mapsUrl;
      }
      await SupabaseService.upsertMyProfile(
        businessName: _businessNameController.text,
        rif: _rifController.text,
        role: _role,
        phone: _phoneController.text,
        estado: _estadoController.text,
        ciudad: _ciudadController.text,
        direccion: _fiscalAddressController.text,
        fiscalMapsUrl: mapsUrl ?? _fiscalMapsUrlController.text,
      );
      await _tryGeocodeAndSaveCoordinates();
      if (!mounted) return;
      widget.onSaved();
    } catch (e, st) {
      debugPrint('upsertMyProfile error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SupabaseService.profileSaveErrorMessage(e)),
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

  Future<bool> _persistProfileFromForm({bool validate = true}) async {
    if (validate && !_formKey.currentState!.validate()) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revise los campos del perfil antes de continuar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    try {
      final mapsUrl = SupabaseService.normalizeHttpUrl(
        _fiscalMapsUrlController.text,
      );
      if (mapsUrl != null &&
          mapsUrl != _fiscalMapsUrlController.text.trim()) {
        _fiscalMapsUrlController.text = mapsUrl;
      }
      await SupabaseService.upsertMyProfile(
        businessName: _businessNameController.text,
        rif: _rifController.text,
        role: _role,
        phone: _phoneController.text,
        estado: _estadoController.text,
        ciudad: _ciudadController.text,
        direccion: _fiscalAddressController.text,
        fiscalMapsUrl: mapsUrl ?? _fiscalMapsUrlController.text,
      );
      await _tryGeocodeAndSaveCoordinates();
      if (!mounted) return false;
      widget.onRelatedDataChanged?.call();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SupabaseService.profileSaveErrorMessage(e))),
      );
      return false;
    }
  }

  /// Crea/actualiza borrador mínimo para poder subir documentos KYC en onboarding.
  Future<bool> _ensureProfileForDocumentUpload() async {
    final persisted = await SupabaseService.fetchMyProfile();
    final persistedRole = persisted?.role?.trim().toLowerCase();
    final hasPersistedRole = persistedRole == 'importador' ||
        persistedRole == 'aliado' ||
        persistedRole == 'administrador';
    if (persisted != null && hasPersistedRole) {
      return true;
    }
    final businessName = _businessNameController.text.trim();
    final rif = _rifController.text.trim();
    if (businessName.isEmpty || rif.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Indique nombre del negocio y RIF antes de adjuntar documentos.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    if (_role.trim().toLowerCase() != 'aliado') return false;
    return _persistProfileFromForm(validate: false);
  }

  /// Geocodifica el domicilio fiscal del importador o aliado (catálogo / proximidad).
  Future<void> _tryGeocodeAndSaveCoordinates() async {
    final role = _role.trim().toLowerCase();
    if (role != 'importador' && role != 'aliado') {
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailDisplayController.text.trim().isEmpty
        ? '—'
        : _emailDisplayController.text.trim();

    final businessName = _businessNameController.text.trim();
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 600;
    final wide = width >= 560;

    return Form(
      key: _formKey,
      child: Padding(
        padding: EdgeInsets.fromLTRB(mobile ? 0 : 4, mobile ? 0 : 4, mobile ? 0 : 4, 24),
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
                  Expanded(
                    child: Text(
                      mobile ? 'Perfil' : 'Mi Perfil B2B',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 8),
            ],
            _ProfileIdentityCard(
              compact: mobile,
              businessName: businessName.isEmpty
                  ? (mobile ? 'Tu negocio' : 'Mi Perfil B2B')
                  : businessName,
              email: email,
              logo: _ProfileLogoBox(
                storagePath: widget.initial?.logoStoragePath,
                size: mobile ? 72 : 84,
              ),
              actions: MediaPickActionChips(
                iconOnly: true,
                busy: _logoBusy,
                enabled: !_saving,
                fileLabel: 'Archivo',
                onCamera: () => _pickProfileLogo(
                  channel: DocumentPickChannel.camera,
                ),
                onGallery: () => _pickProfileLogo(
                  channel: DocumentPickChannel.gallery,
                ),
                onFile: () => _pickProfileLogo(
                  channel: DocumentPickChannel.file,
                ),
                onDelete: (widget.initial?.logoStoragePath != null &&
                        widget.initial!.logoStoragePath!.trim().isNotEmpty)
                    ? _clearProfileLogo
                    : null,
              ),
            ),
            if (widget.onEnterApp != null &&
                (widget.initial?.isReadyForMainApp ?? false)) ...[
              const SizedBox(height: 16),
              _EnterAppBanner(onPressed: widget.onEnterApp!),
            ],
            SizedBox(height: mobile ? 12 : 16),
            ProfileCollapsibleSection(
              title: mobile ? 'Negocio' : 'Datos del negocio',
              subtitle: mobile
                  ? null
                  : (businessName.isEmpty
                      ? 'Tipo de cuenta, RIF y contacto'
                      : businessName),
              initiallyExpanded: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!mobile) ...[
                    Text(
                      'Tipo de cuenta',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _RoleChoiceGrid(
                    compact: mobile,
                    showAdministrador: _showAdministradorRoleOption,
                    role: _role,
                    locked: _roleLocked,
                    saving: _saving,
                    onChanged: (r) => setState(() => _role = r),
                  ),
                  SizedBox(height: mobile ? 14 : 18),
                  TextFormField(
                    controller: _businessNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDecoration(
                      mobile ? 'Nombre comercial' : 'Ej: Repuestos La Victoria C.A.',
                      label: mobile ? 'Negocio' : 'Nombre del negocio',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Campo obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rifController,
                            decoration: _fieldDecoration(
                              'J-12345678-9',
                              label: 'RIF',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Campo obligatorio';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _fieldDecoration(
                              '+58 412…',
                              label: 'Teléfono',
                            ),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    TextFormField(
                      controller: _rifController,
                      decoration: _fieldDecoration(
                        'J-12345678-9',
                        label: 'RIF',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Campo obligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _fieldDecoration(
                        '+58 412…',
                        label: 'Teléfono',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailDisplayController,
                    readOnly: true,
                    decoration: _fieldDecoration(
                      '',
                      label: mobile ? 'Correo' : 'Correo electrónico',
                      readOnly: true,
                    ),
                  ),
                ],
              ),
            ),
            if (_requiereUbicacionFiscalCompleta) ...[
              const SizedBox(height: 12),
              ProfileCollapsibleSection(
                title: mobile ? 'Ubicación' : 'Ubicación y domicilio fiscal',
                subtitle: mobile ? null : _ubicacionSectionSubtitle(),
                initiallyExpanded: !(widget.initial?.isComplete ?? false),
                infoMessage: mobile ? null : _ubicacionFiscalHelp(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _estadoController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _fieldDecoration(
                                'Miranda',
                                label: 'Estado',
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                if (!_requiereUbicacionFiscalCompleta) {
                                  return null;
                                }
                                if (v == null || v.trim().isEmpty) {
                                  return 'Indique el estado';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _ciudadController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _fieldDecoration(
                                'Los Teques',
                                label: 'Ciudad',
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                if (!_requiereUbicacionFiscalCompleta) {
                                  return null;
                                }
                                if (v == null || v.trim().isEmpty) {
                                  return 'Indique la ciudad';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      )
                    else ...[
                      TextFormField(
                        controller: _estadoController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDecoration(
                          'Miranda',
                          label: 'Estado',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (!_requiereUbicacionFiscalCompleta) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Indique el estado';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ciudadController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDecoration(
                          'Los Teques',
                          label: 'Ciudad',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (!_requiereUbicacionFiscalCompleta) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Indique la ciudad';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fiscalAddressController,
                      maxLines: mobile ? 2 : 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _fieldDecoration(
                        mobile ? 'Calle, local…' : 'Av. Principal, Local 12…',
                        label: mobile ? 'Dirección' : 'Dirección fiscal',
                      ),
                      validator: (v) {
                        if (!_requiereUbicacionFiscalCompleta) return null;
                        if (v == null || v.trim().isEmpty) {
                          return mobile
                              ? 'Indique la dirección'
                              : 'Indique la dirección fiscal (domicilio de la empresa)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fiscalMapsUrlController,
                      keyboardType: TextInputType.url,
                      decoration: _fieldDecoration(
                        'maps.app.goo.gl/…',
                        label: mobile ? 'Google Maps' : _fiscalMapsFieldLabel(),
                      ).copyWith(
                        suffixIcon: ProfileInfoIcon(
                          message: _fiscalMapsHelp() ??
                              'Pegue el enlace «Compartir» de Google Maps.',
                          title: 'Google Maps',
                        ),
                      ),
                      validator: (v) {
                        if (!_requiereUbicacionFiscalCompleta) return null;
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) {
                          return mobile
                              ? 'Falta el enlace de Maps'
                              : 'Indique el enlace «Compartir» de Google Maps de su domicilio fiscal';
                        }
                        if (SupabaseService.normalizeHttpUrl(t) == null) {
                          return 'URL de Maps no válida';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
            if (!_requiereUbicacionFiscalCompleta) ...[
              const SizedBox(height: 12),
              ProfileCollapsibleSection(
                title: mobile ? 'Dirección' : 'Dirección fiscal',
                subtitle: mobile ? null : 'Opcional',
                initiallyExpanded: false,
                child: TextFormField(
                  controller: _fiscalAddressController,
                  maxLines: mobile ? 2 : 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldDecoration(
                    mobile ? 'Calle, local…' : 'Av. Principal, Local 12…',
                    label: mobile ? 'Dirección' : 'Dirección fiscal',
                  ),
                ),
              ),
            ],
          if (_roleLocked && _persistedAsImportador) ...[
            const SizedBox(height: 12),
            AuthorizationStatusSection(
              key: ValueKey<int>(_authSectionTick),
              profile: widget.initial,
            ),
          ],
          if (_persistedAsImportador && widget.initial != null) ...[
            const SizedBox(height: 12),
            ImporterAcceptedPagoMetodosSection(
              profile: widget.initial!,
              onSaved: widget.onRelatedDataChanged,
            ),
            if (!_isOnboarding) ...[
              const SizedBox(height: 12),
              const ImporterCommissionSettlementsSection(),
              const SizedBox(height: 8),
              _reputationTabHint(context),
              if (widget.afterReputation != null) ...[
                const SizedBox(height: 12),
                widget.afterReputation!,
              ],
            ],
          ],
          if (_showAliadoKycSection) ...[
            const SizedBox(height: 14),
            if (!mobile)
              const ProfileSectionHeader(
                label: 'VERIFICACIÓN',
                infoTitle: 'Verificación',
                infoMessage: AliadoKycSectionHelp.verificacion,
              )
            else
              ProfileSectionHeader(
                label: 'KYC',
                infoTitle: 'Verificación',
                infoMessage: AliadoKycSectionHelp.verificacion,
              ),
            KeyedSubtree(
              key: _kycDocumentationSectionKey,
              child: ProfileKycDocumentsSection(
                role: 'aliado',
                profile: widget.initial,
                kycStatus: widget.initial?.kycStatus,
                beforeUpload: _ensureProfileForDocumentUpload,
                beforeSubmitReview: _persistProfileFromForm,
                registrationLocked: _aliadoRegistrationLocked,
                onTermsAccepted: widget.onTermsAccepted,
                onChanged: () {
                  _bumpAuthorizationSection();
                  widget.onRelatedDataChanged?.call();
                },
              ),
            ),
          ],
          if (_showTermsSection) ...[
            const SizedBox(height: 14),
            ProfileSectionHeader(
              label: mobile ? 'TÉRMINOS' : 'TÉRMINOS LEGALES',
              infoTitle: 'Términos y privacidad',
              infoMessage: mobile
                  ? 'Debe aceptar términos y privacidad para usar B2B Conecta.'
                  : 'Aliados e importadores deben aceptar los términos y la '
                      'política de privacidad vigentes antes de usar B2B Conecta.',
            ),
            TermsAcceptanceSection(
              accepted: _termsAccepted,
              onAcceptedChanged: (v) {
                setState(() => _termsAccepted = v);
                if (v) widget.onTermsAccepted?.call();
              },
            ),
          ],
          if (_showGuardarPerfilButton) ...[
            SizedBox(height: mobile ? 18 : 24),
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
                  : Text(mobile ? 'Guardar' : 'Guardar Perfil'),
            ),
          ] else
            const SizedBox(height: 16),
          if (widget.beforeSignOut != null) ...[
            const SizedBox(height: 12),
            widget.beforeSignOut!,
          ],
          const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _saving ? null : _signOut,
              icon: Icon(Icons.logout, color: AppColors.textSecondary, size: 20),
              label: Text(
                mobile ? 'Salir' : 'Cerrar Sesión',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fiscalMapsFieldLabel() {
    switch (_role.trim().toLowerCase()) {
      case 'importador':
        return 'Google Maps · almacén / domicilio';
      case 'aliado':
        return 'Google Maps · taller / domicilio';
      default:
        return 'Google Maps (opcional)';
    }
  }
}

class _ProfileLogoBox extends StatelessWidget {
  const _ProfileLogoBox({this.storagePath, this.size = 84});

  final String? storagePath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = storagePath?.trim();
    if (p == null || p.isEmpty) {
      return BusinessLogoPlaceholder(size: size);
    }
    final radius = BorderRadius.circular(size * 0.16);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<String>(
          future: SupabaseService.createSignedUrlForProfileLogo(p),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return ColoredBox(
                color: AppColors.brandBlueContainer,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ThemeController.instance.isDark
                          ? AppColors.brandAccent
                          : AppColors.brandBlue,
                    ),
                  ),
                ),
              );
            }
            final url = snap.data;
            if (url == null || snap.hasError) {
              return BusinessLogoPlaceholder(size: size);
            }
            return Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => BusinessLogoPlaceholder(size: size),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({
    required this.businessName,
    required this.email,
    required this.logo,
    required this.actions,
    this.compact = false,
  });

  final String businessName;
  final String email;
  final Widget logo;
  final Widget actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              children: [
                logo,
                const SizedBox(height: 10),
                actions,
                const SizedBox(height: 12),
                Text(
                  businessName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  logo,
                  const SizedBox(height: 10),
                  actions,
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      businessName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleChoiceGrid extends StatelessWidget {
  const _RoleChoiceGrid({
    required this.role,
    required this.locked,
    required this.saving,
    required this.onChanged,
    required this.showAdministrador,
    this.compact = false,
  });

  final String role;
  final bool locked;
  final bool saving;
  final ValueChanged<String> onChanged;
  final bool showAdministrador;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Widget tile({
      required String value,
      required String label,
      required IconData icon,
    }) {
      return _RoleChoiceTile(
        label: label,
        icon: icon,
        selected: role == value,
        enabled: !locked,
        compact: compact,
        onTap: saving || locked ? null : () => onChanged(value),
      );
    }

    final importador = tile(
      value: 'importador',
      label: 'Importador',
      icon: Icons.local_shipping_outlined,
    );
    final aliado = tile(
      value: 'aliado',
      label: 'Aliado',
      icon: Icons.person_outline,
    );
    final admin = tile(
      value: 'administrador',
      label: compact ? 'Admin' : 'Administrador (broker)',
      icon: Icons.admin_panel_settings_outlined,
    );

    if (!showAdministrador) {
      return Row(
        children: [
          Expanded(child: importador),
          SizedBox(width: compact ? 8 : 10),
          Expanded(child: aliado),
        ],
      );
    }

    if (compact) {
      return Row(
        children: [
          Expanded(child: importador),
          const SizedBox(width: 8),
          Expanded(child: aliado),
          const SizedBox(width: 8),
          Expanded(child: admin),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: importador),
            const SizedBox(width: 10),
            Expanded(child: aliado),
          ],
        ),
        const SizedBox(height: 10),
        admin,
      ],
    );
  }
}

class _RoleChoiceTile extends StatelessWidget {
  const _RoleChoiceTile({
    required this.label,
    required this.icon,
    required this.selected,
    this.enabled = true,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? AppColors.brandAccent : AppColors.textSecondary;
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        vertical: compact ? 10 : 12,
        horizontal: compact ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.brandBlueContainer : AppColors.fieldFill,
        borderRadius: BorderRadius.circular(compact ? 12 : 10),
        border: Border.all(
          color: selected ? AppColors.brandAccent : AppColors.borderSubtle,
          width: selected ? 1.8 : 1,
        ),
      ),
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: accent),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      height: 1.2,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
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
          borderRadius: BorderRadius.circular(compact ? 12 : 10),
          child: content,
        ),
      ),
    );
  }
}

class _EnterAppBanner extends StatelessWidget {
  const _EnterAppBanner({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withOpacity(0.12),
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: AppColors.successGreen.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.successGreen, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Su cuenta está habilitada',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ya puede acceder al panel de B2B Conecta con su catálogo, pedidos y operaciones.',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.dashboard_outlined, size: 20),
            label: const Text(
              'Entrar a B2B Conecta',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
