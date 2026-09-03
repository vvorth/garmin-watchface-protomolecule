import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! The configurable history graph: one bar per time slot, oldest on the left.
module Graph {
  //! Bars never go all the way down to nothing — the lowest reading still gets
  //! a visible stub so the shape of the series stays readable.
  const MIN_BAR as Float = 0.12;

  function barWidth(screenWidth as Numeric) as Number {
    var w = Math.round(screenWidth * 0.0154).toNumber();
    return w < 2 ? 2 : w;
  }

  function pitch(screenWidth as Numeric) as Number {
    var gap = Math.round(screenWidth * 0.0192).toNumber();
    return barWidth(screenWidth) + (gap < 2 ? 2 : gap);
  }

  //! How many time slots fit into the space available for the graph.
  function bucketCount(screenWidth as Numeric, halfWidth as Numeric) as Number {
    var count = ((halfWidth * 2) / pitch(screenWidth)).toNumber();
    return count < 6 ? 6 : count;
  }

  //! `values` holds one Float per slot, oldest first, with null for slots that
  //! have no sample.
  function draw(dc as Graphics.Dc, screenWidth as Numeric, cx as Numeric, top as Numeric, bottom as Numeric, values as Array, isPercentage as Boolean, color as Number) as Void {
    var count = values.size();
    if (count == 0) {
      return;
    }

    var bar = barWidth(screenWidth);
    var step = pitch(screenWidth);
    var total = count * step - (step - bar);
    var x = cx - total / 2.0;
    var height = bottom - top;

    var low = 0.0;
    var high = 100.0;
    if (!isPercentage) {
      var range = bounds(values);
      if (range == null) {
        return;
      }
      low = range[0];
      high = range[1];
      if (high - low < 0.001) {
        low = low - 0.5;
        high = high + 0.5;
      }
    }

    dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    for (var i = 0; i < count; i++) {
      var value = values[i];
      var left = x + i * step;
      if (value == null) {
        // No sample in this slot: leave a one pixel high tick on the baseline.
        dc.fillRectangle(left, bottom - 1, bar, 1);
        continue;
      }
      var norm = (value - low) / (high - low);
      if (norm < 0.0) {
        norm = 0.0;
      }
      if (norm > 1.0) {
        norm = 1.0;
      }
      var barHeight = height * (MIN_BAR + (1.0 - MIN_BAR) * norm);
      dc.fillRectangle(left, bottom - barHeight, bar, barHeight);
    }
  }

  //! [min, max] over the non-null entries, or null when there are none.
  function bounds(values as Array) as Array? {
    var low = null;
    var high = null;
    for (var i = 0; i < values.size(); i++) {
      var value = values[i];
      if (value == null) {
        continue;
      }
      if (low == null || value < low) {
        low = value;
      }
      if (high == null || value > high) {
        high = value;
      }
    }
    return low == null ? null : [low, high];
  }
}
