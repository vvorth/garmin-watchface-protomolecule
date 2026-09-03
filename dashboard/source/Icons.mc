import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Every icon on this face is drawn from primitives instead of being shipped
//! as a bitmap. That keeps the resource bundle empty, and the icons stay sharp
//! on any screen size because they scale with `r` (the icon radius in pixels).
module Icons {
  // Icon groups the many Weather.CONDITION_* values collapse into.
  const SUN as Number = 0;
  const PARTLY_CLOUDY as Number = 1;
  const CLOUDY as Number = 2;
  const RAIN as Number = 3;
  const SNOW as Number = 4;
  const STORM as Number = 5;
  const FOG as Number = 6;
  const WIND as Number = 7;

  //! Map a Toybox.Weather condition onto one of the icon groups above.
  //!
  //! The raw numbers are the documented values of the Weather.CONDITION_*
  //! constants. They are spelled out here rather than referenced by name so
  //! that a device whose SDK is missing one of the rarer constants still
  //! compiles; the constant each value belongs to is named in the comments.
  function forCondition(condition as Number?) as Number {
    if (condition == null) {
      return CLOUDY;
    }
    switch (condition) {
      case 0: // CLEAR
      case 22: // PARTLY_CLEAR
      case 23: // MOSTLY_CLEAR
      case 40: // FAIR
        return SUN;
      case 1: // PARTLY_CLOUDY
      case 52: // THIN_CLOUDS
        return PARTLY_CLOUDY;
      case 2: // MOSTLY_CLOUDY
      case 20: // CLOUDY
        return CLOUDY;
      case 3: // RAIN
      case 11: // SCATTERED_SHOWERS
      case 13: // UNKNOWN_PRECIPITATION
      case 14: // LIGHT_RAIN
      case 15: // HEAVY_RAIN
      case 24: // LIGHT_SHOWERS
      case 25: // SHOWERS
      case 26: // HEAVY_SHOWERS
      case 27: // CHANCE_OF_SHOWERS
      case 31: // DRIZZLE
      case 45: // CLOUDY_CHANCE_OF_RAIN
        return RAIN;
      case 4: // SNOW
      case 7: // WINTRY_MIX
      case 10: // HAIL
      case 16: // LIGHT_SNOW
      case 17: // HEAVY_SNOW
      case 18: // LIGHT_RAIN_SNOW
      case 19: // HEAVY_RAIN_SNOW
      case 21: // RAIN_SNOW
      case 34: // ICE
      case 43: // CHANCE_OF_SNOW
      case 44: // CHANCE_OF_RAIN_SNOW
      case 46: // CLOUDY_CHANCE_OF_SNOW
      case 47: // CLOUDY_CHANCE_OF_RAIN_SNOW
      case 48: // FLURRIES
      case 49: // FREEZING_RAIN
      case 50: // SLEET
      case 51: // ICE_SNOW
        return SNOW;
      case 6: // THUNDERSTORMS
      case 12: // SCATTERED_THUNDERSTORMS
      case 28: // CHANCE_OF_THUNDERSTORMS
      case 32: // TORNADO
      case 41: // HURRICANE
      case 42: // TROPICAL_STORM
        return STORM;
      case 8: // FOG
      case 9: // HAZY
      case 29: // MIST
      case 33: // SMOKE
      case 39: // HAZE
        return FOG;
      case 5: // WINDY
      case 30: // DUST
      case 35: // SAND
      case 36: // SQUALL
      case 37: // SANDSTORM
      case 38: // VOLCANIC_ASH
        return WIND;
      default:
        return CLOUDY;
    }
  }

  function weather(dc as Graphics.Dc, group as Number, x as Numeric, y as Numeric, r as Numeric, color as Number) as Void {
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    switch (group) {
      case SUN:
        sun(dc, x, y, r);
        break;
      case PARTLY_CLOUDY:
        sun(dc, x + r * 0.34, y - r * 0.36, r * 0.55);
        cloud(dc, x - r * 0.14, y + r * 0.22, r * 0.82);
        break;
      case CLOUDY:
        cloud(dc, x, y + r * 0.1, r);
        break;
      case RAIN:
        cloud(dc, x, y - r * 0.16, r * 0.9);
        drops(dc, x, y + r * 0.62, r);
        break;
      case SNOW:
        cloud(dc, x, y - r * 0.16, r * 0.9);
        flakes(dc, x, y + r * 0.66, r);
        break;
      case STORM:
        cloud(dc, x, y - r * 0.2, r * 0.9);
        bolt(dc, x, y + r * 0.6, r);
        break;
      case FOG:
        cloud(dc, x, y - r * 0.24, r * 0.82);
        bars(dc, x, y + r * 0.58, r);
        break;
      case WIND:
        bars(dc, x, y, r * 1.25);
        break;
    }
  }

  //! Filled disc with eight rays, matching the starburst in the reference.
  function sun(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric) as Void {
    dc.fillCircle(x, y, r * 0.4);
    dc.setPenWidth(penWidth(r * 0.2));
    for (var i = 0; i < 8; i++) {
      var a = (i * Math.PI) / 4.0;
      var dx = Math.cos(a);
      var dy = Math.sin(a);
      dc.drawLine(x + dx * r * 0.64, y - dy * r * 0.64, x + dx * r, y - dy * r);
    }
    dc.setPenWidth(1);
  }

