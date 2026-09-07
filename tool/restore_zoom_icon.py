"""Restore the pre-dd217b6 book icon and make a zoomed Android/iOS source."""

from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OLD_SPEC = "4d43318:assets/app_icon.png"


def git_show(spec: str) -> bytes:
    return subprocess.check_output(["git", "show", spec], cwd=ROOT)


def content_bbox(im: Image.Image) -> tuple[int, int, int, int]:
    rgba = im.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    minx, miny, maxx, maxy = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 20 and (r + g + b) > 40:
                minx = min(minx, x)
                miny = min(miny, y)
                maxx = max(maxx, x)
                maxy = max(maxy, y)
    if maxx < minx:
        raise RuntimeError("no opaque icon content")
    return minx, miny, maxx + 1, maxy + 1


def zoom_full_book(src: Image.Image, size: int, extra: float = 1.0) -> Image.Image:
    """Crop to the book and scale the whole book to fill the canvas height."""
    box = content_bbox(src)
    book = src.convert("RGBA").crop(box)
    bw, bh = book.size
    scale = (size / bh) * extra
    nw, nh = max(1, int(bw * scale)), max(1, int(bh * scale))
    scaled = book.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    x = (size - nw) // 2
    y = (size - nh) // 2
    canvas.paste(scaled, (x, y), scaled)
    if nw > size or nh > size:
        left = max(0, -x)
        top = max(0, -y)
        canvas = canvas.crop((left, top, left + size, top + size))
        if canvas.size != (size, size):
            padded = Image.new("RGBA", (size, size), (0, 0, 0, 255))
            padded.paste(canvas, (0, 0))
            canvas = padded
    return canvas


def main() -> None:
    old = Image.open(__import__("io").BytesIO(git_show(OLD_SPEC))).convert("RGBA")
    assets = ROOT / "assets"
    assets.mkdir(exist_ok=True)

    # Desktop / in-app: original restored artwork.
    old.save(assets / "app_icon.png", "PNG")

    # Phone launchers: drop leftover black margin so the whole book fills height.
    zoom_full_book(old, 1024, extra=1.0).save(assets / "app_icon_android.png", "PNG")
    zoom_full_book(old, 1024, extra=1.0).save(assets / "app_icon_ios.png", "PNG")

    # Keep the Windows PNG in sync with the restored desktop art.
    win_png = ROOT / "windows" / "runner" / "resources" / "app_icon.png"
    win_png.parent.mkdir(parents=True, exist_ok=True)
    old.save(win_png, "PNG")

    print("restored", assets / "app_icon.png", old.size)
    print("android zoom", Image.open(assets / "app_icon_android.png").size)
    print("ios zoom", Image.open(assets / "app_icon_ios.png").size)


if __name__ == "__main__":
    main()
