import 'dart:math';
import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/widgets/b2b_header_title.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/data/supabase_access.dart';
import '../../core/utils/upload_file_guard.dart';
import '../orders/shared/order_message_attachment.dart';
import '../orders/shared/order_message_pick.dart';

const consultationPhotosBucket = 'consultation-photos';

String newConsultationMessageId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Future<OrderMessageAttachment> uploadConsultationPhoto(
    {required String threadId,
    required String messageId,
    required PreparedOrderAttachment photo}) async {
  final uid = SupabaseAccess.currentUserId;
  if (uid == null) throw StateError('Inicia sesión para enviar la consulta.');
  final checked = UploadFileGuard.check(photo.bytes, photo.fileName,
      kind: UploadKind.image, maxBytes: OrderMessageLimits.maxImageBytes);
  final path = '$threadId/$uid/$messageId/foto.${checked.extension}';
  await SupabaseAccess.client.storage
      .from(consultationPhotosBucket)
      .uploadBinary(path, checked.bytes,
          fileOptions: FileOptions(contentType: checked.mime, upsert: true));
  return OrderMessageAttachment(
      path: path, kind: 'image', mime: checked.mime, name: checked.fileName);
}

class ConsultationPhoto extends StatefulWidget {
  const ConsultationPhoto({super.key, required this.attachment});
  final OrderMessageAttachment attachment;
  @override
  State<ConsultationPhoto> createState() => _ConsultationPhotoState();
}

class _ConsultationPhotoState extends State<ConsultationPhoto> {
  late Future<String> _url = _load();
  Future<String> _load() => SupabaseAccess.client.storage
      .from(consultationPhotosBucket)
      .createSignedUrl(widget.attachment.path, 3600);
  @override
  void didUpdateWidget(covariant ConsultationPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.path != widget.attachment.path) _url = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
      future: _url,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return TextButton.icon(
              onPressed: () => setState(() => _url = _load()),
              icon: const Icon(Icons.refresh),
              label: const Text('Volver a cargar la foto'));
        }
        if (!snapshot.hasData) {
          return const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator()));
        }
        return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
                onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => Dialog(
                            child: Stack(children: [
                          InteractiveViewer(
                              child: Image.network(snapshot.data!,
                                  fit: BoxFit.contain)),
                          Positioned(
                              top: 0,
                              right: 0,
                              child: CloseButton(
                                  onPressed: () => Navigator.pop(context)))
                        ]))),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(snapshot.data!,
                        height: 160,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Text('No se pudo cargar la foto.')))));
      });
}

PreferredSizeWidget consultationAppBar(
        {required String title,
        String? subtitle,
        VoidCallback? onBack,
        bool automaticallyImplyLeading = true,
        List<Widget>? actions}) =>
    AppBar(
        automaticallyImplyLeading: automaticallyImplyLeading,
        backgroundColor: const Color(0xFF004BDD),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 72,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        leading: onBack == null ? null : BackButton(onPressed: onBack),
        actions: actions,
        title: B2bHeaderTitle(
          title: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          subtitle: subtitle == null
              ? null
              : Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFE5EFFF))),
        ));
