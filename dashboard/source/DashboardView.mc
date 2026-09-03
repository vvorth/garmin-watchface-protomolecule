import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! The watch face itself.
//!
//! Everything is drawn in one pass from `onUpdate`. The face is a stack of
//! rows separated by hairlines that follow the round screen, so all geometry
//! is derived from the screen size at layout time (see the Layout module for
//! the vertical fractions).
class DashboardView extends WatchUi.WatchFace {
  hidden var mWidth as Number = 0;
  hidden var mHeight as Number = 0;
  hidden var mCenterX as Number = 0;
  hidden var mCenterY as Number = 0;
  hidden var mRadius as Number = 0;

  hidden var mTimeFont;
  hidden var mRowFont;
  hidden var mSmallFont;
  hidden var mBadgeFont;

  //! AMOLED screens ask for a reduced face while the watch is asleep.
  hidden var mBurnInProtection as Boolean = false;
  hidden var mAsleep as Boolean = false;
  hidden var mBurnInEnteredAtMinute as Number? = null;

  function initialize() {
    WatchFace.initialize();
  }

  function onLayout(dc as Graphics.Dc) as Void {
    mWidth = dc.getWidth();
    mHeight = dc.getHeight();
    mCenterX = mWidth / 2;
    mCenterY = mHeight / 2;
    mRadius = (mWidth < mHeight ? mWidth : mHeight) / 2;

    var settings = System.getDeviceSettings();
    mBurnInProtection = settings has :requiresBurnInProtection && settings.requiresBurnInProtection;

    // Pick the largest system font that still fits each row. Doing this once
    // here keeps every screen size sharp without a per-device layout file.
    var timeBand = (Layout.SEP_4_Y - Layout.SEP_3_Y) * mHeight;
    mTimeFont = Fonts.fit(dc, Fonts.time(), "88 88", chord(Layout.TIME_Y * mHeight) * 2, timeBand);
    mRowFont = Fonts.fit(dc, Fonts.row(), "88.8k", mWidth * 0.3, mHeight * 0.095);
    mSmallFont = Fonts.fit(dc, Fonts.row(), "888% 888°", mWidth * 0.44, mHeight * 0.078);
    mBadgeFont = Fonts.fit(dc, Fonts.row(), "88", mWidth * 0.06, mHeight * 0.055);
  }

  function onUpdate(dc as Graphics.Dc) as Void {
    if (dc has :clearClip) {
      dc.clearClip();
    }
    if (dc has :setAntiAlias) {
      dc.setAntiAlias(true);
    }

    dc.setColor(Theme.TEXT, Theme.BACKGROUND);
    dc.clear();

    if (mBurnInProtection && mAsleep) {
      drawSleepFace(dc);
      return;
    }
    mBurnInEnteredAtMinute = null;

    var settings = System.getDeviceSettings();
    // Walking the body battery history is the most expensive read on the face,
    // and both the status row and the left arc want it, so do it once.
    var bodyBattery = Data.bodyBattery();

    separator(dc, Layout.SEP_1_Y);
    separator(dc, Layout.SEP_2_Y);
    separator(dc, Layout.SEP_3_Y);
    separator(dc, Layout.SEP_4_Y);
    separator(dc, Layout.SEP_5_Y);

    drawDate(dc);
    drawWeather(dc);
    drawGraph(dc);
    drawTime(dc, 0);
    drawStatusRow(dc, settings, bodyBattery);
    drawBatteryRow(dc, settings);
    drawArcs(dc, bodyBattery);
  }

  function onEnterSleep() as Void {
    mAsleep = true;
    WatchUi.requestUpdate();
  }

  function onExitSleep() as Void {
    mAsleep = false;
    WatchUi.requestUpdate();
  }

  // ---------------------------------------------------------------- geometry

  //! Half the width available at height `y`, following a circle just inside
  //! the screen edge. Zero outside the circle.
  hidden function chord(y as Numeric) as Numeric {
    var r = mRadius * Layout.SEPARATOR_RADIUS;
    var dy = y - mCenterY;
    var squared = r * r - dy * dy;
    return squared <= 0 ? 0 : Math.sqrt(squared);
  }

