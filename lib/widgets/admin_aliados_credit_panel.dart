import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/aliado_doc_type.dart';
import '../models/kyc_status.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Admin: lista de aliados con edición de `credit_limit`.
class AdminAliadosCreditPanel extends StatefulWidget {
  const AdminAliadosCreditPanel({super.key});

  @override
  State<AdminAliadosCreditPanel> createState() =>
      _AdminAliadosCreditPanelState();
}

class _AdminAliadosCreditPanelState extends State<AdminAliadosCreditPanel> {
  List<ProfileModel> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.fetchAliadoProfilesForAdmin();
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            Center(
              child: Text(
                'No hay aliados registrados.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final p = _rows[i];
          return _AliadoCreditCard(
            key: ValueKey<String>(p.id),
            profile: p,
            onSaved: _load,
          );
        },
      ),
    );
  }
}

class _AliadoCreditCard extends StatefulWidget {
  const _AliadoCreditCard({
    super.key,
    required this.profile,
    required this.onSaved,
  });

  final ProfileModel profile;
  final Future<void> Function() onSaved;

  @override
  State<_AliadoCreditCard> createState() => _AliadoCreditCardState();
}

class _AliadoCreditCardState extends State<_AliadoCreditCard> {
  late final TextEditingController _limitCtrl;
  bool _saving = false;
  bool _busyKyc = false;

  @override
  void initState() {
    super.initState();
    final lim = widget.profile.creditLimit;
    _limitCtrl = TextEditingController(
      text: lim != null ? lim.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _limitCtrl.text.trim().replaceAll(',', '.');
    final v = double.tryParse(raw);
    if (v == null || v < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce un monto numérico válido (≥ 0).'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.adminSetAliadoCreditLimit(
        aliadoId: widget.profile.id,
        creditLimit: v,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Límite de crédito actualizado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setKyc(String status) async {
    setState(() => _busyKyc = true);
    try {
      await SupabaseService.adminSetAliadoKycStatus(
        aliadoId: widget.profile.id,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == KycStatus.aprobado
                ? 'KYC aprobado.'
                : 'Estado KYC actualizado.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyKyc = false);
    }
  }

  Future<void> _openDocs() async {
    try {
      final docs = await SupabaseService.fetchProfileDocumentsForAliado(
        widget.profile.id,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Documentos cargados',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Sin archivos.'),
                )
              else
                SizedBox(
                  height: 320,
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(AliadoDocType.labelEs(d.docType)),
                        subtitle: Text(d.fileName ?? d.storagePath),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () async {
                          final url = await SupabaseService
                              .createSignedUrlForProfileDocument(
                            d.storagePath,
                          );
                          final uri = Uri.parse(url);
                          if (ctx.mounted && await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.profile.businessName ?? '—').trim();
    final rif = (widget.profile.rif ?? '—').trim();

    return Material(
      color: Colors.white,
      borderRadius: AppDecorations.radius12,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppDecorations.radius12,
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'RIF: $rif',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Score: ${widget.profile.creditScore ?? '—'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              'KYC: ${KycStatus.labelEs(widget.profile.kycStatus)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.brandBlue,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _busyKyc
                      ? null
                      : () => _setKyc(KycStatus.aprobado),
                  child: const Text('Aprobar KYC'),
                ),
                FilledButton.tonal(
                  onPressed: _busyKyc
                      ? null
                      : () => _setKyc(KycStatus.rechazado),
                  child: const Text('Rechazar'),
                ),
                OutlinedButton(
                  onPressed: _busyKyc
                      ? null
                      : () => _setKyc(KycStatus.pendiente),
                  child: const Text('Pendiente'),
                ),
                OutlinedButton(
                  onPressed: _busyKyc ? null : _openDocs,
                  child: const Text('Ver archivos'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _limitCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Límite de crédito (USD)',
                hintText: 'Ej: 50000.00',
                filled: true,
                fillColor: AppColors.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: AppDecorations.radius12,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar límite'),
            ),
          ],
        ),
      ),
    );
  }
}
