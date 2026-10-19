"""Reproduce the original mosque icon. Requires Pillow; no downloaded artwork."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "PrayerTime" / "Assets.xcassets"
BLUE = (0, 122, 255)  # Apple's default system blue on a light background.


def mark(background):
    image = Image.new("RGBA", (1024, 1024), background)
    draw = ImageDraw.Draw(image)
    # A quiet, geometric masjid: one dome, one minaret, one doorway.
    draw.rectangle((282, 507, 736, 751), fill=BLUE)
    draw.pieslice((282, 304, 736, 710), 180, 360, fill=BLUE)
    draw.rectangle((504, 260, 520, 325), fill=BLUE)
    draw.ellipse((493, 239, 531, 277), fill=BLUE)
    draw.rectangle((203, 405, 253, 751), fill=BLUE)
    draw.polygon([(194, 405), (228, 326), (262, 405)], fill=BLUE)
    draw.rectangle((192, 448, 264, 470), fill=BLUE)
    draw.rounded_rectangle((465, 592, 559, 817), radius=47, fill=background)
    draw.rectangle((465, 651, 559, 760), fill=background)
    draw.rectangle((195, 751, 751, 777), fill=BLUE)
    # Keep the base continuous; the door stops at its top edge.
    return image


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
    app = ASSETS / "AppIcon.appiconset"
    app.mkdir(exist_ok=True)
    mark("white").convert("RGB").save(app / "AppIcon.png")
    (app / "Contents.json").write_text(json.dumps({"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}, indent=2))
    content = ASSETS / "MosqueMark.imageset"
    content.mkdir(exist_ok=True)
    mark((0, 0, 0, 0)).save(content / "MosqueMark.png")
    (content / "Contents.json").write_text(json.dumps({"images": [{"filename": "MosqueMark.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, indent=2))


if __name__ == "__main__":
    main()