  //! Three overlapping discs on a slab; `r` is half the cloud width.
  function cloud(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric) as Void {
    dc.fillCircle(x - r * 0.46, y + r * 0.14, r * 0.4);
    dc.fillCircle(x + r * 0.44, y + r * 0.2, r * 0.36);
    dc.fillCircle(x - r * 0.02, y - r * 0.14, r * 0.52);
    dc.fillRectangle(x - r * 0.86, y + r * 0.14, r * 1.72, r * 0.42);
  }

  function drops(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric) as Void {
    dc.setPenWidth(penWidth(r * 0.16));
    for (var i = -1; i <= 1; i++) {
      var dx = x + i * r * 0.46;
      dc.drawLine(dx + r * 0.1, y - r * 0.2, dx - r * 0.1, y + r * 0.24);
    }
    dc.setPenWidth(1);
  }

  function flakes(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric) as Void {
    for (var i = -1; i <= 1; i++) {
      dc.fillCircle(x + i * r * 0.46, y, r * 0.14);
    }
  }

  function bolt(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric) as Void {
    dc.fillPolygon([
      pt(x + r * 0.24, y - r * 0.42),
      pt(x - r * 0.28, y + r * 0.06),
      pt(x - r * 0.02, y + r * 0.06),
      pt(x - r * 0.2, y + r * 0.5),
      pt(x + r * 0.3, y - r * 0.04),
      pt(x + r * 0.02, y - r * 0.04),
    ]);
  }

  //! Stacked horizontal bars, used for fog and wind.
  function bars(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric) as Void {
    dc.setPenWidth(penWidth(r * 0.16));
    dc.drawLine(x - r * 0.7, y - r * 0.3, x + r * 0.7, y - r * 0.3);
    dc.drawLine(x - r * 0.5, y, x + r * 0.8, y);
    dc.drawLine(x - r * 0.7, y + r * 0.3, x + r * 0.6, y + r * 0.3);
    dc.setPenWidth(1);
  }

  //! Bell with a slash through it. The slash is drawn twice: once in the
  //! background colour to punch a gap out of the bell, then in the icon colour.
  function doNotDisturb(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric, color as Number) as Void {
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    dc.fillCircle(x, y - r * 0.14, r * 0.44); // dome
    dc.fillPolygon([
      pt(x - r * 0.68, y + r * 0.42),
      pt(x - r * 0.44, y + r * 0.14),
      pt(x - r * 0.44, y - r * 0.14),
      pt(x + r * 0.44, y - r * 0.14),
      pt(x + r * 0.44, y + r * 0.14),
      pt(x + r * 0.68, y + r * 0.42),
    ]);
    dc.fillCircle(x, y - r * 0.68, r * 0.13); // handle
    dc.fillCircle(x, y + r * 0.62, r * 0.17); // clapper

    dc.setColor(Theme.BACKGROUND, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(penWidth(r * 0.3));
    dc.drawLine(x - r * 0.9, y + r * 0.9, x + r * 0.9, y - r * 0.9);
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(penWidth(r * 0.16));
    dc.drawLine(x - r * 0.86, y + r * 0.86, x + r * 0.86, y - r * 0.86);
    dc.setPenWidth(1);
  }

  function alarm(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric, color as Number) as Void {
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    var stroke = penWidth(r * 0.18);
    dc.setPenWidth(stroke);
    dc.drawCircle(x, y + r * 0.1, r * 0.66);
    // the two bells on top
    dc.drawLine(x - r * 0.72, y - r * 0.44, x - r * 0.4, y - r * 0.72);
    dc.drawLine(x + r * 0.72, y - r * 0.44, x + r * 0.4, y - r * 0.72);
    // hands
    dc.drawLine(x, y + r * 0.1, x, y - r * 0.3);
    dc.drawLine(x, y + r * 0.1, x + r * 0.34, y + r * 0.24);
    dc.setPenWidth(1);
  }

  //! Vertical span of notification() as a multiple of r (it reaches from
  //! y - 0.75r to y + 0.85r); callers size the badge to a slot with this.
  const NOTIFICATION_SPAN as Float = 1.60;

  //! Speech bubble, always a solid fill in `color` (grey when idle, orange with
  //! a count otherwise). Roughly square. The caller draws the number on top.
  function notification(dc as Graphics.Dc, x as Numeric, y as Numeric, r as Numeric, color as Number) as Void {
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    dc.fillRoundedRectangle(x - r * 0.85, y - r * 0.75, r * 1.7, r * 1.2, r * 0.30);
    dc.fillPolygon([
      pt(x - r * 0.24, y + r * 0.40),
      pt(x + r * 0.24, y + r * 0.40),
      pt(x - r * 0.04, y + r * 0.85),
    ]);
  }

  function penWidth(value as Numeric) as Number {
    var w = Math.round(value).toNumber();
    return w < 1 ? 1 : w;
  }

  //! fillPolygon wants integer vertices, and its parameter is typed as an
  //! array of [x, y] pairs -- so the return type is the pair tuple, not a
  //! plain Array<Number>, or the array literals below fail the type check.
  function pt(x as Numeric, y as Numeric) as [Numeric, Numeric] {
    return [Math.round(x).toNumber(), Math.round(y).toNumber()];
  }
}
