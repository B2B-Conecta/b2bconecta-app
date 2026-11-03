import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica_badge.dart';
import 'cart_service.dart';

/// Resultado del diálogo de destino: se devuelve al confirmar (no al cancelar).
class DeliveryDestinationResult {
  const DeliveryDestinationResult({
    required this.useProfile,
    this.texto,
    this.mapsUrl,
  });

  final bool useProfile;
  final String? texto;
  final String? mapsUrl;
}

/// Destino: dirección fiscal del perfil, o formulario de ubicación alterna.
class DeliveryDestinationDialog extends StatefulWidget {
  const DeliveryDestinationDialog(
      {super.key, required this.profile, required this.paymentSummary});

  final ProfileModel profile;

  final String paymentSummary;

  @override
  State<DeliveryDestinationDialog> createState() =>
      _DeliveryDestinationDialogState();
}

class _DeliveryDestinationDialogState extends State<DeliveryDestinationDialog> {
  bool _usaPerfil = true;
  final _formKey = GlobalKey<FormState>();
  final _fieldKeys =
      List.generate(4, (_) => GlobalKey<FormFieldState<String>>());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  String? _profileError;
  final _estado = TextEditingController();
  final _ciudad = TextEditingController();
  final _domicilio = TextEditingController();
  final _maps = TextEditingController();

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    _estado.dispose();
    _ciudad.dispose();
    _domicilio.dispose();
    _maps.dispose();
    super.dispose();
  }

  InputDecoration _field(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorMaxLines: 2,
      filled: true,
      fillColor: AppColors.fieldFill,
      border: OutlineInputBorder(
        borderRadius: AppDecorations.radius12,
        borderSide: BorderSide.none,
      ),
    );
  }

  String _armarTextoEntrega() {
    final e = _estado.text.trim();
    final c = _ciudad.text.trim();
    final d = _domicilio.text.trim();
    return [
      if (e.isNotEmpty) 'Estado: $e',
      if (c.isNotEmpty) 'Ciudad: $c',
      if (d.isNotEmpty) 'Domicilio: $d',
    ].join('\n');
  }

  void _confirmar() {
    if (_usaPerfil) {
      if (!widget.profile.hasFiscalMapsShareLink) {
        setState(() => _profileError =
            'Agrega el enlace de Google Maps en Mi perfil o elige otra dirección.');
        return;
      }
    } else if (!(_formKey.currentState?.validate() ?? false)) {
      for (var i = 0; i < _fieldKeys.length; i++) {
        if (_fieldKeys[i].currentState?.hasError ?? false) {
          _focusNodes[i].requestFocus();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final fieldContext = _fieldKeys[i].currentContext;
            if (!mounted || fieldContext == null) return;
            Scrollable.ensureVisible(fieldContext, alignment: 0);
          });
          break;
        }
      }
      return;
    }
    final text = _usaPerfil ? null : _armarTextoEntrega();
    final maps = _usaPerfil ? null : _maps.text.trim();
    Navigator.of(context).pop(
      DeliveryDestinationResult(
        useProfile: _usaPerfil,
        texto: text,
        mapsUrl: maps,
      ),
    );
  }

  String? _required(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;

  String? _validateMaps(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Agrega el enlace de Google Maps.';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !uri.hasAuthority ||
        uri.host.isEmpty) {
      return 'Usa un enlace completo: https://…';
    }
    return null;
  }

  void _chooseLocation(bool useProfile) {
    setState(() {
      _usaPerfil = useProfile;
      _profileError = null;
    });
  }

  List<String> _envioNotas() {
    final notes = <String>[];
    for (final entry in CartService.instance.supplierGroups.entries) {
      if (entry.value.isEmpty) continue;
      final line = entry.value.first;
      final note = EnvioPolitica.notaConfirmacion(
        tipo: line.part.ownerEnvioTipo,
        proveedor: CartService.instance.importadorDisplayName(entry.key),
        minimoGratis: line.part.ownerEnvioGratisMinimo,
      );
      if (note != null) notes.add(note);
    }
    return notes;
  }

  String get _fiscalSummary {
    final parts = <String>[
      if ((widget.profile.estado ?? '').trim().isNotEmpty)
        widget.profile.estado!.trim(),
      if ((widget.profile.ciudad ?? '').trim().isNotEmpty)
        widget.profile.ciudad!.trim(),
      if ((widget.profile.direccion ?? '').trim().isNotEmpty)
        widget.profile.direccion!.trim(),
    ];
    if (parts.isEmpty) {
      return 'Complete la dirección fiscal en Mi perfil.';
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Dónde entregamos el pedido?'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.paymentSummary,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'La tienda recibe la mercancía en esta dirección. Puede usar la de su perfil u otra para este pedido.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              EnvioPoliticaNotas(notas: _envioNotas()),
              _LocationChoice(
                selected: _usaPerfil,
                icon: Icons.storefront_outlined,
                title: 'Dirección de mi perfil',
                  body: widget.profile.hasFiscalMapsShareLink
                      ? (_usaPerfil
                          ? _fiscalSummary
                          : 'Usar la dirección guardada en Mi perfil.')
                      : 'Falta el enlace de Google Maps en Mi perfil.',
                onTap: () => _chooseLocation(true),
              ),
              if (_profileError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_profileError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                ),
              const SizedBox(height: 8),
              _LocationChoice(
                selected: !_usaPerfil,
                icon: Icons.edit_location_alt_outlined,
                title: 'Otra dirección',
                body:
                    'Solo para este pedido. El enlace de mapas es obligatorio.',
                onTap: () => _chooseLocation(false),
              ),
              if (!_usaPerfil) ...[
                const SizedBox(height: 4),
                const Text(
                  'Ubicación alterna de entrega',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandBlue,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Esta dirección sustituye a la fiscal para este pedido. '
                  'El enlace de Google Maps es obligatorio para ubicar el sitio con precisión.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: _fieldKeys[0],
                  scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
                  focusNode: _focusNodes[0],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _estado,
                  validator: (value) => _required(value, 'Indica el estado.'),
                  textCapitalization: TextCapitalization.words,
                  decoration: _field('Estado'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: _fieldKeys[1],
                  scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
                  focusNode: _focusNodes[1],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _ciudad,
                  validator: (value) => _required(value, 'Indica la ciudad.'),
                  textCapitalization: TextCapitalization.words,
                  decoration: _field('Ciudad'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: _fieldKeys[2],
                  scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
                  focusNode: _focusNodes[2],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _domicilio,
                  validator: (value) =>
                      _required(value, 'Indica la calle, sector y referencia.'),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _field('Domicilio (calle, sector, ref.)'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: _fieldKeys[3],
                  scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
                  focusNode: _focusNodes[3],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _maps,
                  validator: _validateMaps,
                  keyboardType: TextInputType.url,
                  decoration: _field(
                    'URL de Google Maps',
                    hint: 'https://…',
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _confirmar(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmar,
          child: const Text('Confirmar pedido'),
        ),
      ],
    );
  }
}

class _LocationChoice extends StatelessWidget {
  const _LocationChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandBlueContainer : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.borderSubtle,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.brand : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
