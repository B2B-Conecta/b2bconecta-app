import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:motolink_pro_app/app/config/brand_copy.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'package:motolink_pro_app/core/utils/stored_file_page.dart';
import 'package:motolink_pro_app/features/kyc/account_access_status.dart';
import 'package:motolink_pro_app/features/kyc/aliado_doc_type.dart';
import 'package:motolink_pro_app/features/kyc/document_review_status.dart';
import 'package:motolink_pro_app/features/kyc/profile_document_model.dart';
import 'package:motolink_pro_app/features/kyc/profile_kyc_document_tile.dart';
import 'package:motolink_pro_app/core/notifications/in_app_notification_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/core/auth/auth_service.dart';
import 'package:motolink_pro_app/core/notifications/push_notification_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/ads/meta_pixel.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/notifications/kyc_notification_match.dart';
import 'package:motolink_pro_app/features/kyc/aliado_access_approved_banner.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';
import 'profile_setup_screen.dart';

/// Aliado o mayorista con registro enviado o rechazado: sin MainShell hasta aprobación.
class AliadoPendingReviewScreen extends StatefulWidget {
  const AliadoPendingReviewScreen({
    super.key,
    required this.profile,
    required this.onRefresh,
  });

  final ProfileModel profile;
  final VoidCallback onRefresh;

  @override
  State<AliadoPendingReviewScreen> createState() =>
      _AliadoPendingReviewScreenState();
}

class _AliadoPendingReviewScreenState extends State<AliadoPendingReviewScreen> {
  RealtimeChannel? _notificationsChannel;
  RealtimeChannel? _profileChannel;
  bool _approvedBannerVisible = false;
  String _approvedMessage =
      'Su acceso a B2B Conecta está habilitado. Ya puede operar en la plataforma.';
  List<ProfileDocumentModel> _docs = const [];
  bool _loadingDocs = false;
  String? _busyDocType;
  String? _docNotice;

  bool get _isRejected =>
      widget.profile.accountAccessStatus?.trim() ==
      AccountAccessStatus.rejected;

  bool get _isImportador => widget.profile.isImportador;

  @override
  void initState() {
    super.initState();
    if (!_isRejected) {
      unawaited(PushNotificationService.instance.registerForCurrentUser());
      _notificationsChannel = SupabaseService.subscribeToMyNotifications(
        onInsert: _onNotificationInsert,
      );
      _profileChannel = SupabaseService.subscribeToMyProfileAccess(
        onAccessActive: _onAccessActive,
      );
    }
    if (!_isImportador) unawaited(_loadDocs());
  }

  Future<void> _loadDocs() async {
    if (!mounted) return;
    setState(() => _loadingDocs = true);
    try {
      final list = await SupabaseService.fetchMyProfileDocuments();
      if (!mounted) return;
      setState(() {
        _docs = list;
        _loadingDocs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDocs = false);
    }
  }

  ProfileDocumentModel? _docFor(String type) {
    for (final doc in _docs) {
      if (doc.docType == type) return doc;
    }
    return null;
  }

  Future<void> _openDoc(ProfileDocumentModel doc) {
    final name = doc.fileName?.trim();
    return openStoredFile(
      context,
      signedUrl: () => SupabaseService.createSignedUrlForProfileDocument(
        doc.storagePath,
      ),
      fileName: (name == null || name.isEmpty)
          ? AliadoDocType.labelEs(doc.docType)
          : name,
    );
  }

  Future<void> _replaceRejected(String docType) async {
    final picked = await pickKycDocumentBytes(context);
    if (picked == null || !mounted) return;
    setState(() => _busyDocType = docType);
    try {
      await SupabaseService.uploadMyProfileDocument(
        docType: docType,
        bytes: picked.bytes,
        fileName: picked.fileName,
      );
      if (!mounted) return;
      setState(() {
        _docNotice =
            '${AliadoDocType.labelEs(docType)} quedó otra vez en revisión.';
      });
      await _loadDocs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reenviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyDocType = null);
    }
  }

  @override
  void dispose() {
    unawaited(SupabaseService.unsubscribeChannel(_notificationsChannel));
    unawaited(SupabaseService.unsubscribeChannel(_profileChannel));
    super.dispose();
  }

  void _onAccessActive() {
    if (!mounted || _isRejected) return;
    trackCompleteRegistration(userId: widget.profile.id);
    widget.onRefresh();
  }

