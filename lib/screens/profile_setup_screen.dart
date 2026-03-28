import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

const _kCorporateRed = Color(0xFFE31B23);

/// Formulario para completar datos B2B antes de acceder al catálogo.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    this.initial,
    this.isEditing = false,
    required this.onProfileComplete,
  });

  final ProfileModel? initial;

  /// `true` cuando se abre desde el catálogo para actualizar datos B2B.
  final bool isEditing;
  final VoidCallback onProfileComplete;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessNameController;
  late final TextEditingController _rifController;
  late final TextEditingController _phoneController;
  String _role = 'importador';
  bool _saving = false;

  static const _roles = <String, String>{
    'importador': 'Importador',
    'aliado': 'Aliado',
  };

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _businessNameController =
        TextEditingController(text: i?.businessName ?? '');
    _rifController = TextEditingController(text: i?.rif ?? '');
    _phoneController = TextEditingController(text: i?.phone ?? '');
    final r = i?.role?.trim().toLowerCase();
    if (r == 'importador' || r == 'aliado') {
      _role = r!;
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _rifController.dispose();
    _phoneController.dispose();
    super.dispose();
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
      );
      if (!mounted) return;
      widget.onProfileComplete();
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.isEditing ? 'Editar perfil de empresa' : 'Perfil de empresa',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _signOut,
            child: const Text(
              'Cerrar sesión',
              style:
                  TextStyle(color: _kCorporateRed, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.isEditing
                      ? 'Actualiza los datos de tu empresa'
                      : 'Completa tu perfil B2B',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isEditing
                      ? 'Los cambios se reflejan en el catálogo y en tu cuenta.'
                      : 'Estos datos son necesarios para operar en MotoLink Pro.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _businessNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre comercial o razón social',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Campo obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _rifController,
                  decoration: InputDecoration(
                    labelText: 'RIF',
                    hintText: 'Ej: J-12345678-9',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Campo obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: InputDecoration(
                    labelText: 'Rol en la plataforma',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _roles.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) {
                          if (v != null) setState(() => _role = v);
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kCorporateRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.isEditing
                              ? 'GUARDAR CAMBIOS'
                              : 'GUARDAR Y CONTINUAR',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
