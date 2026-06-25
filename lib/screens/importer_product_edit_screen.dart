import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/part_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_breakpoints.dart';
import '../utils/product_volume_tiers.dart';
import '../widgets/importer_product_commercial_terms_section.dart';
import '../widgets/product_custom_fields_section.dart';
import '../widgets/product_image_gallery_editor.dart';
import '../widgets/product_usd_payment_discount_field.dart';

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
  late final TextEditingController _salePriceController;
  late final TextEditingController _usdPaymentDiscountController;
  late final TextEditingController _stockController;
  List<ProductVolumeTier> _volumeTiers = [];
  late final TextEditingController _categoryController;
  late final TextEditingController _compatController;
  List<ProductImageEditSlot> _imageSlots = [];
  bool _isActive = true;
  bool _hasWarranty = false;
  bool _saving = false;
  bool _pagoSoloDivisas = false;
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
    _salePriceController = TextEditingController(
      text: p?.salePriceUsd != null ? p!.salePriceUsd!.toStringAsFixed(2) : '',
    );
    final usdPct = parseUsdPaymentDiscountPct(p?.discountRules);
    _usdPaymentDiscountController = TextEditingController(
      text: usdPct != null ? usdPct.toStringAsFixed(1) : '',
    );
    _volumeTiers = p?.volumeTiers ?? [];
    _stockController = TextEditingController(
      text: p != null ? '${p.stock}' : '',
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
    _loadImporterPagoPolicy();
  }

  Future<void> _loadImporterPagoPolicy() async {
    try {
      final profile = await SupabaseService.fetchMyProfile();
      if (!mounted) return;
      setState(() => _pagoSoloDivisas = profile?.pagoSoloDivisas ?? false);
    } catch (_) {}
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _salePriceController.dispose();
    _usdPaymentDiscountController.dispose();
    _stockController.dispose();
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
    final saleRaw = _salePriceController.text.trim();
    double? salePrice;
    if (saleRaw.isNotEmpty) {
      salePrice = double.tryParse(saleRaw.replaceAll(',', '.'));
      if (salePrice == null || salePrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Precio oferta inválido.')),
        );
        return;
      }
      if (salePrice >= price) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El precio oferta debe ser menor que el precio lista.',
            ),
          ),
        );
        return;
      }
    }
    final usdPctRaw = _pagoSoloDivisas
        ? ''
        : _usdPaymentDiscountController.text.trim();
    double? usdPaymentDiscountPct;
    if (usdPctRaw.isNotEmpty) {
      usdPaymentDiscountPct = parseUsdPaymentDiscountPctField(usdPctRaw);
      if (usdPaymentDiscountPct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Descuento línea USD inválido: use un % entre 0 y 100.',
            ),
          ),
        );
        return;
      }
    }
    final discountRules = buildProductDiscountRules(
      volumeTiers: _volumeTiers,
      usdPaymentDiscountPct: usdPaymentDiscountPct,
    );

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
          discountRules: discountRules,
          clearDiscountRules: discountRules == null,
          stock: stock,
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
          discountRules: discountRules,
          stock: stock,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Eliminar «$name» del inventario? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await SupabaseService.deleteProduct(productId: widget.initial!.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
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

  Widget _buildVisibilitySwitch() {
    return SwitchTheme(
      data: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade300;
          }
          return AppColors.brandOrange.withOpacity(0.85);
        }),
        trackOutlineWidth: WidgetStateProperty.all(1.8),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade400;
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.brandOrange;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.brandOrange.withOpacity(0.22);
          }
          return Colors.transparent;
        }),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          _isActive
              ? 'Visible en catálogo (Modo pausa off)'
              : 'Producto en pausa (oculto para aliados)',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _isActive ? AppColors.successGreen : Colors.orange.shade800,
          ),
        ),
        subtitle: Text(
          _isActive
              ? 'Los aliados pueden ver este producto.'
              : 'Actívelo cuando quiera volver a publicarlo.',
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
          controller: _descController,
          decoration: _dec('Descripción'),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _priceController,
          decoration: _dec('Precio lista (USD)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
        ),
        const SizedBox(height: 16),
        ImporterProductCommercialTermsSection(
          salePriceController: _salePriceController,
          usdPaymentDiscountController: _usdPaymentDiscountController,
          volumeTiers: _volumeTiers,
          onVolumeTiersChanged: (t) => setState(() => _volumeTiers = t),
          enabled: !_saving,
          showUsdPaymentDiscount: !_pagoSoloDivisas,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _stockController,
          decoration: _dec('Stock'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
        const SizedBox(height: 20),
        ProductCustomFieldsEditor(
          initial: _customFields,
          enabled: !_saving,
          onChanged: (fields) => _customFields = fields,
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
                              _buildVisibilitySwitch(),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Producto con garantía',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: const Text(
                                  'El aliado verá el sello de garantía en el catálogo.',
                                  style: TextStyle(fontSize: 12),
                                ),
                                value: _hasWarranty,
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _hasWarranty = v),
                              ),
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
          _buildVisibilitySwitch(),
          const SizedBox(height: 8),
          _buildMainFields(),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Producto con garantía',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Si está activo, el aliado verá el sello de garantía en el catálogo.',
              style: TextStyle(fontSize: 12),
            ),
            value: _hasWarranty,
            onChanged: _saving ? null : (v) => setState(() => _hasWarranty = v),
          ),
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
