#!/usr/bin/env python3
"""Documenta la fuente del ícono de launcher B2B Conecta.

Los assets oficiales son:
  - assets/app-icon-b2b-conecta-launcher.png
  - assets/app-icon-b2b-conecta-foreground.png

Regenerar plataformas:
  dart run flutter_launcher_icons
"""
from pathlib import Path

root = Path(__file__).resolve().parent.parent
launcher = root / "assets" / "app-icon-b2b-conecta-launcher.png"
foreground = root / "assets" / "app-icon-b2b-conecta-foreground.png"

missing = [p for p in (launcher, foreground) if not p.is_file()]
if missing:
    raise SystemExit(f"Missing B2B launcher assets: {missing}")

print("B2B Conecta launcher assets OK:")
print(f"  {launcher.name}")
print(f"  {foreground.name}")
print("Run: dart run flutter_launcher_icons")
