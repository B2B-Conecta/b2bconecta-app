import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

const _monthNames = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const _weekdayNames = <String>[
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const _weekdayInitials = <String>['L', 'M', 'M', 'J', 'V', 'S', 'D'];

/// Calendario de filtros: español, semana desde el lunes y color de marca.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = 'Fecha',
}) {
  final first = _dateOnly(firstDate);
  final last = _dateOnly(lastDate);
  var initial = _dateOnly(initialDate);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => _AppDatePickerDialog(
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: helpText,
    ),
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String formatAppFilterDate(DateTime d) {
  final local = d.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  return '$dd/$mm/${local.year}';
}

/// Campo Desde / Hasta usado en los filtros de fecha.
class FilterDateField extends StatelessWidget {
  const FilterDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.emptyLabel = 'Sin límite',
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? emptyLabel : formatAppFilterDate(value!);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(12),
          color: AppColors.card,
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class _AppDatePickerDialog extends StatefulWidget {
  const _AppDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String helpText;

  @override
  State<_AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<_AppDatePickerDialog> {
  late DateTime _selected;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _visibleMonth = DateTime(_selected.year, _selected.month);
  }

  bool get _canGoBack {
    final prev = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    final lastOfPrev = DateTime(prev.year, prev.month + 1, 0);
    return !lastOfPrev.isBefore(widget.firstDate);
  }

  bool get _canGoForward {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    return !next.isAfter(widget.lastDate);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  String get _headline {
    final name = _weekdayNames[_selected.weekday - 1];
    final month = _monthNames[_selected.month - 1];
    final titled = name[0].toUpperCase() + name.substring(1);
    return '$titled, ${_selected.day} de $month';
  }

  @override
  Widget build(BuildContext context) {
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final firstWeekday = DateTime(year, month, 1).weekday;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leading = firstWeekday - 1;
    final cells = leading + daysInMonth;

    return Dialog(
      backgroundColor: AppColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.helpText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _headline,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_monthNames[month - 1][0].toUpperCase()}${_monthNames[month - 1].substring(1)} $year',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mes anterior',
                    onPressed: _canGoBack ? () => _shiftMonth(-1) : null,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_left),
                    color: AppColors.brand,
                  ),
                  IconButton(
                    tooltip: 'Mes siguiente',
                    onPressed: _canGoForward ? () => _shiftMonth(1) : null,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chevron_right),
                    color: AppColors.brand,
                  ),
                ],
              ),
              Row(
                children: [
                  for (final label in _weekdayInitials)
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: 36,
                ),
                itemCount: cells,
                itemBuilder: (context, index) {
                  if (index < leading) return const SizedBox.shrink();
                  final day = index - leading + 1;
                  final date = DateTime(year, month, day);
                  final enabled = !date.isBefore(widget.firstDate) &&
                      !date.isAfter(widget.lastDate);
                  final selected = date == _selected;
                  final today = date == _dateOnly(DateTime.now());
                  return InkWell(
                    onTap: enabled
                        ? () => setState(() => _selected = date)
                        : null,
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.brand : null,
                          shape: BoxShape.circle,
                          border: !selected && today
                              ? Border.all(color: AppColors.brand)
                              : null,
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: !enabled
                                ? AppColors.textMuted
                                : selected
                                    ? AppColors.white
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text(
                      'Aceptar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
