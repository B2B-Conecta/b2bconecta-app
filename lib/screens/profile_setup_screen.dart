import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/b2b_onboarding_shell.dart';
import '../widgets/profile_b2b_form.dart';

/// Onboarding o edición de perfil B2B (misma estética que la pestaña Perfil).
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
    _maybeAdvanceToMainApp();
  }

  @override
  void didUpdateWidget(covariant ProfileSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial != oldWidget.initial) {
      _profile = widget.initial;
      _maybeAdvanceToMainApp();
    }
  }

  void _maybeAdvanceToMainApp() {
    if (widget.isEditing) return;
    final p = _profile;
    if (p == null || !p.isReadyForMainApp) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onProfileComplete();
    });
  }

  Future<void> _softRefreshProfile() async {
    final fetched = await SupabaseService.fetchMyProfile();
    if (!mounted) return;
    setState(() => _profile = fetched);
    _maybeAdvanceToMainApp();
  }

  Future<void> _onTermsAccepted() async {
    await _softRefreshProfile();
    if (!mounted) return;
    final p = _profile;
    if (p != null && p.isReadyForMainApp) {
      widget.onProfileComplete();
    }
  }

  Future<void> _onProfileSaved() async {
    await _softRefreshProfile();
    if (!mounted) return;
    widget.onProfileComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
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
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ProfileB2BForm(
                  key: _formSessionKey,
                  initial: _profile,
                  showCloseBar: false,
                  onRelatedDataChanged: _softRefreshProfile,
                  onTermsAccepted: _onTermsAccepted,
                  onSaved: _onProfileSaved,
                  onEnterApp: widget.onProfileComplete,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: B2bOnboardingShell(
        child: ProfileB2BForm(
          key: _formSessionKey,
          initial: _profile,
          showCloseBar: false,
          onRelatedDataChanged: _softRefreshProfile,
          onTermsAccepted: _onTermsAccepted,
          onSaved: _onProfileSaved,
          onEnterApp: widget.onProfileComplete,
        ),
      ),
    );
  }
}