  hidden function separator(dc as Graphics.Dc, fraction as Float) as Void {
    var y = Math.round(fraction * mHeight);
    var half = chord(y);
    if (half < 4) {
      return;
    }
    dc.setColor(Theme.SEPARATOR, Graphics.COLOR_TRANSPARENT);
    dc.setPenWidth(1);
    dc.drawLine(mCenterX - half, y, mCenterX + half, y);
  }

  // ------------------------------------------------------------------- rows

  hidden function drawDate(dc as Graphics.Dc) as Void {
    var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
    var text = Lang.format("$1$ $2$ $3$", [now.day_of_week, now.day.format("%d"), now.month]);
    dc.setColor(Theme.DATE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(mCenterX, Layout.DATE_Y * mHeight, mSmallFont, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
  }

  //! Current temperature, chance of precipitation, today's condition and
  //! today's high and low, spread across one row.
  hidden function drawWeather(dc as Graphics.Dc) as Void {
    var y = Layout.WEATHER_Y * mHeight;
    var conditions = Data.currentConditions();
    if (conditions == null) {
      dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
      dc.drawText(mCenterX, y, mSmallFont, "--", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
      return;
    }

    // Which fields CurrentConditions carries varies with the device and with
    // how much the weather service has delivered, so ask before reading.
    var current = conditions has :temperature ? Data.formatTemperature(conditions.temperature) : null;
    var high = conditions has :highTemperature ? Data.formatTemperature(conditions.highTemperature) : null;
    var low = conditions has :lowTemperature ? Data.formatTemperature(conditions.lowTemperature) : null;
    var precipitation = null;
    if (conditions has :precipitationChance && conditions.precipitationChance != null) {
      precipitation = conditions.precipitationChance.format("%d") + "%";
    }
    var condition = conditions has :condition ? conditions.condition : null;

    var iconRadius = mWidth * 0.042;
    var gap = mWidth * 0.026;

    // Measure first so the whole row can be centred as one block.
    var total = iconRadius * 2;
    var texts = [current, precipitation, high, low];
    for (var i = 0; i < texts.size(); i++) {
      if (texts[i] != null) {
        total += dc.getTextDimensions(texts[i], mSmallFont)[0] + gap;
      }
    }

    var x = mCenterX - total / 2.0;
    x = drawSegment(dc, x, y, current, Theme.TEXT, gap);
    x = drawSegment(dc, x, y, precipitation, Theme.TEXT, gap);

    Icons.weather(dc, Icons.forCondition(condition), x + iconRadius, y, iconRadius, Theme.TEXT);
    x += iconRadius * 2 + gap;

    x = drawSegment(dc, x, y, high, Theme.TEXT, gap);
    drawSegment(dc, x, y, low, Theme.TEXT_DIM, gap);
  }

  //! Draws one left aligned, vertically centred piece of the weather row and
  //! returns the x the next piece starts at. Null text advances nothing.
  hidden function drawSegment(dc as Graphics.Dc, x as Numeric, y as Numeric, text as String?, color as Number, gap as Numeric) as Numeric {
    if (text == null) {
      return x;
    }
    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    dc.drawText(x, y, mSmallFont, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    return x + dc.getTextDimensions(text, mSmallFont)[0] + gap;
  }

  hidden function drawGraph(dc as Graphics.Dc) as Void {
    var top = Layout.GRAPH_TOP_Y * mHeight;
    var bottom = Layout.GRAPH_BOTTOM_Y * mHeight;
    var half = chord(bottom);
    var buckets = Graph.bucketCount(mWidth, half);

    var source = Data.graphSource();
    var values = Data.graphSeries(source, Data.graphHours(), buckets);
    if (values == null) {
      return;
    }
    Graph.draw(dc, mWidth, mCenterX, top, bottom, values, Data.graphIsPercentage(source), Theme.GRAPH);
  }

  //! Hours and minutes as one centred block, no colon, minutes in the accent
  //! colour. `offsetY` shifts the block for burn-in protection.
  hidden function drawTime(dc as Graphics.Dc, offsetY as Numeric) as Void {
    var clock = System.getClockTime();
    var is24Hour = System.getDeviceSettings().is24Hour;

    var hour = clock.hour;
    if (!is24Hour) {
      hour = hour % 12;
      if (hour == 0) {
        hour = 12;
      }
    }
    var hours = is24Hour ? hour.format("%02d") : hour.format("%d");
    var minutes = clock.min.format("%02d");

    var gap = mWidth * 0.012;
    var hoursWidth = dc.getTextDimensions(hours, mTimeFont)[0];
    var minutesWidth = dc.getTextDimensions(minutes, mTimeFont)[0];
    var x = mCenterX - (hoursWidth + gap + minutesWidth) / 2.0;
    var y = Layout.TIME_Y * mHeight + offsetY;

    dc.setColor(Theme.HOURS, Graphics.COLOR_TRANSPARENT);
    dc.drawText(x, y, mTimeFont, hours, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    dc.setColor(Theme.MINUTES, Graphics.COLOR_TRANSPARENT);
    dc.drawText(x + hoursWidth + gap, y, mTimeFont, minutes, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
  }

  //! Body battery, do not disturb, alarm and step count.
  hidden function drawStatusRow(dc as Graphics.Dc, settings as System.DeviceSettings, bodyBattery as Number?) as Void {
    var y = Layout.STATUS_Y * mHeight;
    var iconRadius = mWidth * 0.043;

    dc.setColor(bodyBattery == null ? Theme.TEXT_DIM : Theme.TEXT, Graphics.COLOR_TRANSPARENT);
    dc.drawText(mWidth * 0.2, y, mRowFont, bodyBattery == null ? "--" : bodyBattery.format("%d"), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

    var doNotDisturb = settings has :doNotDisturb && settings.doNotDisturb;
    Icons.doNotDisturb(dc, mWidth * 0.395, y, iconRadius, doNotDisturb ? Theme.DND_ON : Theme.OFF);

    var alarms = settings.alarmCount != null && settings.alarmCount > 0;
    Icons.alarm(dc, mWidth * 0.545, y, iconRadius, alarms ? Theme.ALARM_ON : Theme.OFF);

    dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
    dc.drawText(mWidth * 0.8, y, mRowFont, Data.formatSteps(Data.steps()), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
  }

  //! Estimated days of battery left, notification badge, battery percentage.
  hidden function drawBatteryRow(dc as Graphics.Dc, settings as System.DeviceSettings) as Void {
    var y = Layout.BATTERY_Y * mHeight;

    var days = Data.batteryDays();
    if (days != null) {
      dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
      dc.drawText(mWidth * 0.375, y, mSmallFont, days.format("%d") + "d", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
    dc.drawText(mWidth * 0.625, y, mSmallFont, Data.batteryPercent().format("%d") + "%", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

    var count = settings.notificationCount == null ? 0 : settings.notificationCount;
    var radius = mWidth * 0.045;
    var x = mCenterX;
    Icons.notification(dc, x, y, radius, count > 0 ? Theme.NOTIFICATION_ON : Theme.OFF, count > 0);
    if (count > 0) {
      dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
      dc.drawText(x, y - radius * 0.1, mBadgeFont, count.format("%d"), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
  }

  hidden function drawArcs(dc as Graphics.Dc, bodyBattery as Number?) as Void {
    var pen = Math.round(mWidth * 0.023).toNumber();
    if (pen < 3) {
      pen = 3;
    }
    var radius = mRadius - pen / 2 - 1;

    Arcs.draw(
      dc,
      mCenterX,
      mCenterY,
      radius,
      pen,
      bodyBattery == null ? null : bodyBattery / 100.0,
      Data.batteryPercent() / 100.0,
      Data.daylightRemaining()
    );
  }

  // --------------------------------------------------------- burn-in variant

  //! Reduced face for AMOLED screens while the watch is asleep: date and time
  //! only, dimmed, and nudged up and down over a five minute cycle so no pixel
  //! stays lit in one place.
  hidden function drawSleepFace(dc as Graphics.Dc) as Void {
    var clock = System.getClockTime();
    if (mBurnInEnteredAtMinute == null) {
      mBurnInEnteredAtMinute = clock.min;
    }
    var elapsed = clock.min - mBurnInEnteredAtMinute;
    if (elapsed < 0) {
      elapsed += 60;
    }
    var offsetY = (elapsed % 5 - 2) * (mHeight / 12.0);

    var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
    dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
    dc.drawText(
      mCenterX,
      Layout.SEP_3_Y * mHeight + offsetY,
      mSmallFont,
      Lang.format("$1$ $2$ $3$", [now.day_of_week, now.day.format("%d"), now.month]),
      Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
    );
    drawTime(dc, offsetY);
  }
}
