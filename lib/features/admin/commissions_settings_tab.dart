import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_payout_prefs.dart';
import 'package:motolink_pro_app/features/commissions/commission_settlement_model.dart';
import 'package:motolink_pro_app/features/commissions/commissions_service.dart';

/// Facturación operativa B2B: comisiones, método de cobro e historial de cortes.
class B2BCommissionsBillingTab extends StatefulWidget {
  const B2BCommissionsBillingTab({
    super.key,
    this.onOpenCommissions,
  });

  final VoidCallback? onOpenCommissions;

  @override
  State<B2BCommissionsBillingTab> createState() =>
      _B2BCommissionsBillingTabState();
}

/// Alias histórico para el hub de ajustes.
typedef CommissionsSettingsTab = B2BCommissionsBillingTab;

class _B2BCommissionsBillingTabState extends State<B2BCommissionsBillingTab> {
  static const _months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  bool _loading = true;
  double _rate = 0.025;
  double _bcvRate = 0;
  double _monthUsd = 0;
  double _pendingUsd = 0;
  DateTime? _nextCut;
  List<CommissionSettlementModel> _history = const [];
  AdminPayoutPrefs? _payout;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        CommissionsService.fetchDefaultCommissionRate(),
        CommissionsService.fetchCommissionSettlements(limit: 24),
        BcvBasePrice.currentRate(),
        AdminPayoutPrefs.load(),
      ]);
      final rate = results[0] as double;
      final list = results[1] as List<CommissionSettlementModel>;
      final bcv = results[2] as double;
      final payout = results[3] as AdminPayoutPrefs;

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthUsd = list.where((s) {
        if (s.isAnulado) return false;
        final anchor = s.paidAt ?? s.issuedAt ?? s.periodEnd;
        return !anchor.isBefore(monthStart) &&
            anchor.month == now.month &&
            anchor.year == now.year;
      }).fold<double>(0, (a, s) => a + s.totalCommissionUsd);

      final pending = list
          .where((s) => s.isBorrador || s.isEmitido)
          .fold<double>(0, (a, s) => a + s.totalCommissionUsd);

      DateTime? nextCut;
      final open = list.where((s) => s.isBorrador || s.isEmitido).toList()
        ..sort((a, b) => a.periodEnd.compareTo(b.periodEnd));
      if (open.isNotEmpty) {
        nextCut = open.first.periodEnd;
      } else if (list.isNotEmpty) {
        final last = list
            .map((s) => s.periodEnd)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        nextCut = last.add(const Duration(days: 15));
      } else {
        nextCut = DateTime(now.year, now.month, 15);
        if (!nextCut.isAfter(now)) {
          nextCut = DateTime(now.year, now.month + 1, 15);
        }
      }

      if (!mounted) return;
      setState(() {
        _rate = rate > 0 ? rate : 0.025;
        _bcvRate = bcv;
        _monthUsd = monthUsd;
        _pendingUsd = pending;
        _nextCut = nextCut;
        _history = list.take(12).toList();
        _payout = payout;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _payout ??= AdminPayoutPrefs();
        _loading = false;
      });
    }
  }

  void _goHistory() {
    if (widget.onOpenCommissions != null) {
      widget.onOpenCommissions!();
      return;
    }
    MainShellTabController.navigateToAdminComisionesForNotification();
  }

  String _fmtDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  String _periodReadable(CommissionSettlementModel s) =>
      '${_fmtDay(s.periodStart)} - ${_fmtDay(s.periodEnd)}';

  String _usd(double v) => '\$${formatVesAmount(v, fractionDigits: 2)} USD';

  String _bs(double usd) {
    if (_bcvRate <= 0) return 'Bs —';
    return formatBsLabel(usd * _bcvRate, fractionDigits: 2);
  }

  Future<void> _downloadReceipt(CommissionSettlementModel s) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          s.tieneFacturaPdf
              ? 'Preparando recibo del corte ${_periodReadable(s)}…'
              : 'Comprobante simulado del corte ${_periodReadable(s)}.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openPayoutModal() async {
    final theme = B2BThemeExtension.of(context);
    final current = _payout ?? await AdminPayoutPrefs.load();
    final method = ValueNotifier(current.method);
    final labelCtrl = TextEditingController(text: current.label);
    final maskCtrl = TextEditingController(
      text: current.mask.replaceAll(RegExp(r'[^\d]'), ''),
    );

    final saved = await showDialog<AdminPayoutPrefs>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.dialogSurface,
          title: Text(
            'Actualizar método de cobro',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: ValueListenableBuilder<String>(
              valueListenable: method,
              builder: (context, value, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Datos de liquidación para transferencias de comisiones.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'zelle',
                          label: Text('Zelle'),
                          icon: Icon(Icons.mail_outline, size: 16),
                        ),
                        ButtonSegment(
                          value: 'bank',
                          label: Text('Banco'),
                          icon: Icon(Icons.account_balance_outlined, size: 16),
                        ),
                      ],
                      selected: {value},
                      onSelectionChanged: (s) => method.value = s.first,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: labelCtrl,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: InputDecoration(
                        labelText: value == 'zelle'
                            ? 'Etiqueta / correo Zelle'
                            : 'Banco o titular',
                        filled: true,
                        fillColor: theme.inputFill,
                        labelStyle: TextStyle(color: theme.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: maskCtrl,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: InputDecoration(
                        labelText: value == 'zelle'
                            ? 'Últimos dígitos / referencia'
                            : 'Últimos 4 dígitos de cuenta',
                        hintText: '4892',
                        filled: true,
                        fillColor: theme.inputFill,
                        labelStyle: TextStyle(color: theme.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final digits = maskCtrl.text.replaceAll(RegExp(r'\D'), '');
                final tail = digits.length >= 4
                    ? digits.substring(digits.length - 4)
                    : (digits.isEmpty ? '4892' : digits.padLeft(4, '0'));
                Navigator.pop(
                  ctx,
                  AdminPayoutPrefs(
                    method: method.value,
                    label: labelCtrl.text.trim().isEmpty
                        ? (method.value == 'bank' ? 'Banco Nacional' : 'Zelle')
                        : labelCtrl.text.trim(),
                    mask: '•••• $tail',
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    method.dispose();
    labelCtrl.dispose();
    maskCtrl.dispose();

    if (saved == null || !mounted) return;
    await saved.save();
    setState(() => _payout = saved);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Método de cobro actualizado.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final ratePct = (_rate * 100).toStringAsFixed(
      (_rate * 100) % 1 == 0 ? 1 : 2,
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: _Card(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: theme.brand,
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Esquema de Comisiones B2B',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Modelo de retención por transacciones mayoristas y tasa oficial BCV.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: theme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.successBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: theme.successFg,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cuenta Activa · Comisión base: $ratePct% por transacción',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.successFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, c) {
                      final narrow = c.maxWidth < 560;
                      final monthTile = _MetricTile(
                        theme: theme,
                        label: 'Comisiones acumuladas del mes',
                        primary: _usd(_monthUsd),
                        secondary: _bs(_monthUsd),
                      );
                      final pendingTile = _MetricTile(
                        theme: theme,
                        label: 'Corte pendiente de liquidación',
                        primary: _nextCut == null ? '—' : _fmtDay(_nextCut!),
                        secondary:
                            'Saldo por transferir: ${_usd(_pendingUsd)}',
                      );
                      if (narrow) {
                        return Column(
                          children: [
                            monthTile,
                            const SizedBox(height: 10),
                            pendingTile,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: monthTile),
                          const SizedBox(width: 10),
                          Expanded(child: pendingTile),
                        ],
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1, color: theme.borderSubtle),
                  ),
                  _PayoutMethodRow(
                    theme: theme,
                    payout: _payout,
                    onUpdate: _openPayoutModal,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1, color: theme.borderSubtle),
                  ),
                  Text(
                    'Historial de cortes y liquidaciones',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Registro detallado de comisiones pagadas y pendientes',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: theme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_history.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.borderSubtle),
                      ),
                      child: Text(
                        'Aún no hay cortes registrados. Cuando se generen liquidaciones aparecerán aquí.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textSecondary,
                        ),
                      ),
                    )
                  else
                    for (final s in _history)
                      _SettlementHistoryRow(
                        theme: theme,
                        period: _periodReadable(s),
                        description:
                            s.invoiceReference?.trim().isNotEmpty == true
                                ? 'Corte ${s.invoiceReference} · Mayoristas'
                                : 'Corte quincenal · ${s.lineCount} líneas · Mayoristas',
                        usd: _usd(s.totalCommissionUsd),
                        bs: _bs(s.totalCommissionUsd),
                        paid: s.isPagado,
                        pending: s.isBorrador || s.isEmitido,
                        onDownload: () => _downloadReceipt(s),
                      ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _goHistory,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.brand,
                      side: BorderSide(color: theme.brand),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: LucideIcon(
                      LucideGlyph.badgeDollarSign,
                      size: 18,
                      color: theme.brand,
                    ),
                    label: const Text(
                      'Ver historial completo en Comisiones',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.theme, required this.child});

  final B2BThemeExtension theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: theme.textPrimary.withOpacity(dark ? 0.35 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.theme,
    required this.label,
    required this.primary,
    required this.secondary,
  });

  final B2BThemeExtension theme;
  final String label;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            primary,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            secondary,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutMethodRow extends StatelessWidget {
  const _PayoutMethodRow({
    required this.theme,
    required this.payout,
    required this.onUpdate,
  });

  final B2BThemeExtension theme;
  final AdminPayoutPrefs? payout;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final isBank = payout?.method == 'bank';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.brandContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: LucideIcon(
              isBank ? LucideGlyph.landmark : LucideGlyph.creditCard,
              size: 20,
              color: theme.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Método de pago y cuenta asociada',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  payout?.displayLine ?? 'Zelle · •••• 4892',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onUpdate,
            child: Text(
              'Actualizar método',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: theme.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementHistoryRow extends StatelessWidget {
  const _SettlementHistoryRow({
    required this.theme,
    required this.period,
    required this.description,
    required this.usd,
    required this.bs,
    required this.paid,
    required this.pending,
    required this.onDownload,
  });

  final B2BThemeExtension theme;
  final String period;
  final String description;
  final String usd;
  final String bs;
  final bool paid;
  final bool pending;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final statusBg = paid
        ? theme.successBg
        : (dark ? const Color(0x26F59E0B) : const Color(0xFFFEF3C7));
    final statusFg = paid
        ? theme.successFg
        : (dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));
    final statusLabel = paid
        ? 'Liquidado'
        : (pending ? 'Pendiente' : 'En revisión');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 640;
          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    usd,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  Text(
                    bs,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textMuted,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusFg,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );

          final download = IconButton(
            tooltip: 'Descargar recibo / PDF',
            onPressed: onDownload,
            icon: LucideIcon(
              LucideGlyph.download,
              size: 18,
              color: theme.brand,
            ),
          );

          if (narrow) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: body),
                download,
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 5, child: body),
              download,
            ],
          );
        },
      ),
    );
  }
}
