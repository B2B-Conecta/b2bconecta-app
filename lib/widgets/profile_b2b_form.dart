import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'motolink_pro_logo.dart';
import 'main_shell_tab.dart';
import 'profile_kyc_documents_section.dart';
import 'importer_accepted_pago_metodos_section.dart';
import 'importer_commission_settlements_section.dart';
import 'authorization_status_section.dart';

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
    if (_persistedAsAliado) {
      MainShellTabController.registerKycDocumentationSectionKey(
        _kycDocumentationSectionKey,
      );
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

  String _fiscalMapsSectionDescription() {
    switch (_role.trim().toLowerCase()) {
      case 'importador':
        return 'Pegue el enlace «Compartir» de Google Maps apuntando a su almacén o domicilio fiscal. '
            'MotoLink lo usa como origen al armar la ruta en vivo hacia el taller del aliado cuando el pedido '
            'está en tránsito (junto con el enlace del aliado en su perfil).';
      case 'aliado':
        return 'Enlace «Compartir» de Google Maps de su taller (requisito mínimo junto con RIF y dirección fiscal).';
      default:
        return 'Pegue un enlace público (compartir ubicación) para que MotoLink y los participantes '
            'abran su domicilio fiscal en el mapa.';
    }
  }

  String _ubicacionFiscalIntroText() {
    switch (_role.trim().toLowerCase()) {
      case 'aliado':
        return 'Estado, ciudad y domicilio fiscal son obligatorios para ingresar y solicitar pedidos.';
      case 'importador':
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

  Widget _reputationTabHint(BuildContext context) {
    return Material(
      color: AppColors.brandBlueContainer.withOpacity(0.35),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => MainShellTabController.navigateToReputationTab(),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.star_outline, color: Colors.amber.shade800, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Reputación, cierres semanales y comentarios en la pestaña Reputación.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade600),
            ],
          ),
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
          if (_roleLocked && _persistedAsImportador) ...[
            const SizedBox(height: 14),
            AuthorizationStatusSection(
              key: ValueKey<int>(_authSectionTick),
              profile: widget.initial,
            ),
          ],
          if (_persistedAsImportador && widget.initial != null) ...[
            const SizedBox(height: 20),
            ImporterAcceptedPagoMetodosSection(
              profile: widget.initial!,
              onSaved: widget.onRelatedDataChanged,
            ),
            const SizedBox(height: 20),
            const ImporterCommissionSettlementsSection(),
            const SizedBox(height: 12),
            _reputationTabHint(context),
          ],
          if (_persistedAsAliado) ...[
            const SizedBox(height: 14),
            _sectionLabel('VERIFICACIÓN'),
            KeyedSubtree(
              key: _kycDocumentationSectionKey,
              child: ProfileKycDocumentsSection(
                role: 'aliado',
                profile: widget.initial,
                kycStatus: widget.initial?.kycStatus,
                onChanged: () {
                  _bumpAuthorizationSection();
                  widget.onRelatedDataChanged?.call();
                },
              ),
            ),
          ],
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
