import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motolink_pro_app/app/theme/app_dark_tokens.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';

void main() {
  tearDown(() {
    AppColors.brightness = Brightness.light;
  });

  test('buildAppDarkTheme usa tokens slate (sin negro puro)', () {
    final theme = buildAppDarkTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppDarkTokens.background);
    expect(theme.colorScheme.primary, AppDarkTokens.brand);
    expect(theme.colorScheme.surface, AppDarkTokens.surface);
    expect(theme.scaffoldBackgroundColor, isNot(Colors.black));
  });

  test('AppColors dark mapea a AppDarkTokens', () {
    AppColors.brightness = Brightness.dark;
    expect(AppColors.background, AppDarkTokens.background);
    expect(AppColors.card, AppDarkTokens.surface);
    expect(AppColors.textPrimary, AppDarkTokens.textPrimary);
    expect(AppColors.textSecondary, AppDarkTokens.textSecondary);
    expect(AppColors.brandLink, AppDarkTokens.brand);
    expect(AppColors.successForeground, AppDarkTokens.successFg);
  });

  test('AdminUsersChrome reacciona a brightness', () {
    AppColors.brightness = Brightness.light;
    expect(AdminUsersChrome.brand, const Color(0xFF2563EB));
    expect(AdminUsersChrome.cardColor, Colors.white);

    AppColors.brightness = Brightness.dark;
    expect(AdminUsersChrome.brand, AppDarkTokens.brand);
    expect(AdminUsersChrome.cardColor, AppDarkTokens.surfaceElevated);
    expect(AdminUsersChrome.titleColor, AppDarkTokens.textPrimary);
  });

  test('texto primario supera umbral AA (4.5:1) sobre surface', () {
    expect(
      _contrastRatio(AppDarkTokens.textPrimary, AppDarkTokens.surface),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('texto secundario supera umbral AA (4.5:1) sobre surface', () {
    expect(
      _contrastRatio(AppDarkTokens.textSecondary, AppDarkTokens.surface),
      greaterThanOrEqualTo(4.5),
    );
  });
}

double _relativeLuminance(Color c) {
  double channel(int v) {
    final s = v / 255.0;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.red) +
      0.7152 * channel(c.green) +
      0.0722 * channel(c.blue);
}

double _contrastRatio(Color fg, Color bg) {
  final l1 = _relativeLuminance(fg);
  final l2 = _relativeLuminance(bg);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}
