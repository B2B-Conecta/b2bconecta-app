import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cash_phase_policy.dart';
import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'main_shell_tab.dart';
import 'aliado_kyc_documents_section.dart';
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
  late final TextEditingController _emailDisplayController;
  String _role = 'importador';
  bool _saving = false;
  double? _openExposure;
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

  bool get _ubicacionObligatoria {
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
            widget.initial?.creditoConsumidoAcumulado) {
      _loadOpenExposure();
    }
  }

  Future<void> _loadOpenExposure() async {
    setState(() => _loadingExposure = true);
    try {
      final v = await SupabaseService.fetchOpenCreditExposureForCurrentAliado();
      if (!mounted) return;
      setState(() {
        _openExposure = v;
        _loadingExposure = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
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
    _emailDisplayController.dispose();
    super.dispose();
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
    final cons = widget.initial?.creditoConsumidoAcumulado ?? 0.0;
    final disponible =
        ((limMostrado ?? 0) - exp - cons).clamp(0.0, double.infinity);
    final pce = widget.initial?.primerosPedidosContadoEntregados ?? 0;
    final enFaseContado = pce < CashPhasePolicy.entregasRequeridas;
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
              const SizedBox(height: 12),
            ],
            Text(
              limRaw == null && !enFaseContado
                  ? 'Pendiente: MotoLink asignará su límite de crédito (pestaña Crédito).'
                  : enFaseContado
                      ? 'Límite mostrado (fase contado): \$${(limMostrado ?? 0).toStringAsFixed(2)}'
                      : 'Límite autorizado: \$${(limMostrado ?? 0).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (limRaw != null || enFaseContado) ...[
              const SizedBox(height: 10),
              if (_loadingExposure)
                const LinearProgressIndicator(minHeight: 3)
              else ...[
                Text(
                  'Compromiso en pedidos abiertos: \$${exp.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Crédito imputado (entregas con línea MotoLink): \$${cons.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Disponible estimado: \$${disponible.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandBlue,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
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
      );
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
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.12),
                borderRadius: AppDecorations.radius12,
              ),
              child: const Icon(
                Icons.business_outlined,
                size: 36,
                color: AppColors.brand,
              ),
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
          if (_ubicacionObligatoria) ...[
            const SizedBox(height: 16),
            _sectionLabel('UBICACIÓN (ESTADO / CIUDAD)'),
            Text(
              'Visible en el catálogo para ubicar proveedores y talleres. '
              'Complete también la dirección fiscal más abajo: estado, ciudad y domicilio '
              'son obligatorios para solicitar pedidos.',
              style: TextStyle(fontSize: 12, height: 1.35, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _estadoController,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration('Estado (ej: Miranda)'),
              validator: (v) {
                if (!_ubicacionObligatoria) return null;
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
                if (!_ubicacionObligatoria) return null;
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
                if (!_ubicacionObligatoria) return null;
                if (v == null || v.trim().isEmpty) {
                  return 'Indique la dirección fiscal (domicilio de la empresa)';
                }
                return null;
              },
            ),
          ],
          if (!_ubicacionObligatoria) ...[
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
            _aliadoCreditSummary(),
            const SizedBox(height: 20),
            KeyedSubtree(
              key: _kycDocumentationSectionKey,
              child: AliadoKycDocumentsSection(
                kycStatus: widget.initial?.kycStatus,
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
