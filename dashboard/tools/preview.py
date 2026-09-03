#!/usr/bin/env python3
"""Render a static preview of the watch face without the Connect IQ simulator.

This mirrors the geometry in source/DashboardView.mc one-to-one, so it is a
quick way to check spacing and proportions after changing the fractions in
source/Theme.mc. It is a drawing mock, not an emulator: the system font metrics
are approximations of the ones a 260x260 fenix reports.

    python3 tools/preview.py out.png
"""

import math
import sys

from PIL import Image, ImageDraw, ImageFont

W = H = 260
CX = CY = W // 2
R = W // 2

FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# Rough stand-ins for the Garmin system fonts on a 260x260 screen, in the same
# order as Fonts.TIME / Fonts.ROW (largest first).
TIME_FONTS = [85, 65, 50, 34, 32]
ROW_FONTS = [27, 23, 21, 16]

# source/Theme.mc
BACKGROUND = (0, 0, 0)
DATE = (0, 255, 0)
HOURS = (255, 255, 255)
MINUTES = (0, 255, 255)
TEXT = (255, 255, 255)
TEXT_DIM = (170, 170, 170)
SEPARATOR = (85, 85, 85)
GRAPH = (0, 255, 0)
OFF = (85, 85, 85)
DND_ON = (255, 0, 0)
ALARM_ON = (255, 255, 0)
NOTIFICATION_ON = (255, 85, 0)
ARC_BODY_BATTERY = (0, 255, 0)
ARC_DEVICE_BATTERY = (0, 255, 255)
ARC_DAYLIGHT = (255, 255, 0)

# source/Theme.mc, module Layout
DATE_Y = 0.078
SEP_1_Y = 0.12
WEATHER_Y = 0.182
SEP_2_Y = 0.238
GRAPH_TOP_Y = 0.252
GRAPH_BOTTOM_Y = 0.348
SEP_3_Y = 0.364
TIME_Y = 0.508
SEP_4_Y = 0.652
STATUS_Y = 0.748
SEP_5_Y = 0.828
BATTERY_Y = 0.898
SEPARATOR_RADIUS = 0.94

ARC_LEFT_FROM, ARC_LEFT_TO = 240, 200
ARC_CENTER, ARC_CENTER_SPREAD = 270, 25
ARC_RIGHT_FROM, ARC_RIGHT_TO = 300, 340

SCALE = 4  # supersampling, purely a preview nicety


def font(size):
    return ImageFont.truetype(FONT_PATH, int(size * SCALE * 0.78))


def text_size(draw, string, size):
    box = draw.textbbox((0, 0), string, font=font(size))
    return box[2] - box[0], size * SCALE


def fit(draw, candidates, sample, max_width, max_height):
    for size in candidates:
        w, h = text_size(draw, sample, size)
        if w <= max_width * SCALE and h <= max_height * SCALE:
            return size
    return candidates[-1]


def chord(y):
    r = R * SEPARATOR_RADIUS
    dy = y - CY
    squared = r * r - dy * dy
    return 0 if squared <= 0 else math.sqrt(squared)


class Canvas:
    """Thin wrapper so the drawing code reads like the Monkey C Dc calls."""

    def __init__(self):
        self.image = Image.new("RGB", (W * SCALE, H * SCALE), BACKGROUND)
        self.d = ImageDraw.Draw(self.image)

    def line(self, x1, y1, x2, y2, color, width=1):
        self.d.line([x1 * SCALE, y1 * SCALE, x2 * SCALE, y2 * SCALE], fill=color, width=int(width * SCALE))

    def rect(self, x, y, w, h, color):
        self.d.rectangle([x * SCALE, y * SCALE, (x + w) * SCALE, (y + h) * SCALE], fill=color)

    def circle(self, x, y, r, color):
        self.d.ellipse([(x - r) * SCALE, (y - r) * SCALE, (x + r) * SCALE, (y + r) * SCALE], fill=color)

    def ring(self, x, y, r, color, width):
        self.d.ellipse(
            [(x - r) * SCALE, (y - r) * SCALE, (x + r) * SCALE, (y + r) * SCALE],
            outline=color,
            width=int(width * SCALE),
        )

    def polygon(self, points, color):
        self.d.polygon([(x * SCALE, y * SCALE) for x, y in points], fill=color)

    def rounded(self, x, y, w, h, radius, color, filled=True, width=1):
        box = [x * SCALE, y * SCALE, (x + w) * SCALE, (y + h) * SCALE]
        if filled:
            self.d.rounded_rectangle(box, radius=radius * SCALE, fill=color)
        else:
            self.d.rounded_rectangle(box, radius=radius * SCALE, outline=color, width=int(width * SCALE))

    def arc(self, x, y, r, color, start, end, width):
        """Garmin degrees: counter clockwise from 3 o'clock."""
        box = [(x - r) * SCALE, (y - r) * SCALE, (x + r) * SCALE, (y + r) * SCALE]
        a, b = sorted((-start, -end))
        self.d.arc(box, start=a, end=b, fill=color, width=int(width * SCALE))

    def text(self, x, y, size, string, color, align="left", valign="middle"):
        f = font(size)
        box = self.d.textbbox((0, 0), string, font=f)
        w, h = box[2] - box[0], box[3] - box[1]
        px = x * SCALE
        py = y * SCALE
        if align == "center":
            px -= w / 2
        elif align == "right":
            px -= w
        if valign == "middle":
            py -= h / 2
        self.d.text((px - box[0], py - box[1]), string, font=f, fill=color)


