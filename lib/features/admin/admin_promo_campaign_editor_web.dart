part of 'admin_promo_campaigns_panel.dart';

/// Formulario de campaña solo en el diálogo de escritorio.
extension _PromoCampaignEditorDesktop on _PromoCampaignEditorSheetState {
  Widget buildDesktopPromoEditor(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final title = widget.existing == null ? 'Nueva campaña' : 'Editar campaña';
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 680.0;
        return SizedBox(
          height: height,
          child: _editorBody(theme, title),
        );
      },
    );
  }

  Widget _editorBody(B2BThemeExtension theme, String title) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(theme, title),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _leftColumn(theme)),
                VerticalDivider(width: 1, color: theme.borderSubtle),
                Expanded(child: _rightColumn(theme)),
              ],
            ),
          ),
          _footer(theme),
        ],
    );
  }

  Widget _header(B2BThemeExtension theme, String title) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Datos, vigencia y creatividades de la valla.',
                    style: TextStyle(fontSize: 12.5, color: theme.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: _saving ? null : _close,
              icon: LucideIcon(
                LucideGlyph.close,
                size: 18,
                color: theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(B2BThemeExtension theme) {
    final cancelBorder = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: theme.borderSubtle),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.dialogSurface,
        border: Border(top: BorderSide(color: theme.borderSubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: _saving ? null : _close,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.textPrimary,
                minimumSize: const Size(120, 40),
                side: BorderSide(color: theme.borderSubtle),
                shape: cancelBorder,
              ),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _saving || _uploading ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: B2BBrandHero.start,
                foregroundColor: B2BBrandHero.foreground,
                disabledBackgroundColor: B2BBrandHero.start.withOpacity(0.45),
                disabledForegroundColor: B2BBrandHero.foreground,
                minimumSize: const Size(140, 40),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: Text(_saving ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leftColumn(B2BThemeExtension theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 18, 20),
      children: [
        _section(theme, 'Información general'),
        TextField(
          controller: _internalTitleCtrl,
          style: TextStyle(color: theme.textPrimary, fontSize: 14),
          decoration: _field(theme, 'Título interno (admin)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _displayTitleCtrl,
          style: TextStyle(color: theme.textPrimary, fontSize: 14),
          decoration: _field(theme, 'Texto visible (opcional)'),
        ),
        const SizedBox(height: 16),
        _section(theme, 'Segmentación y acción'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _sponsorField(theme)),
            const SizedBox(width: 10),
            Expanded(child: _typeField(theme)),
          ],
        ),
        if (_isThirdParty) ...[
          const SizedBox(height: 10),
          _audienceField(theme),
          const SizedBox(height: 10),
          TextField(
            controller: _advertiserNameCtrl,
            style: TextStyle(color: theme.textPrimary, fontSize: 14),
            decoration: _field(
              theme,
              'Nombre del anunciante',
              hint: 'Ej. Agencia Rápido Express',
            ),
          ),
        ],
        const SizedBox(height: 10),
        _actionField(theme),
        if (_needsImporter) ...[
          const SizedBox(height: 10),
          _importerField(theme),
        ],
        ..._productFields(theme),
        if (_isThirdParty &&
            _actionType == PromoCampaignModel.actionExternalUrl) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _externalUrlCtrl,
            keyboardType: TextInputType.url,
            style: TextStyle(color: theme.textPrimary, fontSize: 14),
            decoration: _field(theme, 'URL externa', hint: 'https://…'),
          ),
        ],
        const SizedBox(height: 16),
        _section(theme, 'Programación y estado'),
        Row(
          children: [
            Expanded(child: _dateButton(theme, start: true)),
            const SizedBox(width: 10),
            Expanded(child: _dateButton(theme, start: false)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _priorityCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: theme.textPrimary, fontSize: 14),
                decoration: _field(theme, 'Prioridad (mayor = primero)'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _activeCard(theme)),
          ],
        ),
      ],
    );
  }

  Widget _rightColumn(B2BThemeExtension theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 22, 20),
      children: [
        _section(theme, 'Creatividades'),
        _creativeCard(
          theme,
          title: 'Banner escritorio',
          spec: '1320 × 493 px',
          note: 'Al subir, la imagen se ajusta sola a 1320 × 493 px.',
          aspect: PromoBannerSpec.webFrameAspect,
          url: _imageUrl,
          sizeLabel: _imageWidth != null && _imageHeight != null
              ? '$_imageWidth×$_imageHeight px'
              : null,
          buttonLabel: _imageUrl == null
              ? 'Subir escritorio'
              : 'Cambiar escritorio',
          onUpload: _uploading || _saving ? null : () => _pickImage(),
          onDownload: _imageUrl == null ||
                  _uploading ||
                  _saving ||
                  _downloadingCreative != null
              ? null
              : () => _downloadCreative(_imageUrl!, mobile: false),
          downloading: _downloadingCreative == 'desktop',
          emptyGlyph: LucideGlyph.image,
        ),
        const SizedBox(height: 14),
        _creativeCard(
          theme,
          title: 'Banner móvil',
          spec: '1500 × 500 px · proporción 3:1 · opcional',
          note:
              'Opcional. Al subir, se ajusta a 1500 × 500 px. Si no se sube, se usará la imagen de escritorio.',
          aspect: PromoBannerSpec.mobileAspect,
          url: _mobileImageUrl,
          sizeLabel: _mobileImageWidth != null && _mobileImageHeight != null
              ? '$_mobileImageWidth×$_mobileImageHeight px'
              : null,
          buttonLabel: _mobileImageUrl == null
              ? 'Subir móvil'
              : 'Cambiar móvil',
          onUpload:
              _uploading || _saving ? null : () => _pickImage(mobile: true),
          onDownload: _mobileImageUrl == null ||
                  _uploading ||
                  _saving ||
                  _downloadingCreative != null
              ? null
              : () => _downloadCreative(_mobileImageUrl!, mobile: true),
          downloading: _downloadingCreative == 'mobile',
          onClear: _mobileImageUrl == null || _uploading || _saving
              ? null
              : () => _desktopSet(() {
                    _mobileImagePath = null;
                    _mobileImageUrl = null;
                    _mobileImageWidth = null;
                    _mobileImageHeight = null;
                  }),
          emptyGlyph: LucideGlyph.smartphone,
        ),
        if (_uploadError != null) ...[
          const SizedBox(height: 10),
          Text(
            _uploadError!,
            style: TextStyle(
              color: theme.warningFg,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _section(B2BThemeExtension theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: theme.textSecondary,
        ),
      ),
    );
  }

  InputDecoration _field(
    B2BThemeExtension theme,
    String label, {
    String? hint,
    String? helper,
  }) {
    final radius = BorderRadius.circular(10);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.borderSubtle),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 3,
      isDense: true,
      filled: true,
      fillColor: theme.inputFill,
      labelStyle: TextStyle(color: theme.textSecondary, fontSize: 13),
      floatingLabelStyle: const TextStyle(
        color: B2BBrandHero.start,
        fontWeight: FontWeight.w600,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: B2BBrandHero.start, width: 1.4),
      ),
    );
  }

  Widget _sponsorField(B2BThemeExtension theme) {
    return DropdownButtonFormField<String>(
      value: _sponsorType,
      isExpanded: true,
      decoration: _field(theme, 'Patrocinador'),
      items: [
        DropdownMenuItem(
          value: PromoCampaignModel.sponsorImportador,
          child: _promoDropdownLabel('Proveedor (catálogo tienda minorista)'),
        ),
        DropdownMenuItem(
          value: PromoCampaignModel.sponsorTercero,
          child: _promoDropdownLabel('Tercero (valla publicitaria)'),
        ),
      ],
      onChanged: _onSponsorTypeChanged,
    );
  }

  Widget _typeField(B2BThemeExtension theme) {
    return DropdownButtonFormField<String>(
      value: _type,
      isExpanded: true,
      decoration: _field(theme, 'Tipo'),
      items: [
        DropdownMenuItem(
          value: PromoCampaignModel.typeBanner,
          child: _promoDropdownLabel('Banner'),
        ),
        DropdownMenuItem(
          value: PromoCampaignModel.typePopup,
          child: _promoDropdownLabel('Pop-up'),
        ),
      ],
      onChanged: (v) => _desktopSet(() => _type = v ?? _type),
    );
  }

  Widget _audienceField(B2BThemeExtension theme) {
    return DropdownButtonFormField<String>(
      value: _audience,
      isExpanded: true,
      decoration: _field(theme, 'Audiencia'),
      items: [
        DropdownMenuItem(
          value: PromoCampaignModel.audienceAliado,
          child: _promoDropdownLabel('Solo tiendas minoristas'),
        ),
        DropdownMenuItem(
          value: PromoCampaignModel.audienceImportador,
          child: _promoDropdownLabel('Solo importadores'),
        ),
        DropdownMenuItem(
          value: PromoCampaignModel.audienceAmbos,
          child: _promoDropdownLabel('Tiendas minoristas e importadores'),
        ),
      ],
      onChanged: (v) => _desktopSet(() => _audience = v ?? _audience),
    );
  }

  Widget _actionField(B2BThemeExtension theme) {
    return DropdownButtonFormField<String>(
      value: _actionType,
      isExpanded: true,
      decoration: _field(theme, 'Acción al tocar'),
      items: _isThirdParty
          ? [
              DropdownMenuItem(
                value: PromoCampaignModel.actionExternalUrl,
                child: _promoDropdownLabel('Abrir enlace externo'),
              ),
              DropdownMenuItem(
                value: PromoCampaignModel.actionNone,
                child: _promoDropdownLabel('Solo informativa'),
              ),
            ]
          : [
              DropdownMenuItem(
                value: PromoCampaignModel.actionFilterImporter,
                child: _promoDropdownLabel('Filtrar proveedor'),
              ),
              DropdownMenuItem(
                value: PromoCampaignModel.actionOpenStore,
                child: _promoDropdownLabel('Vitrina del proveedor'),
              ),
              DropdownMenuItem(
                value: PromoCampaignModel.actionOpenProduct,
                child: _promoDropdownLabel('Producto(s) específico(s)'),
              ),
              DropdownMenuItem(
                value: PromoCampaignModel.actionNone,
                child: _promoDropdownLabel('Solo informativa'),
              ),
            ],
      onChanged: (v) {
        _desktopSet(() {
          _actionType = v ?? _actionType;
          if (_actionType != PromoCampaignModel.actionOpenProduct) {
            _selectedProductIds.clear();
            _products = const [];
          }
        });
        if (_actionType == PromoCampaignModel.actionOpenProduct) {
          _loadPublishedProducts();
        }
      },
    );
  }

  Widget _importerField(B2BThemeExtension theme) {
    return DropdownButtonFormField<String?>(
      value: _importadorId,
      isExpanded: true,
      decoration: _field(theme, 'Proveedor'),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Seleccione…'),
        ),
        if (_importadorId != null &&
            _importadorId!.isNotEmpty &&
            !widget.importers.any((o) => o.id == _importadorId))
          DropdownMenuItem<String?>(
            value: _importadorId,
            child: _promoDropdownLabel('Proveedor asignado'),
          ),
        ...widget.importers.map(
          (o) => DropdownMenuItem<String?>(
            value: o.id,
            child: _promoDropdownLabel(o.businessName),
          ),
        ),
      ],
      onChanged: (v) {
        final changed = v != _importadorId;
        _desktopSet(() {
          _importadorId = v;
          if (changed) _selectedProductIds.clear();
        });
        if (_actionType == PromoCampaignModel.actionOpenProduct) {
          _loadPublishedProducts();
        }
      },
    );
  }

  List<Widget> _productFields(B2BThemeExtension theme) {
    if (_isThirdParty || _actionType != PromoCampaignModel.actionOpenProduct) {
      return const [];
    }
    return [
      const SizedBox(height: 10),
      if (_productsLoading)
        const LinearProgressIndicator(minHeight: 2, color: B2BBrandHero.start)
      else
        InputDecorator(
          decoration: _field(
            theme,
            _selectedProductIds.isEmpty
                ? 'Productos publicados'
                : 'Productos publicados (${_selectedProductIds.length})',
            helper: _importadorId == null
                ? 'Seleccione un proveedor'
                : 'Puede marcar uno o varios.',
          ),
          child: _importadorId == null || _products.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _importadorId == null
                        ? 'Seleccione un proveedor…'
                        : 'No hay productos publicados para este proveedor.',
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                  ),
                )
              : SizedBox(
                  height: 220,
                  child: PagedItems(
                    items: _products,
                    itemBuilder: (p) {
                      final selected = _selectedProductIds.contains(p.id);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: selected,
                            activeColor: B2BBrandHero.start,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              _productOptionLabel(p),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textPrimary,
                              ),
                            ),
                            onChanged: (v) {
                              _desktopSet(() {
                                if (v == true) {
                                  _selectedProductIds.add(p.id);
                                  _pctCtrlFor(p.id);
                                } else {
                                  _selectedProductIds.remove(p.id);
                                }
                              });
                            },
                          ),
                          if (selected)
                            Padding(
                              padding: const EdgeInsets.only(left: 40, bottom: 8),
                              child: TextField(
                                controller: _pctCtrlFor(p.id),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: TextStyle(color: theme.textPrimary),
                                decoration: _field(
                                  theme,
                                  '% de este producto',
                                  hint: 'Vacío usa el general',
                                  helper: '0 lo deja sin descuento de esta valla.',
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
        ),
      const SizedBox(height: 10),
      TextField(
        controller: _discountPctCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: theme.textPrimary, fontSize: 14),
        decoration: _field(
          theme,
          'Descuento % en productos (opcional)',
          hint: 'Ej. 5',
          helper:
              'Si un producto no tiene el suyo, usa este. 0 en un producto lo deja sin descuento.',
        ),
      ),
    ];
  }

  Widget _dateButton(B2BThemeExtension theme, {required bool start}) {
    final label = start ? 'Desde' : 'Hasta';
    final value = _formatPromoDate(start ? _startsAt : _endsAt);
    return OutlinedButton(
      onPressed: () => _pickDate(isStart: start),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        side: BorderSide(color: theme.borderSubtle),
        backgroundColor: theme.inputFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        children: [
          LucideIcon(LucideGlyph.calendar, size: 16, color: theme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label $value',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeCard(B2BThemeExtension theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado',
                    style: TextStyle(fontSize: 12, color: theme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: _isActive ? theme.successBg : theme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        _isActive ? 'Activa' : 'Inactiva',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isActive ? theme.successFg : theme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isActive,
              activeTrackColor: B2BBrandHero.start,
              onChanged: (v) => _desktopSet(() => _isActive = v),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadCreative(String url, {required bool mobile}) async {
    if (_downloadingCreative != null) return;
    final slot = mobile ? 'mobile' : 'desktop';
    _desktopSet(() => _downloadingCreative = slot);
    final fileName = _creativeDownloadName(mobile: mobile, url: url);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('status');
      }
      final ext = storedFileExtension(fileName, url);
      final safeExt = ext.isEmpty ? 'jpg' : ext;
      final result = await saveBytesForExport(
        name: storedFileBaseName(fileName, safeExt),
        bytes: response.bodyBytes,
        ext: safeExt,
        mimeType: storedFileMimeType(safeExt),
      );
      if (!mounted || result == ExcelExportResult.cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen descargada.')),
      );
    } catch (_) {
      try {
        await downloadStoredFile(url, fileName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen descargada.')),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo descargar la imagen.')),
        );
      }
    } finally {
      if (mounted) _desktopSet(() => _downloadingCreative = null);
    }
  }

  String _creativeDownloadName({required bool mobile, required String url}) {
    final raw = _internalTitleCtrl.text.trim();
    final slug = raw
        .replaceAll(RegExp(r'[\\/]+'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final slot = mobile ? 'movil' : 'escritorio';
    final ext = storedFileExtension('', url);
    final safeExt = ext.isEmpty ? 'jpg' : ext;
    final base = slug.isEmpty ? 'valla' : slug;
    return 'valla-$slot-$base.$safeExt';
  }

  Widget _creativeCard(
    B2BThemeExtension theme, {
    required String title,
    required String spec,
    required String note,
    required double aspect,
    required String? url,
    required String? sizeLabel,
    required String buttonLabel,
    required VoidCallback? onUpload,
    required LucideGlyph emptyGlyph,
    VoidCallback? onDownload,
    bool downloading = false,
    VoidCallback? onClear,
  }) {
    final hasImage = url != null && url.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(spec, style: TextStyle(fontSize: 12, color: theme.textSecondary)),
            if (sizeLabel != null)
              Text(
                sizeLabel,
                style: TextStyle(fontSize: 12, color: theme.textMuted),
              ),
            const SizedBox(height: 8),
            if (hasImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: ColoredBox(
                    color: theme.inputFill,
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          'No se pudo cargar la vista previa.',
                          style: TextStyle(color: theme.textSecondary, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              CustomPaint(
                painter: _DashedRRectPainter(color: theme.borderStrong),
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: Center(
                    child: LucideIcon(emptyGlyph, size: 18, color: theme.textMuted),
                  ),
                ),
              ),
            if (!hasImage) ...[
              const SizedBox(height: 6),
              Text(
                note,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: theme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onUpload,
                  icon: _uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: B2BBrandHero.start,
                          ),
                        )
                      : const LucideIcon(
                          LucideGlyph.image,
                          size: 16,
                          color: B2BBrandHero.start,
                        ),
                  label: Text(buttonLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: B2BBrandHero.start,
                    side: const BorderSide(color: B2BBrandHero.start),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                if (hasImage)
                  OutlinedButton.icon(
                    onPressed: onDownload,
                    icon: downloading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.textPrimary,
                            ),
                          )
                        : LucideIcon(
                            LucideGlyph.download,
                            size: 16,
                            color: theme.textPrimary,
                          ),
                    label: const Text('Descargar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textPrimary,
                      side: BorderSide(color: theme.borderStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
            if (onClear != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onClear,
                  child: Text(
                    'Usar imagen de escritorio',
                    style: TextStyle(color: theme.textSecondary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(10),
        ),
      );
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
