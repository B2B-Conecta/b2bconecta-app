import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/admin_list_skeleton.dart';

/// Skeleton de 8 filas alineado a columnas de [UsersDataTable].
class AccountsTableSkeleton extends StatelessWidget {
  const AccountsTableSkeleton({
    super.key,
    this.rows = 8,
    this.compact = false,
  });

  final int rows;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Semantics(
      label: 'Cargando usuarios',
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            ColoredBox(
              color: i.isOdd ? theme.tableRowOdd : theme.tableRowEven,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Shimmer(
                  child: compact
                      ? const _CompactSkeletonRow()
                      : const _DesktopSkeletonRow(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesktopSkeletonRow extends StatelessWidget {
  const _DesktopSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 40,
          child: Center(child: SkeletonBox(width: 18, height: 18, radius: 4)),
        ),
        Expanded(
          flex: 4,
          child: Row(
            children: [
              SkeletonBox(width: 36, height: 36, radius: 999),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 12),
                    SizedBox(height: 6),
                    SkeletonBox(width: 160, height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: 88, height: 22, radius: 999),
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: 72, height: 22, radius: 999),
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SkeletonBox(width: 70, height: 11),
          ),
        ),
        SizedBox(
          width: 48,
          child: Center(child: SkeletonBox(width: 18, height: 18, radius: 4)),
        ),
      ],
    );
  }
}

class _CompactSkeletonRow extends StatelessWidget {
  const _CompactSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 18, height: 18, radius: 4),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonBox(width: 36, height: 36, radius: 999),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: 12),
                        SizedBox(height: 6),
                        SkeletonBox(width: 120, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  SkeletonBox(width: 72, height: 20, radius: 999),
                  SizedBox(width: 8),
                  SkeletonBox(width: 64, height: 20, radius: 999),
                  SizedBox(width: 8),
                  SkeletonBox(width: 56, height: 10),
                ],
              ),
            ],
          ),
        ),
        SkeletonBox(width: 18, height: 18, radius: 4),
      ],
    );
  }
}
