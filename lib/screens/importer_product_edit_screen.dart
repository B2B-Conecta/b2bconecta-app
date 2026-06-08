import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/part_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/product_volume_tiers.dart';
import '../widgets/product_validated_orders_list.dart';
import '../widgets/importer_product_commercial_terms_section.dart';
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

class _ImporterProductEditScreenState extends State<ImporterProductEditScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TabController _tabController;
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
  late final TextEditingController _imageController;
  bool _isActive = true;
  bool _hasWarranty = false;
  bool _saving = false;
  bool _pagoSoloDivisas = false;
  Uint8List? _pickedImageBytes;
  String? _pickedImageExt;

  bool get _isEdit => widget.initial != null && widget.initial!.id.isNotEmpty;

  static String _extensionFromXFile(XFile file) {
    var name = file.name;
    if (name.isEmpty) name = file.path;
    if (!name.contains('.')) return 'jpeg';
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'jpg') return 'jpeg';
    return ext;
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera && kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La cámara no está disponible en la versión web.'),
        ),
      );
      return;
    }
    try {
      final x = await ImagePicker().pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageExt = _extensionFromXFile(x);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo obtener la imagen: $e')),
      );
    }
  }

  void _clearPickedImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageExt = null;
    });
  }

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
    _imageController = TextEditingController(text: p?.imagenUrl ?? '');
    _isActive = p?.isActive ?? true;
    _hasWarranty = p?.hasWarranty ?? false;
    _tabController = TabController(
      length: _isEdit ? 2 : 1,
      vsync: this,
    );
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
    _tabController.dispose();
    _skuController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _salePriceController.dispose();
    _usdPaymentDiscountController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    _compatController.dispose();
    _imageController.dispose();
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
      var imageUrl = _imageController.text.trim();
      if (_pickedImageBytes != null && _pickedImageExt != null) {
        imageUrl = await SupabaseService.uploadProductImage(
          bytes: _pickedImageBytes!,
          fileExtension: _pickedImageExt!,
          productId: _isEdit ? widget.initial!.id : null,
        );
        if (mounted) {
          setState(() {
            _imageController.text = imageUrl;
            _pickedImageBytes = null;
            _pickedImageExt = null;
          });
        }
      }

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
          imageUrl: imageUrl,
          isActive: _isActive,
          hasWarranty: _hasWarranty,
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
          imageUrl: imageUrl,
          isActive: _isActive,
          hasWarranty: _hasWarranty,
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

  Widget _buildFormBody() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          SwitchTheme(
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
                  color: _isActive
                      ? AppColors.successGreen
                      : Colors.orange.shade800,
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
          ),
          const SizedBox(height: 8),
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
            onChanged:
                _saving ? null : (v) => setState(() => _hasWarranty = v),
          ),
          const SizedBox(height: 12),
          const Text(
            'Imagen (opcional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: const Text('Galería'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving || kIsWeb
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                  label: const Text('Cámara'),
                ),
              ),
            ],
          ),
          if (_pickedImageBytes != null) ...[
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: AppDecorations.radius12,
                  child: Image.memory(
                    _pickedImageBytes!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _saving ? null : _clearPickedImage,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const Text(
              'Se subirá al guardar (requiere bucket product-images en Supabase).',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _imageController,
            decoration: _dec(
              'URL imagen (opcional)',
              hint: 'O pega un enlace si ya está alojada',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_isEdit ? 'Guardar cambios' : 'Crear producto'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceTinted,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEdit ? 'Editar producto' : 'Añadir producto'),
        bottom: _isEdit
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.brandBlue,
                tabs: const [
                  Tab(text: 'Datos'),
                  Tab(text: 'Pedidos validados'),
                ],
              )
            : null,
        actions: [
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
      body: _isEdit
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildFormBody(),
                ProductValidatedOrdersList(
                  productId: widget.initial!.id,
                ),
              ],
            )
          : _buildFormBody(),
    );
  }
}