  Future<void> _onNotificationInsert(InAppNotificationModel notification) async {
    if (notification.type.trim().toLowerCase() == 'kyc' &&
        !isAliadoAccessApprovedNotification(
          type: notification.type,
          title: notification.title,
        )) {
      if (!mounted) return;
      setState(() {
        final body = notification.body.trim();
        _docNotice = body.isEmpty ? notification.title.trim() : body;
      });
      if (!_isImportador) unawaited(_loadDocs());
      return;
    }

    if (!isAliadoAccessApprovedNotification(
      type: notification.type,
      title: notification.title,
    )) {
      return;
    }

    final body = BrandCopy.display(
      notification.body.trim().isNotEmpty
          ? notification.body.trim()
          : _approvedMessage,
    );

    await PushNotificationService.instance.showLocalBanner(
      title: notification.title.trim().isNotEmpty
          ? notification.title.trim()
          : 'Acceso validado',
      body: body,
      type: notification.type,
      relatedId: notification.relatedId,
      notificationId: notification.id,
    );

    if (!mounted) return;
    setState(() {
      _approvedBannerVisible = true;
      _approvedMessage = body;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_approvedBannerVisible)
              AliadoAccessApprovedBanner(
                message: _approvedMessage,
                onDismiss: () => setState(() => _approvedBannerVisible = false),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: MotoLinkProLogo(height: 56)),
                    const SizedBox(height: 28),
                    Text(
                      _isRejected
                          ? 'Solicitud no aprobada'
                          : 'Solicitud en revisión',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRejected
                          ? (_isImportador
                              ? 'B2B Conecta no pudo aprobar su registro de mayorista en este momento. '
                                  'Revise el motivo, corrija su perfil y vuelva a enviar.'
                              : 'B2B Conecta no pudo aprobar su registro inicial en este momento. '
                                  'Revise el motivo, corrija la documentación y vuelva a enviar.')
                          : (_isImportador
                              ? 'Recibimos su registro de mayorista. Un administrador de B2B Conecta '
                                  'revisará su perfil y habilitará el acceso a la plataforma.'
                              : 'Recibimos su registro inicial. Un administrador de B2B Conecta '
                                  'revisará su documentación y habilitará el acceso a la plataforma.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    if (_isRejected &&
                        widget.profile.accountReviewNote != null &&
                        widget.profile.accountReviewNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Motivo',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red.shade900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.profile.accountReviewNote!.trim(),
                                style: TextStyle(color: Colors.red.shade900),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Estado: ${AccountAccessStatus.labelEs(widget.profile.accountAccessStatus)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (!_isRejected) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Le avisaremos con una notificación push cuando su acceso sea validado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (!_isImportador) ...[
                      const SizedBox(height: 20),
                      _documentsCard(),
                    ],
                    const SizedBox(height: 28),
                    if (_isRejected)
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProfileSetupScreen(
                                initial: widget.profile,
                                onProfileComplete: () {
                                  Navigator.of(context).pop();
                                  widget.onRefresh();
                                },
                              ),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Corregir y reenviar registro'),
                      ),
                    if (!_isRejected)
                      OutlinedButton(
                        onPressed: () {
                          widget.onRefresh();
                          if (!_isImportador) unawaited(_loadDocs());
                        },
                        child: const Text('Actualizar estado'),
                      ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        await AuthService.signOut();
                      },
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _documentsCard() {
    final types = [
      ...AliadoDocType.kycRequiredAliado,
      ...AliadoDocType.kycSupplementaryAliado,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Documentos',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Si uno se rechaza, use Reenviar documento. Los aprobados no se modifican.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            if (_docNotice != null && _docNotice!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _docNotice!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (_loadingDocs)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              )
            else
              for (final type in types)
                if (_docFor(type) != null ||
                    AliadoDocType.kycRequiredAliado.contains(type))
                  _docTile(type),
          ],
        ),
      ),
    );
  }

  Widget _docTile(String type) {
    final doc = _docFor(type);
    final status = doc?.reviewStatus?.trim();
    final canReplace = doc != null && status == DocumentReviewStatus.rechazado;
    final busy = _busyDocType == type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileKycDocumentTile(
            title: AliadoDocType.labelEs(type),
            hasFile: doc != null,
            statusLabel: doc == null
                ? 'Sin archivo'
                : DocumentReviewStatus.labelEs(status),
            effectiveStatus: status,
            reviewNote: doc?.reviewNote,
            busy: busy,
            showPickActions: false,
            onView: doc == null ? null : () => _openDoc(doc),
            onPickCamera: () {},
            onPickGallery: () {},
            onPickFile: () {},
          ),
          if (canReplace) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: busy ? null : () => _replaceRejected(type),
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_outlined, size: 18),
              label: Text(busy ? 'Reenviando…' : 'Reenviar documento'),
            ),
          ],
        ],
      ),
    );
  }
}
