import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
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
module Data {
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

  function graphSource() as Number {
    var source = property("graphSource", GraphSource.HEART_RATE);
    return source >= 0 && source < GraphSource.COUNT ? source : GraphSource.HEART_RATE;
  }

  function graphHours() as Number {
    var hours = property("graphHours", 4);
    return hours < 1 ? 1 : (hours > 24 ? 24 : hours);
  }

  //! The colours offered for the clock digits, on the watch and in Garmin
  //! Connect. All are straight from the MIP palette. The order here is the
  //! order the on-watch menu shows and must match resources/settings/settings.xml
  //! and SettingsMenu.colorLabels().
  function clockColorChoices() as Array<Number> {
    return [0xFFFFFF, 0xAAAAAA, 0x00FFFF, 0x00FF00, 0xFFFF00, 0xFFAA00, 0xFF0000, 0x00AAFF];
  }

  function hourColor() as Number {
    return clockColor("hourColor", Theme.HOURS);
  }

  function minuteColor() as Number {
    return clockColor("minuteColor", Theme.MINUTES);
  }

  function clockColor(key as String, fallback as Number) as Number {
    var value = property(key, fallback);
    var choices = clockColorChoices();
    for (var i = 0; i < choices.size(); i++) {
      if (choices[i] == value) {
        return value;
      }
    }
    return fallback;
  }

  //! Averages the selected series into `buckets` equal time slots, oldest
  //! first. Slots without a sample are null so the graph can leave a gap.
  //! Returns null when the series is unavailable or completely empty.
  function graphSeries(source as Number, hours as Number, buckets as Number) as Array? {
    var sums = new [buckets];
    var counts = new [buckets];
    for (var i = 0; i < buckets; i++) {
      sums[i] = 0.0;
      counts[i] = 0;
    }

    var span = hours * 3600;
    var now = Time.now().value();
    var slot = span / (buckets * 1.0);
    var any = false;

    var iterator = historyIterator(source, span);
    if (iterator == null) {
      return null;
    }

    var sample = iterator.next();
    while (sample != null) {
      var value = sampleValue(source, sample);
      if (value != null && sample.when != null) {
        var age = now - sample.when.value();
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
    var period = new Time.Duration(span);
    try {
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

  //! Most recent body battery reading, 0..100, or null.
  function bodyBattery() as Number? {
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

  function steps() as Number {
    var info = ActivityMonitor.getInfo();
    return info.steps == null ? 0 : info.steps;
  }

  //! "842", "6.8k", "12k" — the compact form the reference uses past 1000.
  function formatSteps(count as Number) as String {
    if (count < 1000) {
      return count.format("%d");
    }
    if (count < 10000) {
      return (count / 1000.0).format("%.1f") + "k";
    }
    return (count / 1000).format("%d") + "k";
  }

  function batteryPercent() as Number {
    return Math.round(System.getSystemStats().battery).toNumber();
  }

  function batteryDays() as Number? {
    var stats = System.getSystemStats();
    if (!(stats has :batteryInDays) || stats.batteryInDays == null) {
      return null;
    }
    return stats.batteryInDays.toNumber();
  }

  function currentConditions() {
    if (!(Toybox has :Weather) || !(Weather has :getCurrentConditions)) {
      return null;
    }
    try {
      return Weather.getCurrentConditions();
    } catch (e) {
      return null;
    }
  }

  //! Weather reports Celsius; convert when the watch is set to statute units.
  function formatTemperature(celsius as Numeric?) as String? {
    if (celsius == null) {
      return null;
    }
    var value = celsius;
    if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
      value = celsius * 9.0 / 5.0 + 32.0;
    }
    return Math.round(value).toNumber().format("%d") + "°";
  }

  //! How much of today's daylight is left: 1.0 at sunrise, 0.0 at sunset.
  //! Null when neither the weather service nor the last fix gives a position.
  function daylightRemaining() as Float? {
    if (!(Toybox has :Weather) || !(Weather has :getSunrise) || !(Weather has :getSunset)) {
      return null;
    }
    var location = position();
    if (location == null) {
      return null;
    }
    try {
      var now = Time.now();
      var sunrise = Weather.getSunrise(location, now);
      var sunset = Weather.getSunset(location, now);
      if (sunrise == null || sunset == null) {
        return null;
      }
      var start = sunrise.value();
      var end = sunset.value();
      if (end <= start) {
        return null;
      }
      var seconds = now.value();
      if (seconds <= start) {
        return 1.0;
      }
      if (seconds >= end) {
        return 0.0;
      }
      return (end - seconds) / ((end - start) * 1.0);
    } catch (e) {
      return null;
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
