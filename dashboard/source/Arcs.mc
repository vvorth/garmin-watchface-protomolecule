import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! The three progress arcs that hug the bottom edge of the screen.
//!
//! Garmin measures arc degrees counter clockwise from 3 o'clock, so 270 is the
//! bottom of the screen, values below it lie to the right and values above it
//! to the left.
//!
//! Each arc is a grey track (its full length when the metric is at 100%) with a
//! coloured fill on top. The fill is a pixel thicker and shares the track's
//! outer edge, so it reads as slightly raised. All three tracks are always
//! drawn, even one whose metric the device cannot supply, for symmetry.
module Arcs {
  //! Anything shorter than this is not worth a draw call and would make
  //! drawArc treat start == end as a full circle.
  const MIN_SWEEP as Float = 0.75;

  function draw(dc as Graphics.Dc, cx as Numeric, cy as Numeric, screenRadius as Numeric, bodyBattery as Float?, deviceBattery as Float, daylight as Float?) as Void {
    var outer = screenRadius - Theme.ARC_EDGE_INSET;
    var rTrack = outer - Theme.ARC_TRACK_PEN / 2.0;
    var rFill = outer - Theme.ARC_FILL_PEN / 2.0;

    track(dc, cx, cy, rTrack, Layout.ARC_LEFT_FROM, Layout.ARC_LEFT_TO);
    track(dc, cx, cy, rTrack, Layout.ARC_CENTER - Layout.ARC_CENTER_SPREAD, Layout.ARC_CENTER + Layout.ARC_CENTER_SPREAD);
    track(dc, cx, cy, rTrack, Layout.ARC_RIGHT_FROM, Layout.ARC_RIGHT_TO);

    // Left: Body Battery, growing from the bottom end upwards.
    if (bodyBattery != null) {
      sweep(dc, cx, cy, rFill, Theme.ARC_BODY_BATTERY, Layout.ARC_LEFT_FROM, Layout.ARC_LEFT_TO, bodyBattery);
    }

    // Centre: device battery, growing out of the 6 o'clock position both ways.
    var spread = Layout.ARC_CENTER_SPREAD * clamp(deviceBattery);
    if (spread >= MIN_SWEEP) {
      dc.setColor(Theme.ARC_DEVICE_BATTERY, Graphics.COLOR_TRANSPARENT);
      strokeArc(dc, cx, cy, rFill, Theme.ARC_FILL_PEN, Layout.ARC_CENTER, Layout.ARC_CENTER - spread);
      strokeArc(dc, cx, cy, rFill, Theme.ARC_FILL_PEN, Layout.ARC_CENTER, Layout.ARC_CENTER + spread);
    }

    // Right: daylight left, full at sunrise and empty at sunset.
    if (daylight != null) {
      sweep(dc, cx, cy, rFill, Theme.ARC_DAYLIGHT, Layout.ARC_RIGHT_FROM, Layout.ARC_RIGHT_TO, daylight);
    }

    dc.setPenWidth(1);
  }

  //! The full length of an arc, in the unfilled colour.
  function track(dc as Graphics.Dc, cx as Numeric, cy as Numeric, r as Numeric, from as Number, to as Number) as Void {
    dc.setColor(Theme.ARC_TRACK, Graphics.COLOR_TRANSPARENT);
    strokeArc(dc, cx, cy, r, Theme.ARC_TRACK_PEN, from, to);
  }

  //! `fraction` of the arc from `from` to `to`, always starting at `from`.
  function sweep(dc as Graphics.Dc, cx as Numeric, cy as Numeric, r as Numeric, color as Number, from as Number, to as Number, fraction as Float) as Void {
    var length = (to - from) * clamp(fraction);
    if (length > -MIN_SWEEP && length < MIN_SWEEP) {
      return;
    }
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    strokeArc(dc, cx, cy, r, Theme.ARC_FILL_PEN, from, from + length);
  }

  //! One arc segment with rounded ends. Dc.drawArc has no cap style, so a disc
  //! the width of the stroke is dropped on each end. Uses the current colour.
  function strokeArc(dc as Graphics.Dc, cx as Numeric, cy as Numeric, r as Numeric, pen as Number, fromDeg as Numeric, toDeg as Numeric) as Void {
    dc.setPenWidth(pen);
    var direction = toDeg > fromDeg ? Graphics.ARC_COUNTER_CLOCKWISE : Graphics.ARC_CLOCKWISE;
    dc.drawArc(cx, cy, r, direction, fromDeg, toDeg);
    cap(dc, cx, cy, r, pen, fromDeg);
    cap(dc, cx, cy, r, pen, toDeg);
  }

  function cap(dc as Graphics.Dc, cx as Numeric, cy as Numeric, r as Numeric, pen as Number, deg as Numeric) as Void {
    var a = Math.toRadians(deg);
    dc.fillCircle(cx + r * Math.cos(a), cy - r * Math.sin(a), pen / 2.0);
  }

  function clamp(fraction as Float) as Float {
    if (fraction < 0.0) {
      return 0.0;
    }
    return fraction > 1.0 ? 1.0 : fraction;
  }
}
