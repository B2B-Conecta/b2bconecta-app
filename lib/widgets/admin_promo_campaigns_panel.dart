import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/catalog_filters.dart';
import '../models/promo_campaign_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

String _formatPromoDate(DateTime d) {
  final local = d.toLocal();
  return formatEsShortDateTime(
    DateTime(local.year, local.month, local.day),
  ).split(' ').first;
}

/// Subsección admin: CRUD de campañas promocionales E1.2.
class AdminPromoCampaignsPanel extends StatefulWidget {
  const AdminPromoCampaignsPanel({super.key});

  @override
  State<AdminPromoCampaignsPanel> createState() =>
      _AdminPromoCampaignsPanelState();
}

class _AdminPromoCampaignsPanelState extends State<AdminPromoCampaignsPanel> {
  List<PromoCampaignModel> _rows = [];
  List<ImporterOption> _importers = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.fetchPromoCampaignsAdmin(),
        SupabaseService.fetchImporterOptions(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = results[0] as List<PromoCampaignModel>;
        _importers = results[1] as List<ImporterOption>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({PromoCampaignModel? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PromoCampaignEditorSheet(
        existing: existing,
        importers: _importers,
      ),
    );
    if (saved == true) await _bootstrap();
  }

  Future<void> _toggleActive(PromoCampaignModel c) async {
    setState(() => _saving = true);
    try {
      await SupabaseService.updatePromoCampaign(
        id: c.id,
        draft: PromoCampaignModel(
          id: c.id,
          internalTitle: c.internalTitle,
          displayTitle: c.displayTitle,
          campaignType: c.campaignType,
          imageStoragePath: c.imageStoragePath,
          imagePublicUrl: c.imagePublicUrl,
          importadorId: c.importadorId,
          actionType: c.actionType,
          startsAt: c.startsAt,
          endsAt: c.endsAt,
          priority: c.priority,
          isActive: !c.isActive,
          createdAt: c.createdAt,
        ),
      );
      await _bootstrap();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(PromoCampaignModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar campaña'),
        content: Text('¿Eliminar «${c.internalTitle}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.deletePromoCampaign(c.id);
      await _bootstrap();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _bootstrap, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Banners y pop-ups en el catálogo del aliado. Etiqueta «Promoción»; CTA filtra por proveedor.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : () => _openEditor(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _bootstrap,
            child: _rows.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 80),
                      Center(
                        child: Text(
                          'No hay campañas. Cree una para probar en catálogo aliado.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = _rows[i];
                      final imp = _importers
                          .where((o) => o.id == c.importadorId)
                          .map((o) => o.businessName)
                          .firstOrNull;
                      return Card(
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              c.imagePublicUrl,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 56,
                                height: 56,
                                color: AppColors.fieldFill,
                                child: const Icon(Icons.image_outlined),
                              ),
                            ),
                          ),
                          title: Text(
                            c.internalTitle,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${c.isBanner ? 'Banner' : 'Pop-up'} · '
                            '${_formatPromoDate(c.startsAt)} – ${_formatPromoDate(c.endsAt)}\n'
                            'Prioridad ${c.priority}'
                            '${imp != null ? ' · $imp' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              switch (v) {
                                case 'edit':
                                  await _openEditor(existing: c);
                                case 'toggle':
                                  await _toggleActive(c);
                                case 'delete':
                                  await _delete(c);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Text(c.isActive ? 'Desactivar' : 'Activar'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Eliminar'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _PromoCampaignEditorSheet extends StatefulWidget {
  const _PromoCampaignEditorSheet({
    this.existing,
    required this.importers,
  });

  final PromoCampaignModel? existing;
  final List<ImporterOption> importers;

  @override
  State<_PromoCampaignEditorSheet> createState() =>
      _PromoCampaignEditorSheetState();
}

class _PromoCampaignEditorSheetState extends State<_PromoCampaignEditorSheet> {
  late final TextEditingController _internalTitleCtrl;
  late final TextEditingController _displayTitleCtrl;
  late final TextEditingController _priorityCtrl;
  late String _type;
  late String _actionType;
  String? _importadorId;
  late DateTime _startsAt;
  late DateTime _endsAt;
  late bool _isActive;
  String? _imagePath;
  String? _imageUrl;
  String? _uploadError;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _internalTitleCtrl = TextEditingController(text: e?.internalTitle ?? '');
    _displayTitleCtrl = TextEditingController(text: e?.displayTitle ?? '');
    _priorityCtrl = TextEditingController(
      text: '${e?.priority ?? 0}',
    );
    _type = e?.campaignType ?? PromoCampaignModel.typeBanner;
    _actionType = e?.actionType ?? PromoCampaignModel.actionFilterImporter;
    _importadorId = e?.importadorId;
    final now = DateTime.now();
    _startsAt = e?.startsAt ?? DateTime(now.year, now.month, now.day);
    _endsAt = e?.endsAt ??
        DateTime(now.year, now.month, now.day).add(const Duration(days: 30));
    _isActive = e?.isActive ?? true;
    _imagePath = e?.imageStoragePath;
    _imageUrl = e?.imagePublicUrl;
  }

  @override
  void dispose() {
    _internalTitleCtrl.dispose();
    _displayTitleCtrl.dispose();
    _priorityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() {
        _uploadError =
            'No se pudo leer el archivo. En web, elija una imagen JPG/PNG menor a 5 MB.';
      });
      return;
    }

    setState(() {
      _uploading = true;
      _uploadError = null;
    });
    try {
      final ext = (f.extension ?? 'jpg').toLowerCase();
      final uploaded = await SupabaseService.uploadPromoCampaignImage(
        bytes: bytes,
        fileExtension: ext,
        campaignId: widget.existing?.id,
      );
      if (!mounted) return;
      setState(() {
        _imagePath = uploaded.path;
        _imageUrl = uploaded.publicUrl;
        _uploadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('StateError: ', '');
      setState(() => _uploadError = msg);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startsAt : _endsAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startsAt = DateTime(picked.year, picked.month, picked.day);
        if (_endsAt.isBefore(_startsAt)) {
          _endsAt = _startsAt;
        }
      } else {
        _endsAt = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  PromoCampaignModel _buildDraft() {
    final priority = int.tryParse(_priorityCtrl.text.trim()) ?? 0;
    return PromoCampaignModel(
      id: widget.existing?.id ?? '',
      internalTitle: _internalTitleCtrl.text,
      displayTitle: _displayTitleCtrl.text,
      campaignType: _type,
      imageStoragePath: _imagePath ?? '',
      imagePublicUrl: _imageUrl ?? '',
      importadorId: _actionType == PromoCampaignModel.actionFilterImporter
          ? _importadorId
          : null,
      actionType: _actionType,
      startsAt: _startsAt,
      endsAt: _endsAt,
      priority: priority,
      isActive: _isActive,
    );
  }

  Future<void> _save() async {
    if (_internalTitleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique un título interno.')),
      );
      return;
    }
    if (_imageUrl == null || _imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suba una imagen.')),
      );
      return;
    }
    if (_actionType == PromoCampaignModel.actionFilterImporter &&
        (_importadorId == null || _importadorId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un proveedor para el CTA.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final draft = _buildDraft();
      if (widget.existing == null) {
        await SupabaseService.insertPromoCampaign(draft: draft);
      } else {
        await SupabaseService.updatePromoCampaign(
          id: widget.existing!.id,
          draft: draft,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? 'Nueva campaña' : 'Editar campaña',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _internalTitleCtrl,
              decoration: const InputDecoration(
                labelText: 'Título interno (admin)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _displayTitleCtrl,
              decoration: const InputDecoration(
                labelText: 'Texto visible (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: PromoCampaignModel.typeBanner,
                  child: Text('Banner'),
                ),
                DropdownMenuItem(
                  value: PromoCampaignModel.typePopup,
                  child: Text('Pop-up'),
                ),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _actionType,
              decoration: const InputDecoration(
                labelText: 'Acción al tocar',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: PromoCampaignModel.actionFilterImporter,
                  child: Text('Filtrar proveedor'),
                ),
                DropdownMenuItem(
                  value: PromoCampaignModel.actionNone,
                  child: Text('Solo informativa'),
                ),
              ],
              onChanged: (v) => setState(() => _actionType = v ?? _actionType),
            ),
            if (_actionType == PromoCampaignModel.actionFilterImporter) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                value: _importadorId,
                decoration: const InputDecoration(
                  labelText: 'Proveedor',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Seleccione…'),
                  ),
                  ...widget.importers.map(
                    (o) => DropdownMenuItem<String?>(
                      value: o.id,
                      child: Text(o.businessName),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _importadorId = v),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _priorityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Prioridad (mayor = primero)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text('Desde ${_formatPromoDate(_startsAt)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: Text('Hasta ${_formatPromoDate(_endsAt)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text('Activa'),
            ),
            const SizedBox(height: 8),
            if (_imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickImage,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: Text(_imageUrl == null ? 'Subir imagen' : 'Cambiar imagen'),
            ),
            if (_uploadError != null) ...[
              const SizedBox(height: 8),
              Text(
                _uploadError!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar campaña'),
            ),
          ],
        ),
      ),
    );
  }
}
