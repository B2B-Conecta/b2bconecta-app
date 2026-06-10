import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_b2b_form.dart';

/// Onboarding o edición de perfil B2B (misma estética que la pestaña Perfil).
///
/// Si el perfil ya tiene [ProfileModel.role] definido, el selector de rol en
/// [ProfileB2BForm] queda deshabilitado (decisión permanente; ver también
/// [SupabaseService.upsertMyProfile]).
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    this.initial,
    this.isEditing = false,
    required this.onProfileComplete,
  });

  final ProfileModel? initial;
  final bool isEditing;
  final VoidCallback onProfileComplete;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  ProfileModel? _profile;

  /// No cambiar al crear el perfil por primera vez (evita dispose mid-upload).
  final Key _formSessionKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _profile = widget.initial;
  }

  @override
  void didUpdateWidget(covariant ProfileSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != oldWidget.initial) {
      _profile = widget.initial;
    }
  }

  /// Actualiza datos del perfil sin desmontar el formulario (T&C, documentos).
  Future<void> _softRefreshProfile() async {
    final fetched = await SupabaseService.fetchMyProfile();
    if (!mounted) return;
    setState(() => _profile = fetched);
  }

  Future<void> _onProfileSaved() async {
    await _softRefreshProfile();
    if (!mounted) return;
    widget.onProfileComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isEditing
          ? AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: const Text(
                'Mi Perfil B2B',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.shade200,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: ProfileB2BForm(
            key: _formSessionKey,
            initial: _profile,
            showCloseBar: false,
            onRelatedDataChanged: _softRefreshProfile,
            onSaved: _onProfileSaved,
          ),
        ),
      ),
    );
  }
}
