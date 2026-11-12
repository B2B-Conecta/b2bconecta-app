import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_recent_activity.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';

/// Feed de las últimas acciones B2B (1/3 del dashboard Inicio).
class RecentActivityFeed extends StatelessWidget {
  const RecentActivityFeed({
    super.key,
    required this.activity,
    this.onSeeAll,
  });

  final AdminRecentActivity activity;
  final VoidCallback? onSeeAll;

  static const preferredHeight = 380.0;

  static Color get _border => AdminUsersChrome.border;
  static Color get _title => AdminUsersChrome.titleColor;
  static Color get _desc => AdminUsersChrome.muted;
  static Color get _time => AdminUsersChrome.muted;
  static Color get _zebra => AdminUsersChrome.zebra;
  static Color get _brand => AdminUsersChrome.brand;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: activity,
      builder: (context, _) {
        final snap = activity.snapshot;
        return Container(
          decoration: AdminUsersChrome.card(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  'Actividad reciente',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _title,
                    height: 1.2,
                  ),
                ),
              ),
              Expanded(
                child: activity.loading && snap.isEmpty
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: snap.items.length,
                        itemBuilder: (context, index) {
                          final item = snap.items[index];
                          final zebra = index.isOdd;
                          return _ActivityRow(
                            item: item,
                            zebra: zebra,
                          );
                        },
                      ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: _border)),
                ),
                child: Material(
                  color: AdminUsersChrome.cardColor,
                  child: InkWell(
                    onTap: onSeeAll ??
                        () => MainShellTabController.navigateToAdminPresence(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ver todo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _brand,
                            ),
                          ),
                          const SizedBox(width: 6),
                          LucideIcon(
                            LucideGlyph.arrowRight,
                            size: 16,
                            color: _brand,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.item,
    required this.zebra,
  });

  final RecentActivityItem item;
  final bool zebra;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: zebra ? RecentActivityFeed._zebra : AdminUsersChrome.cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActorAvatar(item: item),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.actorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: RecentActivityFeed._title,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: RecentActivityFeed._desc,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AdminRecentActivity.formatRelativeEs(item.at),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: RecentActivityFeed._time,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActorAvatar extends StatefulWidget {
  const _ActorAvatar({required this.item});

  final RecentActivityItem item;

  @override
  State<_ActorAvatar> createState() => _ActorAvatarState();
}

class _ActorAvatarState extends State<_ActorAvatar> {
  String? _url;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _ActorAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.logoStoragePath != widget.item.logoStoragePath) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final path = widget.item.logoStoragePath?.trim();
    if (path == null || path.isEmpty) {
      setState(() {
        _url = null;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final url = await SupabaseService.createSignedUrlForProfileLogo(path);
      if (!mounted) return;
      setState(() {
        _url = url;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _url = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.item.kindAccent;
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: accent.withOpacity(0.12),
            backgroundImage: _url != null ? NetworkImage(_url!) : null,
            child: _url == null && !_loading
                ? Text(
                    widget.item.initials,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  )
                : (_loading && _url == null
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: accent,
                        ),
                      )
                    : null),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AdminUsersChrome.cardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AdminUsersChrome.cardColor,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.textPrimary.withOpacity(dark ? 0.28 : 0.08),
                    blurRadius: 2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: LucideIcon(
                widget.item.kindGlyph,
                size: 9,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