def separator(c, fraction):
    y = round(fraction * H)
    half = chord(y)
    if half < 4:
        return
    c.line(CX - half, y, CX + half, y, SEPARATOR, 1)


def sun(c, x, y, r, color):
    c.circle(x, y, r * 0.4, color)
    for i in range(8):
        a = i * math.pi / 4
        dx, dy = math.cos(a), math.sin(a)
        c.line(x + dx * r * 0.64, y - dy * r * 0.64, x + dx * r, y - dy * r, color, max(1, round(r * 0.2)))


def do_not_disturb(c, x, y, r, color):
    c.circle(x, y - r * 0.14, r * 0.44, color)
    c.polygon(
        [
            (x - r * 0.68, y + r * 0.42),
            (x - r * 0.44, y + r * 0.14),
            (x - r * 0.44, y - r * 0.14),
            (x + r * 0.44, y - r * 0.14),
            (x + r * 0.44, y + r * 0.14),
            (x + r * 0.68, y + r * 0.42),
        ],
        color,
    )
    c.circle(x, y - r * 0.68, r * 0.13, color)
    c.circle(x, y + r * 0.62, r * 0.17, color)
    c.line(x - r * 0.9, y + r * 0.9, x + r * 0.9, y - r * 0.9, BACKGROUND, max(1, round(r * 0.3)))
    c.line(x - r * 0.86, y + r * 0.86, x + r * 0.86, y - r * 0.86, color, max(1, round(r * 0.16)))


def alarm(c, x, y, r, color):
    stroke = max(1, round(r * 0.18))
    c.ring(x, y + r * 0.1, r * 0.66, color, stroke)
    c.line(x - r * 0.72, y - r * 0.44, x - r * 0.4, y - r * 0.72, color, stroke)
    c.line(x + r * 0.72, y - r * 0.44, x + r * 0.4, y - r * 0.72, color, stroke)
    c.line(x, y + r * 0.1, x, y - r * 0.3, color, stroke)
    c.line(x, y + r * 0.1, x + r * 0.34, y + r * 0.24, color, stroke)


def notification(c, x, y, r, color, filled):
    tail = [(x - r * 0.2, y + r * 0.44), (x + r * 0.2, y + r * 0.44), (x - r * 0.06, y + r * 1.0)]
    if filled:
        c.rounded(x - r * 0.86, y - r * 0.72, r * 1.72, r * 1.24, r * 0.3, color)
        c.polygon(tail, color)
    else:
        c.rounded(x - r * 0.86, y - r * 0.72, r * 1.72, r * 1.24, r * 0.3, color, filled=False, width=max(1, round(r * 0.16)))
        c.line(tail[0][0], tail[0][1], tail[2][0], tail[2][1], color, max(1, round(r * 0.16)))
        c.line(tail[1][0], tail[1][1], tail[2][0], tail[2][1], color, max(1, round(r * 0.16)))


def draw_graph(c, values, is_percentage, color):
    top, bottom = GRAPH_TOP_Y * H, GRAPH_BOTTOM_Y * H
    bar = max(2, round(W * 0.0154))
    step = bar + max(2, round(W * 0.0192))
    count = len(values)
    total = count * step - (step - bar)
    x = CX - total / 2
    height = bottom - top
    if is_percentage:
        low, high = 0.0, 100.0
    else:
        present = [v for v in values if v is not None]
        low, high = min(present), max(present)
        if high - low < 0.001:
            low, high = low - 0.5, high + 0.5
    for i, value in enumerate(values):
        left = x + i * step
        if value is None:
            c.rect(left, bottom - 1, bar, 1, color)
            continue
        norm = min(1.0, max(0.0, (value - low) / (high - low)))
        bar_h = height * (0.12 + 0.88 * norm)
        c.rect(left, bottom - bar_h, bar, bar_h, color)


