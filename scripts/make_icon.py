"""Reproduce the original mosque icon. Requires Pillow; no downloaded artwork."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "PrayerTime" / "Assets.xcassets"
BLUE = (0, 122, 255)  # Apple's default system blue on a light background.
PALETTE = {
    "blue": BLUE, "indigo": (88, 86, 214), "purple": (175, 82, 222),
    "pink": (255, 45, 85), "red": (255, 59, 48), "orange": (255, 149, 0),
    "yellow": (255, 204, 0), "green": (52, 199, 89), "teal": (48, 176, 199),
}


def mark(background, foreground=BLUE):
    image = Image.new("RGBA", (1024, 1024), background)
    draw = ImageDraw.Draw(image)
    # A quiet, geometric masjid: one dome, one minaret, one doorway.
    draw.rectangle((282, 507, 736, 751), fill=foreground)
    draw.pieslice((282, 304, 736, 710), 180, 360, fill=foreground)
    draw.rectangle((504, 260, 520, 325), fill=foreground)
    draw.ellipse((493, 239, 531, 277), fill=foreground)
    draw.rectangle((203, 405, 253, 751), fill=foreground)
    draw.polygon([(194, 405), (228, 326), (262, 405)], fill=foreground)
    draw.rectangle((192, 448, 264, 470), fill=foreground)
    draw.rounded_rectangle((465, 592, 559, 817), radius=47, fill=background)
    draw.rectangle((465, 651, 559, 760), fill=background)
    draw.rectangle((195, 751, 751, 777), fill=foreground)
    # Keep the base continuous; the door stops at its top edge.
    return image


def luminance(rgb):
    values = [v / 255 for v in rgb]
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in values]
    return sum(v * w for v, w in zip(linear, (0.2126, 0.7152, 0.0722)))


def contrast(first, second):
    a, b = sorted((luminance(first), luminance(second)))
    return (b + 0.05) / (a + 0.05)


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
    for name, colour in PALETTE.items():
        white, dark = (255, 255, 255), (28, 28, 30)
        background = white if name == "blue" else max((white, dark), key=lambda bg: contrast(colour, bg))
        assert contrast(colour, background) >= 3, name
        icon = mark(background, colour).convert("RGB")
        app = ASSETS / ("AppIcon.appiconset" if name == "blue" else f"AppIcon-{name}.appiconset")
        app.mkdir(exist_ok=True)
        icon.save(app / "AppIcon.png")
        (app / "Contents.json").write_text(json.dumps({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}, indent=2))
        preview = ASSETS / f"IconPreview-{name}.imageset"
        preview.mkdir(exist_ok=True)
        icon.resize((264, 264), Image.Resampling.LANCZOS).save(preview / "preview.png")
        (preview / "Contents.json").write_text(json.dumps({"images": [{"filename": "preview.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, indent=2))
    content = ASSETS / "MosqueMark.imageset"
    content.mkdir(exist_ok=True)
    mark((0, 0, 0, 0)).save(content / "MosqueMark.png")
    (content / "Contents.json").write_text(json.dumps({"images": [{"filename": "MosqueMark.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, indent=2))


if __name__ == "__main__":
    main()
