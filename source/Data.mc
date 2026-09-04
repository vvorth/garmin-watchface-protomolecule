import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

//! Which series the configurable graph shows. The numbers are the values
//! stored in the `graphSource` property and must stay in sync with
//! resources/settings/settings.xml and the on-watch menu.
module GraphSource {
  const HEART_RATE as Number = 0;
  const BODY_BATTERY as Number = 1;
  const STRESS as Number = 2;
  const PRESSURE as Number = 3;
  const ELEVATION as Number = 4;
  const OXYGEN as Number = 5;

  const COUNT as Number = 6;
}

//! All reads of watch state live here so the view stays pure drawing code.
//!
//! Everything is defensive: a device may not have the sensor, the user may
//! have denied a permission, and weather may simply not have synced yet. Any
//! of those returns null and the view leaves that element out.
//!
//! ## Why this module caches
//!
//! `onUpdate` runs **once a second** whenever the watch is in high power mode
//! — which is what a wrist-raise gesture puts it in, for roughly ten seconds.
//! It runs once a minute the rest of the time. So anything read straight out
//! of `onUpdate` is read up to 60x more often than the number behind it can
//! actually change.
//!
//! Reads are therefore in three tiers:
//!
//! - **Per frame** (cheap, and genuinely wanted fresh on every gesture): the
//!   clock, `DeviceSettings` (DND / alarms / notification count) and the step
//!   count. The `DeviceSettings` snapshot is taken exactly once per frame in
//!   `beginFrame()` and shared by every row that wants it, instead of the five
//!   separate calls this used to make.
//! - **Every `SLOW_TTL` seconds**: anything that walks a `SensorHistory`
//!   iterator (the graph, Body Battery), plus weather and the `SystemStats`
//!   snapshot behind the battery percentage and days-remaining figures. These
//!   move on a scale of minutes at best; re-reading them at 1 Hz is pure
//!   battery burn.
//! - **Once a day / once per settings change**: sunrise and sunset, the date
//!   string, and the app properties.
//!
//! Nothing here caches to `Application.Storage` — that hits the filesystem and
//! would cost more than it saves. This is plain in-memory state, bounded and
//! rebuilt on the next launch.
module Data {
  //! How long a "slow" reading stays good. Five minutes is under the sampling
  //! interval of every history this face plots, so the graph never visibly
  //! lags, and it collapses a ten-second gesture burst from ten sensor walks
  //! into zero.
  const SLOW_TTL as Number = 300;

  // ------------------------------------------------------------- frame state
  // Taken once per onUpdate by beginFrame(); every getter below reads these
  // rather than calling the system again.
  var mSettings = null;
  var mClock = null;
  var mNowSec as Number = 0;
  var mLocalDay as Number = -1;

  // ----------------------------------------------------------------- caches
  var mGraph = null;
  var mGraphAt as Number = -1;
  var mGraphKey as Number = -1;

  var mBodyBattery = null;
  var mBodyBatteryAt as Number = -1;

  var mConditions = null;
  var mConditionsAt as Number = -1;

  var mStats = null;
  var mStatsAt as Number = -1;

  var mSunDay as Number = -1;
  var mSunTriedAt as Number = -1;
  var mSunriseSec as Number = 0;
  var mSunsetSec as Number = 0;
  var mHasSun as Boolean = false;

  var mDateText = null;
  var mDateDay as Number = -1;

  // Properties, reloaded only when the user changes a setting.
  var mPropsLoaded as Boolean = false;
  var mGraphSource as Number = 0;
  var mGraphHours as Number = 4;
  var mHourColor as Number = 0;
  var mMinuteColor as Number = 0;

  // ------------------------------------------------------------- frame setup

  //! Call once at the top of every onUpdate, before anything else here.
  function beginFrame() as Void {
    mClock = System.getClockTime();
    mSettings = System.getDeviceSettings();
    mNowSec = Time.now().value();

    // Local day index, so the date text and the sun times roll over at local
    // midnight rather than UTC midnight.
    var offset = mClock.timeZoneOffset == null ? 0 : mClock.timeZoneOffset;
    mLocalDay = (mNowSec + offset) / 86400;

    ensureProperties();
  }

  function settings() {
    return mSettings;
  }

  function clock() {
    return mClock;
  }

  //! True while a cached value taken at `at` is still good. A negative age
  //! (the clock moved backwards over a timezone or DST change) counts as
  //! expired so a stale value cannot get stuck.
  function fresh(at as Number) as Boolean {
    if (at < 0) {
      return false;
    }
    var age = mNowSec - at;
    return age >= 0 && age < SLOW_TTL;
  }

  // ------------------------------------------------------------- properties

