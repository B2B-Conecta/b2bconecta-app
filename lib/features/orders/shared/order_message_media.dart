import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'order_message_attachment.dart';

class OrderMessageMediaStrip extends StatelessWidget {
  const OrderMessageMediaStrip({super.key, required this.attachments});

  final List<OrderMessageAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in attachments) ...[
            if (item.isVideo)
              _OrderMessageVideo(attachment: item)
            else
              _OrderMessagePhoto(attachment: item),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _OrderMessagePhoto extends StatefulWidget {
  const _OrderMessagePhoto({required this.attachment});

  final OrderMessageAttachment attachment;

  @override
  State<_OrderMessagePhoto> createState() => _OrderMessagePhotoState();
}

class _OrderMessagePhotoState extends State<_OrderMessagePhoto> {
  late final Future<String> _urlFuture =
      SupabaseService.createSignedUrlForOrderMessageAttachment(
    widget.attachment.path,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return const SizedBox(
            width: 160,
            height: 80,
            child: Center(child: Text('No se pudo mostrar la foto')),
          );
        }
        final url = snap.data;
        if (url == null || url.isEmpty) {
          return const SizedBox(
            width: 120,
            height: 90,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () => _openPhoto(context, url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 160,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                width: 160,
                height: 80,
                child: Center(child: Text('No se pudo mostrar la foto')),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderMessageVideo extends StatefulWidget {
  const _OrderMessageVideo({required this.attachment});

  final OrderMessageAttachment attachment;

  @override
  State<_OrderMessageVideo> createState() => _OrderMessageVideoState();
}

class _OrderMessageVideoState extends State<_OrderMessageVideo> {
  VideoPlayerController? _controller;
  bool _starting = false;
  String? _error;

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_starting) return;
    final current = _controller;
    if (current != null && current.value.isInitialized) {
      if (current.value.isPlaying) {
        await current.pause();
      } else {
        await current.play();
      }
      if (mounted) setState(() {});
      return;
    }

    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final url = await SupabaseService.createSignedUrlForOrderMessageAttachment(
        widget.attachment.path,
      );
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      controller.addListener(_onTick);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _starting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo reproducir el video';
        _starting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return Material(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _play,
        child: SizedBox(
          width: 220,
          height: 140,
          child: ready
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(controller),
                    Center(
                      child: Icon(
                        controller.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: Colors.white70,
                        size: 42,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_starting)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 42,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      _error ?? 'Video',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Botones de captura del hilo. No sustituyen el envío de texto.
class OrderMessageAttachButtons extends StatelessWidget {
  const OrderMessageAttachButtons({
    super.key,
    required this.enabled,
    required this.onPhotoCamera,
    required this.onPhotoGallery,
    required this.onVideoCamera,
    required this.onVideoGallery,
  });

  final bool enabled;
  final VoidCallback onPhotoCamera;
  final VoidCallback onPhotoGallery;
  final VoidCallback onVideoCamera;
  final VoidCallback onVideoGallery;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        IconButton(
          tooltip: 'Tomar foto',
          onPressed: enabled ? onPhotoCamera : null,
          icon: const Icon(Icons.photo_camera_outlined),
          color: AppColors.brand,
        ),
        IconButton(
          tooltip: 'Foto de galería',
          onPressed: enabled ? onPhotoGallery : null,
          icon: const Icon(Icons.photo_library_outlined),
          color: AppColors.brand,
        ),
        IconButton(
          tooltip: 'Grabar video',
          onPressed: enabled ? onVideoCamera : null,
          icon: const Icon(Icons.videocam_outlined),
          color: AppColors.brand,
        ),
        IconButton(
          tooltip: 'Video de galería',
          onPressed: enabled ? onVideoGallery : null,
          icon: const Icon(Icons.video_library_outlined),
          color: AppColors.brand,
        ),
      ],
    );
  }
}