def draw_arcs(c, body_battery, device_battery, daylight):
    pen = max(3, round(W * 0.023))
    radius = R - pen / 2 - 1
    if body_battery is not None:
        length = (ARC_LEFT_TO - ARC_LEFT_FROM) * body_battery
        c.arc(CX, CY, radius, ARC_BODY_BATTERY, ARC_LEFT_FROM, ARC_LEFT_FROM + length, pen)
    spread = ARC_CENTER_SPREAD * device_battery
    if spread >= 0.75:
        c.arc(CX, CY, radius, ARC_DEVICE_BATTERY, ARC_CENTER - spread, ARC_CENTER + spread, pen)
    if daylight is not None:
        length = (ARC_RIGHT_TO - ARC_RIGHT_FROM) * daylight
        c.arc(CX, CY, radius, ARC_DAYLIGHT, ARC_RIGHT_FROM, ARC_RIGHT_FROM + length, pen)


def render(path):
    c = Canvas()
    d = c.d

    time_band = (SEP_4_Y - SEP_3_Y) * H
    time_font = fit(d, TIME_FONTS, "88 88", chord(TIME_Y * H) * 2, time_band)
    row_font = fit(d, ROW_FONTS, "88.8k", W * 0.3, H * 0.095)
    small_font = fit(d, ROW_FONTS, "888% 888°", W * 0.44, H * 0.078)
    badge_font = fit(d, ROW_FONTS, "88", W * 0.06, H * 0.055)

    for fraction in (SEP_1_Y, SEP_2_Y, SEP_3_Y, SEP_4_Y, SEP_5_Y):
        separator(c, fraction)

    # Date
    c.text(CX, DATE_Y * H, small_font, "Thu 3 Sep", DATE, align="center")

    # Weather
    y = WEATHER_Y * H
    icon_r = W * 0.042
    gap = W * 0.026
    pieces = [("27°", TEXT), ("40%", TEXT), None, ("21°", TEXT), ("4°", TEXT_DIM)]
    total = icon_r * 2
    for piece in pieces:
        if piece is not None:
            total += text_size(d, piece[0], small_font)[0] / SCALE + gap
    x = CX - total / 2
    for piece in pieces:
        if piece is None:
            sun(c, x + icon_r, y, icon_r, TEXT)
            x += icon_r * 2 + gap
        else:
            c.text(x, y, small_font, piece[0], piece[1])
            x += text_size(d, piece[0], small_font)[0] / SCALE + gap

    # Graph: a plausible heart rate trace with one gap.
    series = [58, 61, 55, None, 62, 66, 72, 95, 90, 88, 92, 87, 91, 86, 89, 84, 88, 83, 86, 78, 74, 70, 66, 63, 60]
    half = chord(GRAPH_BOTTOM_Y * H)
    count = max(6, int(half * 2 / (max(2, round(W * 0.0154)) + max(2, round(W * 0.0192)))))
    series = (series * ((count // len(series)) + 1))[:count]
    draw_graph(c, series, False, GRAPH)

    # Time
    hours, minutes = "11", "29"
    gap = W * 0.012
    hw = text_size(d, hours, time_font)[0] / SCALE
    mw = text_size(d, minutes, time_font)[0] / SCALE
    x = CX - (hw + gap + mw) / 2
    c.text(x, TIME_Y * H, time_font, hours, HOURS)
    c.text(x + hw + gap, TIME_Y * H, time_font, minutes, MINUTES)

    # Status row
    y = STATUS_Y * H
    icon_r = W * 0.043
    c.text(W * 0.2, y, row_font, "35", TEXT, align="center")
    do_not_disturb(c, W * 0.395, y, icon_r, DND_ON)
    alarm(c, W * 0.545, y, icon_r, ALARM_ON)
    c.text(W * 0.8, y, row_font, "6.8k", TEXT, align="center")

    # Battery row
    y = BATTERY_Y * H
    c.text(W * 0.375, y, small_font, "0d", TEXT, align="center")
    c.text(W * 0.625, y, small_font, "9%", TEXT, align="center")
    radius = W * 0.045
    notification(c, CX, y, radius, NOTIFICATION_ON, True)
    c.text(CX, y - radius * 0.1, badge_font, "1", TEXT, align="center")

    draw_arcs(c, 0.35, 0.09, 0.2)

    # Mask everything outside the round screen.
    mask = Image.new("L", c.image.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, W * SCALE - 1, H * SCALE - 1], fill=255)
    out = Image.new("RGB", c.image.size, (20, 20, 20))
    out.paste(c.image, (0, 0), mask)
    out.resize((W, H), Image.LANCZOS).save(path)
    print("wrote", path)


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "preview.png")
