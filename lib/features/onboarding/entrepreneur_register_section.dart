import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

/// Rol público en el alta: Minorista (`aliado`) / Mayorista (`importador`).
enum PublicSignupRole { aliado, importador }

/// Selector compacto Minorista/Mayorista + toggle Emprendedor + campos rápidos.
class PublicSignupRoleSection extends StatelessWidget {
  const PublicSignupRoleSection({
    super.key,
    required this.role,
    required this.onRoleChanged,
    required this.entrepreneurEnabled,
    required this.onEntrepreneurChanged,
    this.enabled = true,
  });

  final PublicSignupRole role;
  final ValueChanged<PublicSignupRole> onRoleChanged;
  final bool entrepreneurEnabled;
  final ValueChanged<bool> onEntrepreneurChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final isMinorista = role == PublicSignupRole.aliado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tipo de cuenta',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        _RoleSegmentedControl(
          role: role,
          enabled: enabled,
          onChanged: onRoleChanged,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: isMinorista
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _EntrepreneurToggleCard(
                    enabled: enabled,
                    value: entrepreneurEnabled,
                    onChanged: onEntrepreneurChanged,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _RoleSegmentedControl extends StatelessWidget {
  const _RoleSegmentedControl({
    required this.role,
    required this.onChanged,
    required this.enabled,
  });

  final PublicSignupRole role;
  final ValueChanged<PublicSignupRole> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Expanded(
                child: _RoleSegment(
                  label: 'Minorista',
                  selected: role == PublicSignupRole.aliado,
                  onTap: enabled
                      ? () => onChanged(PublicSignupRole.aliado)
                      : null,
                ),
              ),
              Expanded(
                child: _RoleSegment(
                  label: 'Mayorista',
                  selected: role == PublicSignupRole.importador,
                  onTap: enabled
                      ? () => onChanged(PublicSignupRole.importador)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleSegment extends StatelessWidget {
  const _RoleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: selected ? theme.brand : theme.surfaceSubtle.withOpacity(0),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? theme.surfaceCard : theme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EntrepreneurToggleCard extends StatelessWidget {
  const _EntrepreneurToggleCard({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Soy Minorista-Emprendedor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Registro rápido sin documentos iniciales '
                    '(8 semanas para completar expediente).',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: theme.brand,
            ),
          ],
        ),
      ),
    );
  }
}

/// Campos del alta emprendedor (grid 2 cols desktop / 1 col móvil).
class EntrepreneurSignupFields extends StatelessWidget {
  const EntrepreneurSignupFields({
    super.key,
    required this.phoneController,
    required this.rifController,
    required this.cedulaController,
    required this.locationController,
    required this.photos,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    this.enabled = true,
  });

  final TextEditingController phoneController;
  final TextEditingController rifController;
  final TextEditingController cedulaController;
  final TextEditingController locationController;
  final List<PickedDocumentBytes> photos;
  final VoidCallback onAddPhoto;
  final ValueChanged<int> onRemovePhoto;
  final bool enabled;

  InputDecoration _dec(B2BThemeExtension theme, String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: theme.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.brand, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;

    final phone = TextField(
      controller: phoneController,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: _dec(theme, 'Teléfono / WhatsApp'),
    );
    final rif = TextField(
      controller: rifController,
      enabled: enabled,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.next,
      decoration: _dec(theme, 'RIF Personal (ej. V-12345678-9)'),
    );
    final cedula = TextField(
      controller: cedulaController,
      enabled: enabled,
      textInputAction: TextInputAction.next,
      decoration: _dec(theme, 'Cédula de Identidad'),
    );
    final location = TextField(
      controller: locationController,
      enabled: enabled,
      textInputAction: TextInputAction.done,
      maxLines: 2,
      decoration: _dec(
        theme,
        'Ubicación (ej. Av. Bolívar, Local 4, Valencia)',
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Datos del emprendedor',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        if (mobile) ...[
          phone,
          const SizedBox(height: 12),
          rif,
          const SizedBox(height: 12),
          cedula,
          const SizedBox(height: 12),
          location,
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: phone),
              const SizedBox(width: 12),
              Expanded(child: rif),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cedula),
              const SizedBox(width: 12),
              Expanded(child: location),
            ],
          ),
        ],
        const SizedBox(height: 14),
        Text(
          'Opcional — puedes subir hasta 3 fotos de tu local o espacio de trabajo',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: theme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < photos.length; i++)
              _PhotoThumb(
                label: photos[i].fileName,
                onRemove: enabled ? () => onRemovePhoto(i) : null,
              ),
            if (photos.length < 3)
              _AddPhotoChip(onTap: enabled ? onAddPhoto : null),
          ],
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.label, this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LucideIcon(
                    LucideGlyph.image,
                    size: 22,
                    color: theme.brand,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 28, height: 28),
                onPressed: onRemove,
                icon: LucideIcon(
                  LucideGlyph.close,
                  size: 14,
                  color: theme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddPhotoChip extends StatelessWidget {
  const _AddPhotoChip({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: theme.surfaceSubtle,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.borderSubtle),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LucideIcon(LucideGlyph.plus, size: 22, color: theme.brand),
              const SizedBox(height: 4),
              Text(
                'Añadir',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
