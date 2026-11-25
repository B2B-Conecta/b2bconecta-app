import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../catalog/catalog_taxonomy.dart';
import '../catalog/combined_minimum.dart';
import '../catalog/part_model.dart';
import 'inventory_service.dart';

String _category(PartModel part) {
  final canonical = canonicalCatalogCategory(part.category);
  return canonical == null
      ? part.category?.trim() ?? ''
      : categoryFamily(canonical);
}

class InventoryCombinedMinimumsScreen extends StatefulWidget {
  const InventoryCombinedMinimumsScreen({super.key, this.suggestedProductId});

  final String? suggestedProductId;

  @override
  State<InventoryCombinedMinimumsScreen> createState() =>
      _InventoryCombinedMinimumsScreenState();
}

class _InventoryCombinedMinimumsScreenState
    extends State<InventoryCombinedMinimumsScreen> {
  late Future<(List<CombinedMinimum>, List<PartModel>)> _data = _load();

  Future<(List<CombinedMinimum>, List<PartModel>)> _load() async {
    final (groups, products) = await (
      InventoryService.fetchCombinedMinimums(),
      InventoryService.fetchCombinedMinimumInventory(),
    ).wait;
    return (groups, products);
  }

  Future<void> _open(
    List<PartModel> products, {
    CombinedMinimum? group,
    PartModel? suggested,
  }) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _CombinedMinimumEditor(
        group: group,
        products: products,
        suggested: suggested,
      ),
    ));
    if (!mounted || changed != true) return;
    setState(() => _data = _load());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mínimos combinables')),
        body: _MinimumPageWidth(
          child: FutureBuilder(
            future: _data,
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || data == null) {
                return Center(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _data = _load()),
                    child: const Text('Reintentar cargar mínimos'),
                  ),
                );
              }
              final (groups, products) = data;
              final suggested = products
                  .where((product) => product.id == widget.suggestedProductId)
                  .firstOrNull;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Permite que tus clientes completen un mínimo de compra '
                    'sumando distintas referencias de tu inventario.',
                  ),
                  if (suggested != null &&
                      suggested.combinedMinimum == null) ...[
                    const SizedBox(height: 16),
                    Text('Referencia para incluir: ${suggested.nombre}'),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: products.isEmpty
                          ? null
                          : () => _open(products, suggested: suggested),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear grupo'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (groups.isEmpty)
                    Text(products.isEmpty
                        ? 'Agrega productos al inventario para crear un grupo.'
                        : 'Aún no tienes grupos configurados.'),
                  for (final group in groups)
                    _groupTile(group, products, suggested),
                ],
              );
            },
          ),
        ),
      );

  Widget _groupTile(
    CombinedMinimum group,
    List<PartModel> products,
    PartModel? suggested,
  ) {
    final members =
        products.where((part) => part.combinedMinimum?.id == group.id);
    final suggestion = suggested != null &&
        suggested.combinedMinimum == null &&
        _category(suggested).isNotEmpty &&
        members.any((p) => _category(p) == _category(suggested));
    final includes = suggested?.combinedMinimum?.id == group.id;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.layers_outlined),
        title: Text(group.name),
        subtitle: Text(
          'Mínimo ${group.units} uds · ${members.length} referencias'
          '${suggestion ? '\nSugerido por categoría' : ''}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(products,
            group: group, suggested: suggestion || includes ? suggested : null),
      ),
    );
  }
}

class _CombinedMinimumEditor extends StatefulWidget {
  const _CombinedMinimumEditor({
    required this.group,
    required this.products,
    required this.suggested,
  });

  final CombinedMinimum? group;
  final List<PartModel> products;
  final PartModel? suggested;

  @override
  State<_CombinedMinimumEditor> createState() => _CombinedMinimumEditorState();
}

