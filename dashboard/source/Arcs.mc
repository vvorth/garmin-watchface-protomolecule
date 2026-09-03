import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! The three progress arcs that hug the bottom edge of the screen.
//!
//! Garmin measures arc degrees counter clockwise from 3 o'clock, so 270 is the
//! bottom of the screen, values below it lie to the right and values above it
//! to the left.
module Arcs {
  //! Anything shorter than this is not worth a draw call and would make
  //! drawArc treat start == end as a full circle.
  const MIN_SWEEP as Float = 0.75;

  function draw(dc as Graphics.Dc, cx as Numeric, cy as Numeric, radius as Numeric, pen as Number, bodyBattery as Float?, deviceBattery as Float, daylight as Float?) as Void {
    dc.setPenWidth(pen);

    // Left: body battery, growing from the bottom end upwards.
    if (bodyBattery != null) {
      sweep(dc, cx, cy, radius, Theme.ARC_BODY_BATTERY, Layout.ARC_LEFT_FROM, Layout.ARC_LEFT_TO, bodyBattery);
    }

    // Centre: device battery, growing out of the 6 o'clock position both ways.
    var spread = Layout.ARC_CENTER_SPREAD * clamp(deviceBattery);
    if (spread >= MIN_SWEEP) {
      dc.setColor(Theme.ARC_DEVICE_BATTERY, Graphics.COLOR_TRANSPARENT);
      dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, Layout.ARC_CENTER, Layout.ARC_CENTER - spread);
      dc.drawArc(cx, cy, radius, Graphics.ARC_COUNTER_CLOCKWISE, Layout.ARC_CENTER, Layout.ARC_CENTER + spread);
    }

    // Right: daylight left, full at sunrise and empty at sunset.
    if (daylight != null) {
      sweep(dc, cx, cy, radius, Theme.ARC_DAYLIGHT, Layout.ARC_RIGHT_FROM, Layout.ARC_RIGHT_TO, daylight);
    }

    dc.setPenWidth(1);
  }

  //! Draws `fraction` of the track that runs from `from` to `to`, always
  //! starting at `from`.
  function sweep(dc as Graphics.Dc, cx as Numeric, cy as Numeric, radius as Numeric, color as Number, from as Number, to as Number, fraction as Float) as Void {
    var length = (to - from) * clamp(fraction);
    if (length > -MIN_SWEEP && length < MIN_SWEEP) {
      return;
    }
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    var direction = length > 0 ? Graphics.ARC_COUNTER_CLOCKWISE : Graphics.ARC_CLOCKWISE;
    dc.drawArc(cx, cy, radius, direction, from, from + length);
  }

  function clamp(fraction as Float) as Float {
    if (fraction < 0.0) {
      return 0.0;
    }
    return fraction > 1.0 ? 1.0 : fraction;
  }
}
