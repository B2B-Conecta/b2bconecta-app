import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/product_photo_lightbox.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'package:motolink_pro_app/core/utils/upload_file_guard.dart';
import 'product_images.dart';

/// Slot de imagen en edición: URL existente o bytes pendientes de subir.
class ProductImageEditSlot {
  ProductImageEditSlot.url(this.url)
      : pendingBytes = null,
        pendingExt = null;

  ProductImageEditSlot.pending(this.pendingBytes, this.pendingExt) : url = null;

  String? url;
  Uint8List? pendingBytes;
  String? pendingExt;

  bool get hasContent =>
      (url != null && url!.isNotEmpty) ||
      (pendingBytes != null && pendingBytes!.isNotEmpty);
}

/// Editor simple: hasta 3 fotos por producto.
class ProductImageGalleryEditor extends StatelessWidget {
  const ProductImageGalleryEditor({
    super.key,
    required this.slots,
    required this.onChanged,
    this.enabled = true,
  });

  final List<ProductImageEditSlot> slots;
  final ValueChanged<List<ProductImageEditSlot>> onChanged;
  final bool enabled;

  Future<void> _pickImage(
    BuildContext context,
    int index, {
    DocumentPickChannel channel = DocumentPickChannel.gallery,
  }) async {
    if (index != slots.length) return;
    try {
      final picked = await pickKycDocument(channel: channel);
      if (picked == null) return;
      final checked = UploadFileGuard.check(
        picked.bytes,
        picked.fileName,
        kind: UploadKind.image,
      );
      final ext = checked.extension == 'jpg' ? 'jpeg' : checked.extension;

      final next = List<ProductImageEditSlot>.from(slots);
      next.add(ProductImageEditSlot.pending(checked.bytes, ext));
      onChanged(next);
    } on UploadRejectedException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener la imagen: $e')),
      );
    }
  }

  void _openZoom(BuildContext context, int index) {
    final images = <ImageProvider<Object>>[];
    var start = 0;
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (!slot.hasContent) continue;
      if (i == index) start = images.length;
      if (slot.pendingBytes != null) {
        images.add(MemoryImage(slot.pendingBytes!));
      } else if (slot.url != null && slot.url!.isNotEmpty) {
        images.add(NetworkImage(slot.url!));
      }
    }
    if (images.isEmpty) return;
    showProductPhotoLightbox(
      context,
      images: images,
      initialIndex: start,
      productName: 'Fotos del producto',
    );
  }

  void _removeAt(int index) {
    final next = List<ProductImageEditSlot>.from(slots);
    if (index < next.length) {
      next.removeAt(index);
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = slots.length;
    final canAdd = count < kMaxProductImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Fotos del producto',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '$count / $kMaxProductImages',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < kMaxProductImages; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _slotTile(context, i)),
            ],
          ],
        ),
        if (canAdd && enabled) ...[
          const SizedBox(height: 8),
          if (MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(
                  context,
                  count,
                  channel: DocumentPickChannel.camera,
                ),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Tomar foto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brand,
                  side: const BorderSide(color: AppColors.brand),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu
                ? 'Toca un recuadro o toma una foto. La primera es la portada.'
                : 'Toca un recuadro para elegir archivo. La primera es la portada.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _slotTile(BuildContext context, int index) {
    final hasSlot = index < slots.length && slots[index].hasContent;
    final slot = hasSlot ? slots[index] : null;
    final label = index == 0 ? 'Portada' : '${index + 1}';
    final canAddHere = enabled && index == slots.length && index < kMaxProductImages;

    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: AppColors.fieldFill,
        borderRadius: AppDecorations.radius12,
        clipBehavior: Clip.antiAlias,
        child: hasSlot && slot != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => _openZoom(context, index),
                    child: SizedBox.expand(
                      child: slot.pendingBytes != null
                          ? Image.memory(slot.pendingBytes!, fit: BoxFit.cover)
                          : Image.network(
                              slot.url!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder(label),
                            ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: B2BThemeExtension.of(context)
                              .surfaceCard
                              .withOpacity(0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.zoom_in,
                            size: 14,
                            color: B2BThemeExtension.of(context).textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (index == 0)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Portada',
                          style: TextStyle(color: Colors.white, fontSize: 9),
                        ),
                      ),
                    ),
                  if (enabled)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                        onPressed: () => _removeAt(index),
                      ),
                    ),
                ],
              )
            : InkWell(
                onTap: canAddHere ? () => _pickImage(context, index) : null,
                child: Opacity(
                  opacity: canAddHere ? 1 : 0.45,
                  child: _placeholder(label),
                ),
              ),
      ),
    );
  }

  Widget _placeholder(String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, color: Colors.grey.shade500),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Construye la lista final de URLs tras subir pendientes.
Future<List<String>> resolveProductImageEditSlots({
  required List<ProductImageEditSlot> slots,
  required Future<String> Function(Uint8List bytes, String ext, int slot)
      upload,
}) async {
  final urls = <String>[];
  for (var i = 0; i < slots.length && urls.length < kMaxProductImages; i++) {
    final s = slots[i];
    if (s.pendingBytes != null && s.pendingExt != null) {
      urls.add(await upload(s.pendingBytes!, s.pendingExt!, i + 1));
    } else if (s.url != null && s.url!.isNotEmpty) {
      urls.add(s.url!);
    }
  }
  return normalizeProductImageUrls(urls);
}
