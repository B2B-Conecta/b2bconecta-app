import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_share_sheet.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'product_min_order_qty.dart';
import 'product_custom_fields_section.dart';
import 'product_delete_outcome_sheet.dart';
import 'product_image_gallery_editor.dart';
import 'importer_product_price_preview.dart';

/// Crear o editar un producto del inventario (importador).
class ImporterProductEditScreen extends StatefulWidget {
  const ImporterProductEditScreen({super.key, this.initial});

  /// `null` = alta manual nueva.
  final PartModel? initial;

  @override
  State<ImporterProductEditScreen> createState() =>
      _ImporterProductEditScreenState();
}

class _ImporterProductEditScreenState extends State<ImporterProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late final TextEditingController _bsPriceController;
  double? _tasaBcv;
  late final TextEditingController _salePriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _minOrderQtyController;
  late final TextEditingController _categoryController;
  late final TextEditingController _compatController;
  List<ProductImageEditSlot> _imageSlots = [];
  bool _isActive = true;
  bool _hasWarranty = false;
  bool _saving = false;
  Map<String, dynamic> _customFields = const {};

  bool get _isEdit => widget.initial != null && widget.initial!.id.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _skuController = TextEditingController(text: p?.sku ?? '');
    _nameController = TextEditingController(text: p?.nombre ?? '');
    _descController = TextEditingController(text: p?.descripcion ?? '');
    _priceController = TextEditingController(
      text: p != null ? p.precio.toStringAsFixed(2) : '',
    );
    _bsPriceController = TextEditingController();
    _salePriceController = TextEditingController(
      text: p?.salePriceUsd != null ? p!.salePriceUsd!.toStringAsFixed(2) : '',
    );
    _stockController = TextEditingController(
      text: p != null ? '${p.stock}' : '',
    );
    _minOrderQtyController = TextEditingController(
      text: '${p?.minOrderQtyEffective ?? ProductMinOrderQty.platformFloor}',
    );
    _categoryController = TextEditingController(text: p?.category ?? '');
    _compatController = TextEditingController(text: p?.compatibilidad ?? '');
    _imageSlots = (p?.imageUrls ?? const [])
        .map((u) => ProductImageEditSlot.url(u))
        .toList();
    if (_imageSlots.isEmpty && (p?.coverImageUrl ?? '').isNotEmpty) {
      _imageSlots = [ProductImageEditSlot.url(p!.coverImageUrl!)];
    }
    _isActive = p?.isActive ?? true;
    _hasWarranty = p?.hasWarranty ?? false;
    _customFields = Map<String, dynamic>.from(p?.customFields ?? const {});
    for (final controller in [
      _priceController,
      _salePriceController,
      _minOrderQtyController,
    ]) {
      controller.addListener(_onPreviewChanged);
    }
    _loadTasaBcv();
  }

  void _onPreviewChanged() {
    _syncBsPrice();
    if (mounted) setState(() {});
  }

  Future<void> _loadTasaBcv() async {
    final rate = await BcvBasePrice.currentRate();
    if (!mounted) return;
    setState(() => _tasaBcv = rate);
    _syncBsPrice();
  }

  void _syncBsPrice() {
    final next = _bsTextFor(parsePreviewMoney(_priceController.text));
    if (_bsPriceController.text == next) return;
    _bsPriceController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  String _bsTextFor(double? refUsd) {
    final bs = BcvBasePrice.bsForRef(refUsd, _tasaBcv);
    if (bs == null) return '';
    return formatVesAmount(bs);
  }

  @override
  void dispose() {
    for (final controller in [
      _priceController,
      _salePriceController,
      _minOrderQtyController,
    ]) {
      controller.removeListener(_onPreviewChanged);
    }
    _skuController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _bsPriceController.dispose();
    _salePriceController.dispose();
    _stockController.dispose();
    _minOrderQtyController.dispose();
    _categoryController.dispose();
    _compatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final price = double.tryParse(
      _priceController.text.trim().replaceAll(',', '.'),
    );
    final stock = int.tryParse(_stockController.text.trim());
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precio inválido.')),
      );
      return;
    }
    if (stock == null || stock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock inválido.')),
      );
      return;
    }
    final minOrderQty = int.tryParse(_minOrderQtyController.text.trim());
    if (minOrderQty == null ||
        minOrderQty < ProductMinOrderQty.absoluteFloor) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'La cantidad mínima de pedido es obligatoria y no puede ser menor a ${ProductMinOrderQty.absoluteFloor}.',
          ),
        ),
      );
      return;
    }
    final saleRaw = _salePriceController.text.trim();
    double? salePrice;
    if (saleRaw.isNotEmpty) {
      salePrice = double.tryParse(saleRaw.replaceAll(',', '.'));
      if (salePrice == null || salePrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Precio USD inválido.')),
        );
        return;
      }
      if (salePrice >= price) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El precio USD debe ser menor que el precio REF.',
            ),
          ),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final imageUrls = await resolveProductImageEditSlots(
        slots: _imageSlots,
        upload: (bytes, ext, slot) => SupabaseService.uploadProductImage(
          bytes: bytes,
          fileExtension: ext,
          productId: _isEdit ? widget.initial!.id : null,
          slot: slot,
        ),
      );

      if (_isEdit) {
        await SupabaseService.updateProduct(
          productId: widget.initial!.id,
          sku: _skuController.text.trim(),
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          priceUsd: price,
          salePriceUsd: salePrice,
          clearSalePrice: salePrice == null,
          clearDiscountRules: true,
          stock: stock,
          minOrderQty: minOrderQty,
          category: _categoryController.text.trim(),
          compatibility: _compatController.text.trim(),
          imageUrls: imageUrls,
          isActive: _isActive,
          hasWarranty: _hasWarranty,
          customFields: _customFields,
        );
      } else {
        await SupabaseService.insertProduct(
          sku: _skuController.text.trim(),
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          priceUsd: price,
          salePriceUsd: salePrice,
          stock: stock,
          minOrderQty: minOrderQty,
          category: _categoryController.text.trim(),
          compatibility: _compatController.text.trim(),
          imageUrls: imageUrls,
          isActive: _isActive,
          hasWarranty: _hasWarranty,
          customFields: _customFields,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteProduct() async {
    if (!_isEdit) return;
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : widget.initial!.nombre;
    final confirmed = await showAdaptiveAdminSheet<bool>(
      context: context,
      builder: (ctx, _) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 12 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Eliminar producto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Se quita del inventario y del catálogo. No se puede deshacer.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final result = await SupabaseService.deleteProduct(
        productId: widget.initial!.id,
        label: name,
      );
      if (!mounted) return;
      if (result.allSucceeded) {
        Navigator.of(context).pop(true);
        return;
      }
      if (result.hasBlocked) {
        final action = await showProductDeleteOutcomeSheet(
          context: context,
          result: result,
        );
        if (!mounted) return;
        if (action == ProductDeleteOutcomeAction.pauseBlocked) {
          try {
            await SupabaseService.setProductsActiveBulk(
              productIds: result.blockedIds,
              isActive: false,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Producto pausado. Ya no aparece en el catálogo.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop(true);
            return;
          } catch (pauseError) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No se pudo pausar: $pauseError')),
            );
          }
        }
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.fieldFill,
      border: OutlineInputBorder(
        borderRadius: AppDecorations.radius12,
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildShareButton() {
    final product = widget.initial;
    if (product == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        onPressed: () => showProductShareSheet(context, product),
        icon: const Icon(Icons.ios_share_rounded, size: 18),
        label: const Text('Compartir producto'),
      ),
    );
  }

  Widget _buildVisibilitySwitch() {
    return SwitchTheme(
      data: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.borderSubtle;
          }
          return AppColors.brand.withOpacity(0.85);
        }),
        trackOutlineWidth: WidgetStateProperty.all(1.8),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade400;
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.brand;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.brand.withOpacity(0.22);
          }
          return Colors.transparent;
        }),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          _isActive ? 'Publicado' : 'Pausado',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _isActive ? AppColors.successGreen : AppColors.brandAccent,
          ),
        ),
        subtitle: Text(
          _isActive
              ? 'Las tiendas ven este producto en el catálogo.'
              : 'Un producto pausado se oculta de inmediato del catálogo de las tiendas.',
          style: const TextStyle(fontSize: 12),
        ),
        value: _isActive,
        onChanged: _saving ? null : (v) => setState(() => _isActive = v),
      ),
    );
  }

  Widget _buildImageSection() {
    return ProductImageGalleryEditor(
      slots: _imageSlots,
      enabled: !_saving,
      onChanged: (next) => setState(() => _imageSlots = next),
    );
  }

  Widget _buildMainFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _skuController,
          decoration: _dec('SKU', hint: 'Ej: REP-CG150-001'),
          textCapitalization: TextCapitalization.characters,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'SKU obligatorio';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: _dec('Nombre'),
          textCapitalization: TextCapitalization.sentences,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Nombre obligatorio';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _priceController,
          decoration: _dec('Precio REF'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _salePriceController,
          enabled: !_saving,
          decoration: _dec(
            'Precio USD',
            hint: 'Opcional · promoción, menor que el REF',
          ).copyWith(
            helperText: 'Precio de promoción. Si lo dejas vacío, la tienda solo ve el REF.',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bsPriceController,
          readOnly: true,
          enableInteractiveSelection: true,
          decoration: _dec(
            'Precio (Bs)',
            hint: _tasaBcv == null ? 'No disponible' : null,
          ).copyWith(
            helperText:
                'Solo lectura. Se calcula sobre el precio REF. La promoción USD no entra.',
          ),
        ),
        const SizedBox(height: 12),
        ImporterProductPricePreview(
          listPriceUsd: parsePreviewMoney(_priceController.text),
          salePriceUsd: parsePreviewMoney(_salePriceController.text),
          quantity: int.tryParse(_minOrderQtyController.text.trim()) ??
              ProductMinOrderQty.platformFloor,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _stockController,
          decoration: _dec('Stock'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _minOrderQtyController,
          decoration: _dec(
            'Pedido mínimo / MOQ',
            hint: 'Su mínimo (vacío → 5)',
          ).copyWith(
            helperText:
                'Si define un mínimo, esa cantidad manda (mínimo ${ProductMinOrderQty.absoluteFloor}). '
                'Si no lo define, la plataforma usa ${ProductMinOrderQty.platformDefault}.',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            final n = int.tryParse(v?.trim() ?? '');
            if (n == null || n < ProductMinOrderQty.absoluteFloor) {
              return 'Obligatorio · mínimo ${ProductMinOrderQty.absoluteFloor}';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 12),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          clipBehavior: Clip.none,
          title: const Text(
            'Compatibilidad y descripción',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'Opcional. La tienda puede comprar sin estos datos.',
            style: TextStyle(fontSize: 12),
          ),
          children: [
            TextFormField(
              controller: _descController,
              decoration: _dec('Descripción'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryController,
              decoration: _dec('Categoría'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _compatController,
              decoration: _dec('Compatibilidad'),
            ),
            const SizedBox(height: 12),
            ProductCustomFieldsEditor(
              initial: _customFields,
              enabled: !_saving,
              onChanged: (fields) => _customFields = fields,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Producto con garantía',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'La tienda ve el sello de garantía en el catálogo.',
                style: TextStyle(fontSize: 12),
              ),
              value: _hasWarranty,
              onChanged: _saving ? null : (v) => setState(() => _hasWarranty = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormActions({required bool desktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        desktop
            ? Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_isEdit ? 'Guardar cambios' : 'Crear producto'),
                    ),
                  ),
                  if (_isEdit) ...[
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _deleteProduct,
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                      label: Text(
                        'Eliminar',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                    ),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_isEdit ? 'Guardar cambios' : 'Crear producto'),
                  ),
                  if (_isEdit) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _deleteProduct,
                      icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                      label: Text(
                        'Eliminar producto',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade300),
                      ),
                    ),
                  ],
                ],
              ),
      ],
    );
  }

  Widget _buildFormContent({required bool desktop}) {
    if (desktop) {
      return Form(
        key: _formKey,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.productDetailMaxWidth,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: AppDecorations.cardShadow,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildShareButton(),
                              _buildVisibilitySwitch(),
                              const SizedBox(height: 16),
                              _buildImageSection(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMainFields(),
                        _buildFormActions(desktop: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _buildShareButton(),
          _buildVisibilitySwitch(),
          const SizedBox(height: 8),
          _buildMainFields(),
          const SizedBox(height: 12),
          _buildImageSection(),
          _buildFormActions(desktop: false),
        ],
      ),
    );
  }

  Widget _buildFormBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            constraints.maxWidth >= AppBreakpoints.b2bDesktop;
        return _buildFormContent(desktop: desktop);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.b2bDesktop;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceTinted,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEdit ? 'Editar producto' : 'Añadir producto'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Compartir producto',
              onPressed: () => showProductShareSheet(
                context,
                widget.initial!,
              ),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          if (_isEdit && isDesktop)
            TextButton.icon(
              onPressed: _saving ? null : _deleteProduct,
              icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
              label: Text(
                'Eliminar',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
      body: _buildFormBody(),
    );
  }
}
