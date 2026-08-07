#!/usr/bin/env python3
"""Regenera lib/gen/motolink_pro_logo_bytes.dart desde logos B2B Conecta."""
import base64
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent
color_png = root / "assets" / "logo-b2b-conecta-color.png"
white_png = root / "assets" / "logo-b2b-conecta-white.png"
# Compat PDF / rutas legacy
legacy = root / "assets" / "logo-oficial-motolinkpro-nobg.png"
out = root / "lib" / "gen" / "motolink_pro_logo_bytes.dart"

if not color_png.is_file():
    raise SystemExit(f"Missing {color_png}")
if not white_png.is_file():
    raise SystemExit(f"Missing {white_png}")

# Mantener alias legacy apuntando al logo color (fondos claros / PDFs).
legacy.write_bytes(color_png.read_bytes())

color_b64 = base64.b64encode(color_png.read_bytes()).decode("ascii")
white_b64 = base64.b64encode(white_png.read_bytes()).decode("ascii")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(
    f"""// Logos B2B Conecta embebidos (color + blanco).
// Regenerate: python3 tool/embed_logo.py
import 'dart:convert';
import 'dart:typed_data';

Uint8List decodeMotoLinkProLogoPng() {{
  return decodeB2bConectaLogoColorPng();
}}

Uint8List decodeB2bConectaLogoColorPng() {{
  return Uint8List.fromList(base64Decode(_kLogoColorB64));
}}

Uint8List decodeB2bConectaLogoWhitePng() {{
  return Uint8List.fromList(base64Decode(_kLogoWhiteB64));
}}

const String _kLogoColorB64 = '{color_b64}';

const String _kLogoWhiteB64 = '{white_b64}';
"""
)
print(f"Wrote {out} (color={len(color_b64)} white={len(white_b64)} chars base64)")