  //! Drop the cached property values. Called from the app's onSettingsChanged
  //! (Garmin Connect) and from the on-watch menu's store(); the next read
  //! reloads them. Also drops the graph, whose source and range may have moved.
  function invalidateProperties() as Void {
    mPropsLoaded = false;
    mGraph = null;
    mGraphAt = -1;
    mGraphKey = -1;
  }

  function loadProperties() as Void {
    var source = property("graphSource", GraphSource.HEART_RATE);
    mGraphSource = source >= 0 && source < GraphSource.COUNT ? source : GraphSource.HEART_RATE;

    var hours = property("graphHours", 4);
    mGraphHours = hours < 1 ? 1 : (hours > 24 ? 24 : hours);

    mHourColor = validColor(property("hourColor", Theme.HOURS), Theme.HOURS);
    mMinuteColor = validColor(property("minuteColor", Theme.MINUTES), Theme.MINUTES);

    mPropsLoaded = true;
  }

  function property(key as String, fallback as Number) as Number {
    var value = null;
    try {
      value = Properties.getValue(key);
    } catch (e) {
      value = null;
    }
    if (value == null || !(value instanceof Lang.Number)) {
      return fallback;
    }
    return value;
  }

  //! The colours offered for the clock digits, on the watch and in Garmin
  //! Connect. All are straight from the MIP palette. The order here is the
  //! order the on-watch menu shows and must match resources/settings/settings.xml
  //! and SettingsMenu.colorLabels().
  function clockColorChoices() as Array<Number> {
    return [0xFFFFFF, 0xAAAAAA, 0x00FFFF, 0x00FF00, 0xFFFF00, 0xFFAA00, 0xFF0000, 0x00AAFF];
  }

  //! Only used when reloading properties, so the array it allocates is built a
  //! couple of times per settings change rather than twice a frame.
  function validColor(value as Number, fallback as Number) as Number {
    var choices = clockColorChoices();
    for (var i = 0; i < choices.size(); i++) {
      if (choices[i] == value) {
        return value;
      }
    }
    return fallback;
  }

  //! The settings menu reads these before any frame has been drawn, so each
  //! getter loads on demand rather than relying on beginFrame() having run.
  function ensureProperties() as Void {
    if (!mPropsLoaded) {
      loadProperties();
    }
  }

  function graphSource() as Number {
    ensureProperties();
    return mGraphSource;
  }

  function graphHours() as Number {
    ensureProperties();
    return mGraphHours;
  }

  function hourColor() as Number {
    ensureProperties();
    return mHourColor;
  }

  function minuteColor() as Number {
    ensureProperties();
    return mMinuteColor;
  }

  // -------------------------------------------------------------- date text

  //! "Thu 3 Sep", rebuilt once a day. Gregorian.info plus the format call is
  //! several allocations, and the answer only changes at midnight.
  function dateText() {
    if (mDateText != null && mDateDay == mLocalDay) {
      return mDateText;
    }
    var now = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
    mDateText = Lang.format("$1$ $2$ $3$", [now.day_of_week, now.day.format("%d"), now.month]);
    mDateDay = mLocalDay;
    return mDateText;
  }

  // ------------------------------------------------------------------ graph

  //! The graph series, recomputed at most every SLOW_TTL seconds. Walking the
  //! history iterator is by far the most expensive thing this face does — a
  //! few hundred `next()` calls — and the buckets are minutes wide, so there
  //! is nothing to gain from doing it per frame.
  function graph(buckets as Number) as Array? {
    var source = graphSource();
    var hours = graphHours();
    // The key covers everything that changes the shape of the answer, so a new
    // source or range recomputes immediately instead of waiting out the TTL.
    var key = source * 10000 + hours * 100 + buckets;
    if (mGraphKey == key && fresh(mGraphAt)) {
      return mGraph;
    }
    mGraphKey = key;
    mGraphAt = mNowSec;
    mGraph = graphSeries(source, hours, buckets);
    return mGraph;
  }

  //! Averages the selected series into `buckets` equal time slots, oldest
  //! first. Slots without a sample are null so the graph can leave a gap.
  //! Returns null when the series is unavailable or completely empty.
  function graphSeries(source as Number, hours as Number, buckets as Number) as Array? {
    var iterator = historyIterator(source, hours * 3600);
    if (iterator == null) {
      return null;
    }

    var sums = new [buckets];
    var counts = new [buckets];
    for (var i = 0; i < buckets; i++) {
      sums[i] = 0.0;
      counts[i] = 0;
    }

    var span = hours * 3600;
    var slot = span / (buckets * 1.0);
    var any = false;

    var sample = iterator.next();
    while (sample != null) {
      var value = sampleValue(source, sample);
      if (value != null && sample.when != null) {
        var age = mNowSec - sample.when.value();
        if (age >= 0 && age < span) {
          var index = buckets - 1 - (age / slot).toNumber();
          if (index < 0) {
            index = 0;
          }
          if (index > buckets - 1) {
            index = buckets - 1;
          }
          sums[index] = sums[index] + value;
          counts[index] = counts[index] + 1;
          any = true;
        }
      }
      sample = iterator.next();
    }

    if (!any) {
      return null;
    }

    var values = new [buckets];
    for (var i = 0; i < buckets; i++) {
      values[i] = counts[i] > 0 ? sums[i] / counts[i] : null;
    }
    return values;
  }

