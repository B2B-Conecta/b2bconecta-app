import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../utils/product_images.dart';

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

  Future<void> _pickImage(BuildContext context, int index) async {
    if (index != slots.length) return;
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      var ext = x.name.contains('.') ? x.name.split('.').last.toLowerCase() : 'jpeg';
      if (ext == 'jpg') ext = 'jpeg';

      final next = List<ProductImageEditSlot>.from(slots);
      next.add(ProductImageEditSlot.pending(bytes, ext));
      onChanged(next);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener la imagen: $e')),
      );
    }
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
            const Text(
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
              style: const TextStyle(
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
          Text(
            'Toca un recuadro vacío para agregar. La primera foto es la portada.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                  if (slot.pendingBytes != null)
                    Image.memory(slot.pendingBytes!, fit: BoxFit.cover)
                  else if (slot.url != null)
                    Image.network(
                      slot.url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(label),
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
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
