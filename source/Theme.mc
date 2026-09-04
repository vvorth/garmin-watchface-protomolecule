import Toybox.Graphics;
import Toybox.Lang;

//! Colour palette.
//!
//! Every value is picked from the 64 colour palette that Garmin MIP displays
//! (fenix 8 Solar) render natively, i.e. every channel is one of
//! 0x00 / 0x55 / 0xAA / 0xFF. Anything else gets dithered by the firmware and
//! looks grainy on the watch.
module Theme {
  const BACKGROUND as Number = 0x000000;

  const DATE as Number = 0x00FF00;

  //! Default clock colours. Both are overridable from the watch (hourColor /
  //! minuteColor properties, one of Data.clockColorChoices()).
  const HOURS as Number = 0xFFFFFF;
  const MINUTES as Number = 0x00FFFF;

  const TEXT as Number = 0xFFFFFF;
  //! Every secondary read-out (weather, Body Battery, steps, device battery).
  const TEXT_DIM as Number = 0xAAAAAA;
  const SEPARATOR as Number = 0x555555;

  const GRAPH as Number = 0x00FF00;

  const OFF as Number = 0x555555;
  const DND_ON as Number = 0xFF0000;
  const ALARM_ON as Number = 0xFFFF00;
  //! Note: 0xFF8000 is off the MIP 64-colour palette (green channel 0x80), so
  //! the panel dithers it slightly. Nearest clean orange is 0xFFAA00.
  const NOTIFICATION_ON as Number = 0xFF8000;
  //! The count sits on top of NOTIFICATION_ON — black reads, white does not.
  const NOTIFICATION_TEXT as Number = 0x000000;

  const ARC_BODY_BATTERY as Number = 0x00FF00;
  const ARC_DEVICE_BATTERY as Number = 0x00FFFF;
  const ARC_DAYLIGHT as Number = 0xFFFF00;

  //! Unfilled part of every bottom arc: shows how long the track is when full,
  //! so a partial fill can be read against it. Darkest grey the MIP panel has.
  const ARC_TRACK as Number = 0x555555;

  //! Arc thicknesses, in pixels. The coloured fill is a pixel thicker than the
  //! grey track and shares its outer edge, so a filled arc reads as slightly
  //! raised / glowing next to an empty one. ARC_EDGE_INSET keeps the outer edge
  //! a hair off the bezel so the full stroke is visible.
  const ARC_TRACK_PEN as Number = 2;
  const ARC_FILL_PEN as Number = 3;
  const ARC_EDGE_INSET as Number = 1;
}

//! Vertical layout of the face, as fractions of the screen height.
//!
//! The numbers were measured off the reference rendering; keeping them as
//! fractions makes the same face work on every round screen size.
module Layout {
  const DATE_Y as Float = 0.066;
  const SEP_1_Y as Float = 0.112;
  const WEATHER_Y as Float = 0.163;
  const SEP_2_Y as Float = 0.216;
  const GRAPH_TOP_Y as Float = 0.230;
  const GRAPH_BOTTOM_Y as Float = 0.318;
  const SEP_3_Y as Float = 0.334;
  const TIME_Y as Float = 0.507;
  const SEP_4_Y as Float = 0.678;
  const STATUS_Y as Float = 0.754;
  const SEP_5_Y as Float = 0.828;
  const BATTERY_Y as Float = 0.884;

  //! Radius of the circle that the separator ends follow, relative to the
  //! screen radius. Slightly inside the screen so lines never touch the bezel.
  const SEPARATOR_RADIUS as Float = 0.94;

  // Arc tracks along the bottom edge. Garmin measures degrees counter
  // clockwise from the 3 o'clock position, so 270 is the bottom of the screen.
  const ARC_LEFT_FROM as Number = 237; // body battery grows towards ARC_LEFT_TO
  const ARC_LEFT_TO as Number = 205;
  const ARC_CENTER as Number = 270; // device battery grows both ways from here
  const ARC_CENTER_SPREAD as Number = 23;
  // Daylight is anchored at the low end and grows up towards ARC_RIGHT_TO, so
  // it fills to full at sunrise and then retracts from the top down all day.
  const ARC_RIGHT_FROM as Number = 303;
  const ARC_RIGHT_TO as Number = 335;
}
