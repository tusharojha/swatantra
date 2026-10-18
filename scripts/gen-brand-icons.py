#!/usr/bin/env python3
"""Resize assets/logo.png into web favicon + copy for README/web.

flutter_launcher_icons writes a 16×16 favicon that muddies the mandala.
Run this *after* that generator.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "logo.png"
PAPER = (255, 251, 250)


def flatten(im: Image.Image, size: int) -> Image.Image:
    rgba = im.convert("RGBA")
    resized = rgba.resize((size, size), Image.Resampling.LANCZOS)
    bg = Image.new("RGB", (size, size), PAPER)
    bg.paste(resized, mask=resized.split()[-1])
    return bg


def main() -> None:
    im = Image.open(SRC)
    web = ROOT / "app" / "web"
    web.mkdir(parents=True, exist_ok=True)
    flatten(im, 32).save(web / "favicon.png", optimize=True)
    flatten(im, 64).save(web / "favicon-64.png", optimize=True)
    # Keep a full-resolution copy next to the web icons for the README/header.
    dst = web / "logo.png"
    if SRC.resolve() != dst.resolve():
        dst.write_bytes(SRC.read_bytes())
    app_asset = ROOT / "app" / "assets" / "logo.png"
    app_asset.parent.mkdir(parents=True, exist_ok=True)
    if SRC.resolve() != app_asset.resolve():
        app_asset.write_bytes(SRC.read_bytes())
    print("wrote", web / "favicon.png", web / "favicon-64.png")


if __name__ == "__main__":
    main()
