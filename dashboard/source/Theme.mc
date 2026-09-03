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
  const HOURS as Number = 0xFFFFFF;
  const MINUTES as Number = 0x00FFFF;

  const TEXT as Number = 0xFFFFFF;
  const TEXT_DIM as Number = 0xAAAAAA;
  const SEPARATOR as Number = 0x555555;

  const GRAPH as Number = 0x00FF00;

  const OFF as Number = 0x555555;
  const DND_ON as Number = 0xFF0000;
  const ALARM_ON as Number = 0xFFFF00;
  const NOTIFICATION_ON as Number = 0xFF5500;

  const ARC_BODY_BATTERY as Number = 0x00FF00;
  const ARC_DEVICE_BATTERY as Number = 0x00FFFF;
  const ARC_DAYLIGHT as Number = 0xFFFF00;

  //! Unfilled part of every bottom arc: shows how long the track is when full,
  //! so a partial fill can be read against it. Darkest grey the MIP panel has.
  const ARC_TRACK as Number = 0x555555;
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
  const GRAPH_TOP_Y as Float = 0.232;
  const GRAPH_BOTTOM_Y as Float = 0.324;
  const SEP_3_Y as Float = 0.342;
  const TIME_Y as Float = 0.506;
  const SEP_4_Y as Float = 0.670;
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
  const ARC_RIGHT_FROM as Number = 303; // daylight grows towards ARC_RIGHT_TO
  const ARC_RIGHT_TO as Number = 335;
}