  //! Body battery and stress are already percentages, so the graph pins them
  //! to 0..100 instead of auto scaling; that keeps the bars comparable between
  //! updates.
  function graphIsPercentage(source as Number) as Boolean {
    return source == GraphSource.BODY_BATTERY || source == GraphSource.STRESS || source == GraphSource.OXYGEN;
  }

  function historyIterator(source as Number, span as Number) {
    try {
      var period = new Time.Duration(span);
      if (source == GraphSource.HEART_RATE) {
        if (ActivityMonitor has :getHeartRateHistory) {
          return ActivityMonitor.getHeartRateHistory(period, true);
        }
        return null;
      }
      if (!(Toybox has :SensorHistory)) {
        return null;
      }
      var options = { :period => period, :order => SensorHistory.ORDER_NEWEST_FIRST };
      if (source == GraphSource.BODY_BATTERY && SensorHistory has :getBodyBatteryHistory) {
        return SensorHistory.getBodyBatteryHistory(options);
      }
      if (source == GraphSource.STRESS && SensorHistory has :getStressHistory) {
        return SensorHistory.getStressHistory(options);
      }
      if (source == GraphSource.PRESSURE && SensorHistory has :getPressureHistory) {
        return SensorHistory.getPressureHistory(options);
      }
      if (source == GraphSource.ELEVATION && SensorHistory has :getElevationHistory) {
        return SensorHistory.getElevationHistory(options);
      }
      if (source == GraphSource.OXYGEN && SensorHistory has :getOxygenSaturationHistory) {
        return SensorHistory.getOxygenSaturationHistory(options);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  function sampleValue(source as Number, sample) as Float? {
    if (source == GraphSource.HEART_RATE) {
      var hr = sample.heartRate;
      if (hr == null || hr == ActivityMonitor.INVALID_HR_SAMPLE) {
        return null;
      }
      return hr.toFloat();
    }
    var data = sample.data;
    return data == null ? null : data.toFloat();
  }

  // ---------------------------------------------------------- body battery

  //! Most recent body battery reading, 0..100, or null. Cached: it walks a
  //! history iterator and the sensor only samples every few minutes.
  function bodyBattery() as Number? {
    if (fresh(mBodyBatteryAt)) {
      return mBodyBattery;
    }
    mBodyBatteryAt = mNowSec;
    mBodyBattery = readBodyBattery();
    return mBodyBattery;
  }

  function readBodyBattery() as Number? {
    if (!(Toybox has :SensorHistory) || !(SensorHistory has :getBodyBatteryHistory)) {
      return null;
    }
    try {
      var iterator = SensorHistory.getBodyBatteryHistory({
        :period => new Time.Duration(3600 * 6),
        :order => SensorHistory.ORDER_NEWEST_FIRST,
      });
      var sample = iterator.next();
      while (sample != null) {
        if (sample.data != null) {
          return sample.data.toNumber();
        }
        sample = iterator.next();
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  // --------------------------------------------------- steps and the battery

  //! Read every frame on purpose: the user wants a fresh count the moment they
  //! raise their wrist, and ActivityMonitor.getInfo() is a cheap local read.
  function steps() as Number {
    var info = ActivityMonitor.getInfo();
    return info.steps == null ? 0 : info.steps;
  }

  //! "842", "6.0k", "13.5k" — the compact form past 1000. The decimal is
  //! always shown, even when it is zero, so the width does not jump around as
  //! the count crosses a round thousand.
  function formatSteps(count as Number) as String {
    if (count < 1000) {
      return count.format("%d");
    }
    return (count / 1000.0).format("%.1f") + "k";
  }

  //! The SystemStats snapshot, refreshed on the slow tier rather than per
  //! frame. Battery percentage takes tens of minutes to move a single point
  //! and the days-remaining figure is a periodic firmware estimate, so there
  //! is nothing a 1 Hz read could show that a five-minute-old one does not —
  //! and this is the only caller of System.getSystemStats(), so caching it
  //! takes that allocation out of the draw path entirely.
  function stats() {
    if (!fresh(mStatsAt)) {
      mStatsAt = mNowSec;
      mStats = System.getSystemStats();
    }
    return mStats;
  }

  function batteryPercent() as Number {
    return Math.round(stats().battery).toNumber();
  }

  //! Copies the field into a local before testing it — the type checker
  //! narrows locals but not fields, so `x.y != null && x.y.z()` does not
  //! typecheck the way it reads.
  function batteryDays() as Number? {
    var s = stats();
    if (!(s has :batteryInDays)) {
      return null;
    }
    var days = s.batteryInDays;
    return days == null ? null : days.toNumber();
  }

  function notificationCount() as Number {
    var count = mSettings.notificationCount;
    return count == null ? 0 : count;
  }

  function doNotDisturb() as Boolean {
    if (!(mSettings has :doNotDisturb)) {
      return false;
    }
    var dnd = mSettings.doNotDisturb;
    return dnd != null && dnd;
  }

  function alarmSet() as Boolean {
    var alarms = mSettings.alarmCount;
    return alarms != null && alarms > 0;
  }

  // ---------------------------------------------------------------- weather

  //! Cached: the watch itself only re-syncs weather about once an hour, so
  //! asking more often than SLOW_TTL cannot produce a different answer.
  function currentConditions() {
    if (fresh(mConditionsAt)) {
      return mConditions;
    }
    mConditionsAt = mNowSec;
    mConditions = null;
    if (!(Toybox has :Weather) || !(Weather has :getCurrentConditions)) {
      return null;
    }
    try {
      mConditions = Weather.getCurrentConditions();
    } catch (e) {
      mConditions = null;
    }
    return mConditions;
  }

  //! Weather reports Celsius; convert when the watch is set to statute units.
  function formatTemperature(celsius as Numeric?) as String? {
    if (celsius == null) {
      return null;
    }
    var value = celsius;
    if (mSettings.temperatureUnits == System.UNIT_STATUTE) {
      value = celsius * 9.0 / 5.0 + 32.0;
    }
    return Math.round(value).toNumber().format("%d") + "°";
  }

  // --------------------------------------------------------------- daylight

  //! How much of today's daylight is left, as a fraction of the whole day:
  //!
  //!   before sunrise (night)  0.0   empty
  //!   at sunrise              1.0   full
  //!   through the day               drains linearly
  //!   at and after sunset     0.0   empty
  //!
  //! So the arc is dark all night, snaps to full at sunrise, and drains back to
  //! nothing by sunset. Null when neither the weather service nor the last fix
  //! gives a position, which drops the fill and leaves the grey track.
  //!
  //! Sunrise and sunset are resolved once a day and the fraction is then plain
  //! arithmetic — the arc still moves smoothly every frame, but the two
  //! Weather lookups behind it happen once.
  function daylightRemaining() as Float? {
    // Resolved once a day once it succeeds. Until then — no position fix yet,
    // which is the normal state on a freshly booted watch — retry no more
    // often than SLOW_TTL rather than on every frame of every gesture.
    if (!(mHasSun && mSunDay == mLocalDay) && !fresh(mSunTriedAt)) {
      mSunTriedAt = mNowSec;
      resolveSunTimes();
    }
    if (!mHasSun || mSunDay != mLocalDay) {
      return null;
    }
    // Night, either side of the daylight window.
    if (mNowSec <= mSunriseSec || mNowSec >= mSunsetSec) {
      return 0.0;
    }
    return (mSunsetSec - mNowSec) / ((mSunsetSec - mSunriseSec) * 1.0);
  }

  function resolveSunTimes() as Void {
    mHasSun = false;
    if (!(Toybox has :Weather) || !(Weather has :getSunrise) || !(Weather has :getSunset)) {
      return;
    }
    var location = position();
    if (location == null) {
      return;
    }
    try {
      var now = Time.now();
      var sunrise = Weather.getSunrise(location, now);
      var sunset = Weather.getSunset(location, now);
      if (sunrise == null || sunset == null) {
        return;
      }
      var start = sunrise.value();
      var end = sunset.value();
      if (end <= start) {
        return;
      }
      mSunriseSec = start;
      mSunsetSec = end;
      mSunDay = mLocalDay;
      mHasSun = true;
    } catch (e) {
      mHasSun = false;
    }
  }

  function position() {
    try {
      var activity = Activity.getActivityInfo();
      if (activity != null && activity.currentLocation != null) {
        return activity.currentLocation;
      }
    } catch (e) {
      // fall through to the weather observation position
    }
    var conditions = currentConditions();
    if (conditions != null && conditions has :observationLocationPosition) {
      return conditions.observationLocationPosition;
    }
    return null;
  }
}
