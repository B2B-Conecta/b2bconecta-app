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

  String _fiscalMapsSectionTitle() {
    switch (_role.trim().toLowerCase()) {
      case 'importador':
        return 'ENLACE GOOGLE MAPS · ALMACÉN / DOMICILIO FISCAL';
      case 'aliado':
        return 'ENLACE GOOGLE MAPS · TALLER / DOMICILIO FISCAL';
      default:
        return 'ENLACE GOOGLE MAPS (OPCIONAL)';
    }
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
              Icon(Icons.chevron_right, color: Colors.grey.shade600, size: 20),
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
                MediaPickActionChips(
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
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ProfileInfoIcon(
                      message:
                          'Si no sube logo, se muestra el de MotoLink en la barra superior.',
                      title: 'Logo del negocio',
                    ),
                    if (widget.initial?.logoStoragePath != null &&
                        widget.initial!.logoStoragePath!.trim().isNotEmpty) ...[
                      const SizedBox(width: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed:
                            (_saving || _logoBusy) ? null : _clearProfileLogo,
                        child: Text(
                          'Quitar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
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
          ProfileCollapsibleSection(
            title: 'Datos del negocio',
            subtitle: _businessNameController.text.trim().isEmpty
                ? 'Nombre, RIF y contacto'
                : _businessNameController.text.trim(),
            initiallyExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ProfileSectionHeader(label: 'TIPO DE CUENTA'),
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
                const SizedBox(height: 14),
                const ProfileSectionHeader(label: 'NOMBRE DEL NEGOCIO'),
                TextFormField(
                  controller: _businessNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _fieldDecoration('Ej: Repuestos La Victoria C.A.'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const ProfileSectionHeader(label: 'RIF'),
                TextFormField(
                  controller: _rifController,
                  decoration: _fieldDecoration('J-12345678-9'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const ProfileSectionHeader(label: 'CORREO ELECTRÓNICO'),
                TextFormField(
                  controller: _emailDisplayController,
                  readOnly: true,
                  decoration: _fieldDecoration(''),
                ),
                const SizedBox(height: 12),
                const ProfileSectionHeader(label: 'TELÉFONO'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDecoration('+58 412 1234567'),
                ),
              ],
            ),
          ),
          if (_requiereUbicacionFiscalCompleta) ...[
            const SizedBox(height: 12),
            ProfileCollapsibleSection(
              title: 'Ubicación y domicilio fiscal',
              subtitle: _ubicacionSectionSubtitle(),
              initiallyExpanded: !(widget.initial?.isComplete ?? false),
              infoMessage: _ubicacionFiscalHelp(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ProfileSectionHeader(label: 'UBICACIÓN (ESTADO / CIUDAD)'),
                  TextFormField(
                    controller: _estadoController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDecoration('Estado (ej: Miranda)'),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (!_requiereUbicacionFiscalCompleta) return null;
                      if (v == null || v.trim().isEmpty) return 'Indique el estado';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _ciudadController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDecoration('Ciudad (ej: Los Teques)'),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (!_requiereUbicacionFiscalCompleta) return null;
                      if (v == null || v.trim().isEmpty) return 'Indique la ciudad';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  const ProfileSectionHeader(label: 'DIRECCIÓN FISCAL'),
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
                  const SizedBox(height: 12),
                  ProfileSectionHeader(
                    label: _fiscalMapsSectionTitle(),
                    infoMessage: _fiscalMapsHelp(),
                  ),
                  TextFormField(
                    controller: _fiscalMapsUrlController,
                    keyboardType: TextInputType.url,
                    decoration: _fieldDecoration(
                      'https://maps.app.goo.gl/... o maps.google.com/...',
                    ),
                    validator: (v) {
                      if (!_requiereUbicacionFiscalCompleta) return null;
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) {
                        return 'Indique el enlace «Compartir» de Google Maps de su domicilio fiscal';
                      }
                      if (SupabaseService.normalizeHttpUrl(t) == null) {
                        return 'Use una URL válida (p. ej. https://maps.app.goo.gl/...)';
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
              title: 'Dirección fiscal',
              subtitle: 'Opcional',
              initiallyExpanded: false,
              child: TextFormField(
                controller: _fiscalAddressController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDecoration(
                  'Av. Principal, Local 12, Zona Industrial...',
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
            const SizedBox(height: 12),
            const ImporterCommissionSettlementsSection(),
            const SizedBox(height: 8),
            _reputationTabHint(context),
            if (widget.afterReputation != null) ...[
              const SizedBox(height: 12),
              widget.afterReputation!,
            ],
          ],
          if (_showAliadoKycSection) ...[
            const SizedBox(height: 14),
            const ProfileSectionHeader(
              label: 'VERIFICACIÓN',
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
            const ProfileSectionHeader(
              label: 'TÉRMINOS LEGALES',
              infoTitle: 'Términos y privacidad',
              infoMessage:
                  'Aliados e importadores deben aceptar los términos y la '
                  'política de privacidad vigentes antes de usar MotoLink.',
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
          ] else
            const SizedBox(height: 16),
          if (widget.beforeSignOut != null) ...[
            const SizedBox(height: 12),
            widget.beforeSignOut!,
          ],
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
      return const Center(
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
          errorBuilder: (_, __, ___) => const Center(
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
