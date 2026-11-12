# Guía de estilo — Modo Oscuro (B2B Conecta)

Paleta para **panel administrativo y portal mayorista**, orientada a reducir fatiga visual en uso prolongado (oficinas / talleres) y a cumplir **WCAG 2.1 AA**.

Implementación: [`lib/app/theme/app_dark_tokens.dart`](../lib/app/theme/app_dark_tokens.dart), [`lib/app/theme/b2b_theme_extension.dart`](../lib/app/theme/b2b_theme_extension.dart) (`B2BThemeExtension` en `ThemeData.extensions`), [`lib/app/theme/app_theme.dart`](../lib/app/theme/app_theme.dart) (`buildAppTheme` / `buildAppDarkTheme`), [`AdminUsersChrome`](../lib/features/admin/admin_users_chrome.dart).  
Toggle Sol/Luna: [`ThemeModeBubble`](../lib/core/widgets/theme_mode_bubble.dart) + [`ThemeController`](../lib/app/theme/theme_controller.dart) (barra superior admin) + `AnimatedTheme` (250 ms) en `MaterialApp.builder`.  
Sidebar admin: dinámico claro (`#FFFFFF` / activo `#EFF6FF`) u oscuro (slate / activo Blue 500 @ 18%).

## Principios

1. **Sin negro puro (`#000000`)** en superficies: slate 950 / 900 / 800.
2. **Acento más luminoso en dark** (`#3B82F6`) que el Blue 600 de marca light (`#2563EB`).
3. **Texto primario / secundario** con contraste AA sobre `#0F172A`.
4. **Estados semánticos** con texto luminoso + píldora translúcida (no pasteles claros).

## Tokens (Hex · Uso · Contraste WCAG)

Contrastes calculados sobre superficie de tarjeta `#0F172A` salvo nota.

| Token | Hex | Uso | Ratio (aprox.) | WCAG |
|---|---|---|---|---|
| `backgroundDark` | `#0B1120` | Fondo de pantalla / scaffold | — | — |
| `surfaceDark` | `#0F172A` | Sidebar / capas base | — | — |
| `surfaceElevatedDark` | `#1E293B` | Tarjetas dashboard, top bar, modales | — | — |
| `surfaceSubtleDark` | `#131C31` | Zebra / filas alternas, field fill | — | — |
| `borderDark` | `#1E293B` | Divisores sutiles | — | — |
| `borderStrongDark` | `#334155` | Bordes de inputs / cards | — | — |
| `textPrimaryDark` | `#F8FAFC` | Títulos, cuerpo principal | ≈ **15.4:1** | AAA |
| `textSecondaryDark` | `#94A3B8` | Metadatos, subtítulos | ≈ **5.9:1** | AA |
| `textMutedDark` | `#64748B` | Disabled / hints | ≈ **3.8:1** | UI no-texto crítico |
| `brandOnDark` (CTA) | `#3B82F6` | Botones primarios, tabs activas | ≈ **5.1:1** | AA (UI / texto grande) |
| `brandBase` | `#2563EB` | Referencia marca / contenedores | — | — |
| `brandHover` | `#1D4ED8` | Hover CTA | — | — |
| `successFg` | `#4ADE80` | Activo, USD, aprobado (texto) | ≈ **9.5:1** | AAA |
| `successPill` | `#2616A34A` | Fondo píldora éxito | — | — |
| `warningFg` | `#FBBF24` | Pendiente KYC / suspensión | ≈ **9.8:1** | AAA |
| `warningPill` | `#26F59E0B` | Fondo píldora warning | — | — |
| `dangerFg` | `#F87171` | Rechazo / hard delete (texto) | ≈ **5.5:1** | AA |
| `dangerPill` | `#26DC2626` | Fondo píldora peligro | — | — |
| `dangerSolid` | `#EF4444` | Botón destructivo sólido | on `#F8FAFC` ≈ **4.6:1** | AA (texto grande / UI) |

## Mapa Flutter

| Guía | Dart |
|---|---|
| Tokens | `AppDarkTokens.*` |
| Getters reactivos | `AppColors.background` / `card` / `textPrimary` / … (según `AppColors.brightness`) |
| `ThemeData` oscuro | `buildAppDarkTheme()` → `MaterialApp.darkTheme` |
| Preferencia | `ThemeController` (`ThemeMode.light` \| `dark`) |
| Admin chrome | `AdminUsersChrome.border` / `brand` / `card()` / … (leen `_dark`) |

```dart
// CTA / enlace adaptativo
AppColors.brandLink          // claro: #0039A0 · oscuro: #3B82F6
Theme.of(context).colorScheme.primary  // en darkTheme = AppDarkTokens.brand

// Semántica
AppColors.successForeground
AppColors.successSurface     // píldora
AppColors.warningForeground
AppColors.dangerSolid
```

## Toggle Sol/Luna

- Ubicación: barra superior derecha del shell admin (`AdminShellTopBar` → `ThemeModeBubble`).
- También en hub **Ajustes del sistema**.
- Persiste en `SharedPreferences` (`app_theme_mode`).
- `MainShell` escucha `ThemeController` y sincroniza `AppColors.brightness` para `IndexedStack`.

## Checklist visual

- [ ] Scaffold `#0B1120`, cards `#0F172A`, modal `#1E293B`
- [ ] Texto cuerpo `#F8FAFC`, meta `#94A3B8`
- [ ] CTA filled `#3B82F6` (no `#2563EB` apagado sobre slate)
- [ ] Píldoras Activo / Pendiente / Rechazo con fg luminoso + tint 15%
- [ ] Sin cards blancas residuales en Cuentas / Ajustes al activar oscuro
