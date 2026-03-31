import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_b2b_form.dart';

/// Onboarding o edición de perfil B2B (misma estética que la pestaña Perfil).
///
/// Si el perfil ya tiene [ProfileModel.role] definido, el selector de rol en
/// [ProfileB2BForm] queda deshabilitado (decisión permanente; ver también
/// [SupabaseService.upsertMyProfile]).
class ProfileSetupScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isEditing
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
            key: ValueKey<Object>(
              '${initial?.id ?? 'new'}_${initial?.businessName}_${initial?.rif}',
            ),
            initial: initial,
            showCloseBar: false,
            onSaved: onProfileComplete,
          ),
        ),
      ),
    );
  }
}
