"""ひとつみ アプリアイコン(案A 積画)を 1024px で書き出す。

「一」の画を3本積み上げ、最上段だけを藍にする。
最上段 = 今日積んだひとつ。下へ向かって長くなることで積み上がりの安定感を出す。
"""

from PIL import Image, ImageDraw

SIZE = 1024
S = SIZE / 120.0  # 120 の設計座標系から 1024 へのスケール

PAPER = (246, 243, 234)  # #F6F3EA 和紙
SUMI = (28, 26, 23)      # #1C1A17 墨
AI = (29, 78, 137)       # #1D4E89 藍

# (x, y, w, h, color) — 設計座標系(120)。上段が藍、下二段が墨。
# 段の間隔(5)は画の高さ(12)より狭くし、「並んでいる」ではなく「積まれている」に見せる。
BARS = [
    (23.0, 71.0, 74.0, 12.0, SUMI),   # 下段
    (32.0, 54.0, 56.0, 12.0, SUMI),   # 中段
    (41.0, 37.0, 38.0, 12.0, AI),     # 上段 = 今日
]


def main() -> None:
    # 4倍で描いてから縮小し、角丸のジャギーを消す
    scale = 4
    img = Image.new("RGB", (SIZE * scale, SIZE * scale), PAPER)
    draw = ImageDraw.Draw(img)

    for x, y, w, h, color in BARS:
        x0 = x * S * scale
        y0 = y * S * scale
        x1 = (x + w) * S * scale
        y1 = (y + h) * S * scale
        radius = (h / 2) * S * scale
        draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=color)

    img = img.resize((SIZE, SIZE), Image.LANCZOS)

    out = "/Users/taguchi/ai-work/ai-workspace/ta1/design/app-icon-1024.png"
    img.save(out, "PNG")
    print(f"saved: {out} {img.size} mode={img.mode}")


if __name__ == "__main__":
    main()
