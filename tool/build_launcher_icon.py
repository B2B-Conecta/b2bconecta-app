#!/usr/bin/env python3
"""Genera PNGs del ícono de launcher desde assets/logo-motolink-outapp.pdf."""
from __future__ import annotations

import os
import pathlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
pdf = root / "assets" / "logo-motolink-outapp.pdf"
out_icon = root / "assets" / "app-icon-motolink.png"
out_launcher = root / "assets" / "app-icon-motolink-launcher.png"
out_foreground = root / "assets" / "app-icon-motolink-foreground.png"
size = 1024


def _venv_python() -> pathlib.Path:
    venv = root / ".venv-logo"
    py = venv / "bin" / "python3"
    if not py.exists():
        subprocess.check_call([sys.executable, "-m", "venv", str(venv)], cwd=root)
        subprocess.check_call(
            [str(venv / "bin" / "pip"), "install", "pymupdf", "pillow", "-q"],
            cwd=root,
        )
    return py


def _is_content(r: int, g: int, b: int, a: int) -> bool:
    if a < 20:
        return False
    return not (r < 15 and g < 15 and b < 15)


def _build() -> None:
    import fitz
    from PIL import Image

    doc = fitz.open(pdf)
    page = doc[0]
    pix = page.get_pixmap(matrix=fitz.Matrix(4, 4), alpha=True)
    src = Image.frombytes("RGBA", (pix.width, pix.height), pix.samples)
    pixels = src.load()
    w, h = src.size
    min_x, min_y, max_x, max_y = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            if _is_content(*pixels[x, y]):
                min_x = min(min_x, x)
                min_y = min(min_y, y)
                max_x = max(max_x, x)
                max_y = max(max_y, y)

    squircle = src.crop((min_x, min_y, max_x + 1, max_y + 1))
    sw, sh = squircle.size
    side = max(sw, sh)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(squircle, ((side - sw) // 2, (side - sh) // 2))
    icon = square.resize((size, size), Image.Resampling.LANCZOS)
    px = icon.load()

    def sample(x: int, y: int) -> tuple[int, int, int]:
        return px[max(0, min(size - 1, x)), max(0, min(size - 1, y))][:3]

    top = sample(size // 2, 8)
    bottom = sample(size // 2, size - 9)
    bg = Image.new("RGB", (size, size))
    bg_px = bg.load()
    for y in range(size):
        t = y / (size - 1)
        row = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(size):
            bg_px[x, y] = row

    full = bg.copy().convert("RGBA")
    full = Image.alpha_composite(full, icon)
    full.save(out_icon)
    full.convert("RGB").save(out_launcher)

    fg_side = int(size * 0.82)
    fg_src = icon.resize((fg_side, fg_side), Image.Resampling.LANCZOS)
    foreground = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    foreground.paste(fg_src, ((size - fg_side) // 2, (size - fg_side) // 2), fg_src)
    foreground.save(out_foreground)

    print(
        "Wrote launcher assets:",
        out_icon.name,
        out_launcher.name,
        out_foreground.name,
    )


def main() -> None:
    if os.environ.get("BUILD_LAUNCHER") != "1":
        env = os.environ.copy()
        env["BUILD_LAUNCHER"] = "1"
        subprocess.check_call([str(_venv_python()), __file__], env=env, cwd=root)
        return
    _build()


if __name__ == "__main__":
    main()
