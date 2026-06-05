import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/aliado_doc_type.dart';
import '../models/profile_document_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'kyc_status_highlight_widgets.dart';

/// Perfil fiscal de la contraparte en un pedido; KYC solo para aliados.
class TransactionRequestCounterpartyProfileSection extends StatefulWidget {
  const TransactionRequestCounterpartyProfileSection({
    super.key,
    required this.profileId,
    required this.partyLabel,
    required this.businessName,
    this.rif,
    this.phone,
    this.estado,
    this.ciudad,
    this.direccion,
    this.fiscalMapsUrl,
    this.logoStoragePath,
    this.kycStatus,
    this.loadApprovedDocuments = true,
  });

  final String profileId;
  final String partyLabel;
  final String? businessName;
  final String? rif;
  final String? phone;
  final String? estado;
  final String? ciudad;
  final String? direccion;
  final String? fiscalMapsUrl;
  final String? logoStoragePath;
  final String? kycStatus;
  final bool loadApprovedDocuments;

  @override
  State<TransactionRequestCounterpartyProfileSection> createState() =>
      _TransactionRequestCounterpartyProfileSectionState();
}

class _TransactionRequestCounterpartyProfileSectionState
    extends State<TransactionRequestCounterpartyProfileSection> {
  List<ProfileDocumentModel> _docs = [];
  bool _loadingDocs = false;
  String? _logoUrl;

  bool get _isImportador =>
      widget.partyLabel.trim().toLowerCase() == 'importador';

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  @override
  void didUpdateWidget(
    covariant TransactionRequestCounterpartyProfileSection oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId ||
        oldWidget.logoStoragePath != widget.logoStoragePath ||
        oldWidget.loadApprovedDocuments != widget.loadApprovedDocuments) {
      _loadExtras();
    }
  }

  Future<void> _loadExtras() async {
    final logoPath = widget.logoStoragePath?.trim();
    if (logoPath != null && logoPath.isNotEmpty) {
      try {
        final url = await SupabaseService.createSignedUrlForProfileLogo(logoPath);
        if (mounted) setState(() => _logoUrl = url);
      } catch (_) {
        if (mounted) setState(() => _logoUrl = null);
      }
    } else if (mounted) {
      setState(() => _logoUrl = null);
    }

    if (!widget.loadApprovedDocuments || _isImportador) {
      if (mounted) setState(() => _docs = []);
      return;
    }

    setState(() => _loadingDocs = true);
    try {
      final docs = await SupabaseService.fetchCounterpartyProfileDocuments(
        widget.profileId,
      );
      if (mounted) setState(() => _docs = docs);
    } catch (_) {
      if (mounted) setState(() => _docs = []);
    } finally {
      if (mounted) setState(() => _loadingDocs = false);
    }
  }

  Future<void> _openDoc(ProfileDocumentModel doc) async {
    try {
      final url = await SupabaseService.createSignedUrlForProfileDocument(
        doc.storagePath,
      );
      final uri = Uri.parse(url);
      if (!mounted) return;
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el documento.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _openMaps() async {
    final url = widget.fiscalMapsUrl?.trim();
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final dirParts = <String>[
      if (widget.direccion?.trim().isNotEmpty == true) widget.direccion!.trim(),
      if (widget.ciudad?.trim().isNotEmpty == true) widget.ciudad!.trim(),
      if (widget.estado?.trim().isNotEmpty == true) widget.estado!.trim(),
    ];
    final dirLine = dirParts.isEmpty ? null : dirParts.join(', ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_logoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _logoUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _logoPlaceholder(),
                    ),
                  )
                else
                  _logoPlaceholder(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.partyLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.brandBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.businessName?.trim().isNotEmpty == true
                            ? widget.businessName!.trim()
                            : '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (!_isImportador) ...[
                        const SizedBox(height: 6),
                        KycAliadoGlobalStatusHighlight(
                          kycStatus: widget.kycStatus,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.rif != null && widget.rif!.trim().isNotEmpty)
              Text(
                'RIF: ${widget.rif!.trim()}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
            if (widget.phone != null && widget.phone!.trim().isNotEmpty)
              Text(
                'Tel: ${widget.phone!.trim()}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
            if (dirLine != null)
              Text(
                'Dirección fiscal: $dirLine',
                style: TextStyle(fontSize: 12.5, height: 1.35, color: Colors.grey.shade800),
              ),
            if (widget.fiscalMapsUrl?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: _openMaps,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Ver ubicación en Maps'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
            if (widget.loadApprovedDocuments && !_isImportador) ...[
              const SizedBox(height: 10),
              Text(
                'Documentación verificada',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 6),
              if (_loadingDocs)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_docs.isEmpty)
                Text(
                  'Sin documentos aprobados visibles en este pedido.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in _docs)
                      ActionChip(
                        avatar: const Icon(Icons.description_outlined, size: 16),
                        label: Text(
                          AliadoDocType.labelEs(d.docType),
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () => _openDoc(d),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.storefront_outlined, color: AppColors.brandBlue),
    );
  }
}
