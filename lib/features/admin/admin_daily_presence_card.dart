import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/admin/admin_user_activity_row_model.dart';
import 'package:motolink_pro_app/features/admin/user_presence.dart';

/// Resumen del día en el rail admin: cuentas que ingresaron hoy y en línea ahora.
class AdminDailyPresenceCard extends StatefulWidget {
  const AdminDailyPresenceCard({
    super.key,
    required this.extended,
    required this.onOpenDetails,
    this.darkRail = false,
  });

  final bool extended;
  final VoidCallback onOpenDetails;

  /// Alinea colores con el rail corporativo oscuro.
  final bool darkRail;

  @override
  State<AdminDailyPresenceCard> createState() => _AdminDailyPresenceCardState();
}

class _AdminDailyPresenceCardState extends State<AdminDailyPresenceCard> {
  int? _loggedToday;
  int? _onlineNow;
  Timer? _timer;

  static const _darkCard = Color(0xFF1E293B);
  static const _darkBorder = Color(0xFF334155);
  static const _darkMuted = Color(0xFF94A3B8);
  static const _darkLabel = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(_load());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        SupabaseService.listAdminUserActivityMonitoring(period: 'day'),
        SupabaseService.listAdminUserPresence(),
      ]);
      if (!mounted) return;
      final activity = results[0] as List<AdminUserActivityRowModel>;
      final presence = results[1] as List<AdminUserPresenceRow>;
      final now = DateTime.now();
      setState(() {
        _loggedToday = activity.where((r) => r.loginCountToday > 0).length;
        _onlineNow = presence.where((r) => r.isOnlineAt(now)).length;
      });
    } catch (_) {
      // Se conserva el último valor; el próximo ciclo reintenta.
    }
  }

  bool get _useDark {
    if (!widget.darkRail) return AppColors.isDarkOf(context);
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color get _card => _useDark ? _darkCard : const Color(0xFFF1F5F9);
  Color get _border =>
      _useDark ? _darkBorder : const Color(0xFFE2E8F0);
  Color get _muted =>
      _useDark ? _darkMuted : const Color(0xFF64748B);
  Color get _label =>
      _useDark ? _darkLabel : const Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    final today = _loggedToday?.toString() ?? '—';
    final online = _onlineNow;
    final tooltip = 'Ingresaron hoy: $today · '
        '${online ?? '—'} en línea · Ver presencia';

    if (!widget.extended) {
      final onlineLabel = online?.toString() ?? '—';
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: _card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: _border),
            ),
            child: InkWell(
              onTap: widget.onOpenDetails,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 48,
                height: 52,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      onlineLabel,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: _label,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 22,
                          color: _muted,
                        ),
                        Positioned(
                          right: -3,
                          top: -2,
                          child: _OnlineDot(active: (online ?? 0) > 0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Tooltip(
        message: 'Ver presencia',
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _border),
          ),
          child: InkWell(
            onTap: widget.onOpenDetails,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'INGRESARON HOY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: _muted,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 15,
                        color: _muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        today,
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: _label,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _loggedToday == 1 ? 'cuenta' : 'cuentas',
                        style: TextStyle(
                          fontSize: 12,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _OnlineDot(active: (online ?? 0) > 0),
                      const SizedBox(width: 6),
                      Text(
                        online == null ? '— en línea' : '$online en línea ahora',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.successGreen : AppColors.textSecondary;
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: active
            ? [BoxShadow(color: color.withOpacity(0.45), blurRadius: 6)]
            : null,
      ),
    );
  }
}
