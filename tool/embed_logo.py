#!/usr/bin/env python3
"""Regenera lib/gen/motolink_pro_logo_bytes.dart desde assets/logo-oficial-motolinkpro-nobg.png."""
import base64
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent
png = root / "assets" / "logo-oficial-motolinkpro-nobg.png"
out = root / "lib" / "gen" / "motolink_pro_logo_bytes.dart"

b64 = base64.b64encode(png.read_bytes()).decode("ascii")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(
    f"""// Bytes of assets/logo-oficial-motolinkpro-nobg.png (embedded for reliable display on web).
// Regenerate: python3 tool/embed_logo.py
import 'dart:convert';
import 'dart:typed_data';

Uint8List decodeMotoLinkProLogoPng() {{
  return Uint8List.fromList(base64Decode(_kLogoB64));
}}

const String _kLogoB64 = '{b64}';
"""
)
print(f"Wrote {out} ({len(b64)} chars base64)")