class _CombinedMinimumEditorState extends State<_CombinedMinimumEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.group?.name);
  late final _units =
      TextEditingController(text: (widget.group?.units ?? 5).toString());
  late final _selected = {
    for (final part in widget.products)
      if (widget.group != null && part.combinedMinimum?.id == widget.group!.id)
        part.id,
  };
  String _query = '';
  late String? _categoryFilter = switch (widget.suggested) {
    final product? when _category(product).isNotEmpty => _category(product),
    _ => null,
  };
  bool _showSelected = false;
  bool _saving = false;
  String? _error;

  bool _eligible(PartModel part) =>
      part.combinedMinimum == null ||
      part.combinedMinimum?.id == widget.group?.id;

  @override
  void dispose() {
    _name.dispose();
    _units.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    if (!remove && !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await InventoryService.saveCombinedMinimum(
        id: widget.group?.id,
        name: remove ? null : _name.text.trim(),
        units: remove ? null : int.parse(_units.text),
        productIds: remove ? const {} : _selected,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is PostgrestException && e.code == '22023'
            ? e.message
            : 'No se pudo guardar el grupo. Intenta de nuevo.';
      });
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: const Text(
          'Las referencias volverán a usar su mínimo individual.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Conservar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) await _save(remove: true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = {
      for (final product in widget.products)
        if (_category(product).isNotEmpty) _category(product),
    }.toList()
      ..sort();
    final categoryProducts = [
      for (final product in widget.products)
        if (_category(product) == _categoryFilter && _eligible(product))
          product.id,
    ];
    final visible = widget.products.where((product) {
      if (_showSelected && !_selected.contains(product.id)) return false;
      if (!_showSelected &&
          _categoryFilter != null &&
          _category(product) != _categoryFilter) return false;
      return '${product.nombre} ${product.sku ?? ''}'
          .toLowerCase()
          .contains(_query);
    }).toList();
    final allSelected = categoryProducts.every(_selected.contains);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group == null ? 'Crear grupo' : 'Editar grupo'),
        actions: [
          if (widget.group != null)
            IconButton(
              tooltip: 'Eliminar grupo',
              onPressed: _saving ? null : _remove,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _MinimumPageWidth(
        child: Form(
          key: _form,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        enabled: !_saving,
                        maxLength: 60,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del grupo',
                          hintText: 'Ejemplo: Cauchos',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Escribe un nombre'
                                : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _units,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Mínimo de unidades',
                          helperText:
                              'Se suman las unidades de las referencias elegidas.',
                          helperMaxLines: 2,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) {
                          final units = int.tryParse(value ?? '');
                          return units == null ||
                                  units < 2 ||
                                  units > 2147483647
                              ? 'Indica un número válido de 2 o más'
                              : null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('Referencias del grupo',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (widget.suggested case final suggested?)
                        if (_eligible(suggested) &&
                            !_selected.contains(suggested.id))
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => setState(
                                      () => _selected.add(suggested.id)),
                              icon: const Icon(Icons.add),
                              label: Text('Incluir ${suggested.nombre}'),
                            ),
                          ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _categoryFilter ?? '',
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Categoría'),
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Todas las categorías')),
                          for (final category in categories)
                            DropdownMenuItem(
                                value: category, child: Text(category)),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                  _categoryFilter = value == '' ? null : value;
                                  _showSelected = false;
                                }),
                      ),
                      if (categoryProducts.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => allSelected
                                    ? _selected.removeAll(categoryProducts)
                                    : _selected.addAll(categoryProducts)),
                            child: Text(allSelected
                                ? 'Quitar selección de la categoría'
                                : 'Seleccionar categoría (${categoryProducts.length})'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Buscar por nombre o SKU',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                      ),
                      CheckboxListTile(
                        value: _showSelected,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                setState(() => _showSelected = value ?? false),
                        title: Text('Ver seleccionadas (${_selected.length})'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (visible.isEmpty)
                        const Text('No hay referencias para mostrar.'),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final part = visible[index];
                    final available = _eligible(part);
                    final details = [
                      if (part.sku?.isNotEmpty == true) part.sku!,
                      if (!part.isActive) 'Pausada',
                      if (!available) 'Grupo: ${part.combinedMinimum!.name}',
                      if (part.id == widget.suggested?.id && available)
                        'Referencia sugerida',
                    ];
                    return CheckboxListTile(
                      value: _selected.contains(part.id),
                      title: Text(part.nombre),
                      subtitle:
                          details.isEmpty ? null : Text(details.join(' · ')),
                      contentPadding: EdgeInsets.zero,
                      onChanged: _saving || !available
                          ? null
                          : (checked) => setState(() => checked == true
                              ? _selected.add(part.id)
                              : _selected.remove(part.id)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _MinimumPageWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                FilledButton(
                  onPressed: _saving || _selected.isEmpty ? null : _save,
                  child: Text(_saving
                      ? 'Guardando…'
                      : 'Guardar grupo (${_selected.length})'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimumPageWidth extends StatelessWidget {
  const _MinimumPageWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: child,
        ),
      );
}
