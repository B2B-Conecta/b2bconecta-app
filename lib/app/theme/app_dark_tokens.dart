import 'package:flutter/material.dart';

/// Tokens de Modo Oscuro B2B Conecta (WCAG 2.1 AA).
///
/// Superficies en slate profundo (sin negro puro `#000000`) para uso prolongado
/// en oficinas y talleres. Ver `docs/DARK_MODE_STYLE_GUIDE.md`.
abstract final class AppDarkTokens {
  // —— Superficies ——
  /// Fondo principal de pantalla (Slate 950 suave).
  static const background = Color(0xFF0B1120);

  /// Tarjetas, tablas y paneles (Slate 900 — mismo tono que el sidebar).
  static const surface = Color(0xFF0F172A);

  /// Modales, drawers y capas flotantes (Slate 800).
  static const surfaceElevated = Color(0xFF1E293B);

  /// Filas alternas / zebra.
  static const surfaceSubtle = Color(0xFF131C31);

  /// Borde sutil primario (Slate 800).
  static const border = Color(0xFF1E293B);

  /// Borde más visible / divisores (Slate 700).
  static const borderStrong = Color(0xFF334155);

  /// Relleno de inputs (entre surface y elevated).
  static const fieldFill = Color(0xFF131C31);

  // —— Tipografía ——
  /// Texto primario (Slate 50). Contraste ≈ 15.4:1 sobre [surface].
  static const textPrimary = Color(0xFFF8FAFC);

  /// Secundario / metadatos (Slate 400). Contraste ≈ 5.9:1 sobre [surface] (AA).
  static const textSecondary = Color(0xFF94A3B8);

  /// Deshabilitado / hints (Slate 500). ≈ 3.8:1 — uso UI no-texto crítico.
  static const textMuted = Color(0xFF64748B);

  // —— Acentos ——
  /// CTA / acento en dark (Blue 500). Más luminoso que brand light `#2563EB`.
  static const brand = Color(0xFF3B82F6);

  /// Brand light de referencia (Blue 600) — hover / contenedores.
  static const brandBase = Color(0xFF2563EB);

  /// Hover de botones primarios.
  static const brandHover = Color(0xFF1D4ED8);

  /// Contenedor suave de acento.
  static const brandContainer = Color(0xFF1E3A5F);

  // —— Semántica ——
  static const successFg = Color(0xFF4ADE80);
  static const successPill = Color(0x2616A34A);
  static const successBase = Color(0xFF16A34A);

  static const warningFg = Color(0xFFFBBF24);
  static const warningPill = Color(0x26F59E0B);

  static const dangerFg = Color(0xFFF87171);
  static const dangerPill = Color(0x26DC2626);
  static const dangerSolid = Color(0xFFEF4444);

  /// Sidebar / rail (alineado a surface).
  static const sidebar = surface;
}
