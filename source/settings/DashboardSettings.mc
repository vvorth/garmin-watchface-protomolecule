import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.WatchUi;

//! On-watch settings: what the graph plots, how far back it reaches, and the
//! two clock colours.
module SettingsMenu {
  const GRAPH_SOURCE_ITEM as String = "graphSource";
  const GRAPH_HOURS_ITEM as String = "graphHours";
  const HOUR_COLOR_ITEM as String = "hourColor";
  const MINUTE_COLOR_ITEM as String = "minuteColor";

  const HOUR_CHOICES as Array<Number> = [2, 4, 6, 8, 12, 24];

  //! Indexed by GraphSource.*, so the order has to match that module.
  function sourceLabels() as Array {
    return [
      Rez.Strings.SourceHeartRate,
      Rez.Strings.SourceBodyBattery,
      Rez.Strings.SourceStress,
      Rez.Strings.SourcePressure,
      Rez.Strings.SourceElevation,
      Rez.Strings.SourceOxygen,
    ];
  }

  //! Indexed to match Data.clockColorChoices().
  function colorLabels() as Array {
    return [
      Rez.Strings.ColorWhite,
      Rez.Strings.ColorGray,
      Rez.Strings.ColorCyan,
      Rez.Strings.ColorGreen,
      Rez.Strings.ColorYellow,
      Rez.Strings.ColorOrange,
      Rez.Strings.ColorRed,
      Rez.Strings.ColorBlue,
    ];
  }

  function sourceLabel() as String {
    return WatchUi.loadResource(sourceLabels()[Data.graphSource()]);
  }

  function colorLabel(value as Number) as String {
    var choices = Data.clockColorChoices();
    for (var i = 0; i < choices.size(); i++) {
      if (choices[i] == value) {
        return WatchUi.loadResource(colorLabels()[i]);
      }
    }
    return WatchUi.loadResource(colorLabels()[0]);
  }

  function hoursLabel(hours as Number) as String {
    return Lang.format(WatchUi.loadResource(Rez.Strings.HoursSuffix), [hours.format("%d")]);
  }

  //! Writing from the on-watch menu does not go through the app's
  //! onSettingsChanged (that fires only for values pushed from Garmin
  //! Connect), so the cached copy in Data has to be dropped here.
  function store(key as String, value as Number) as Void {
    try {
      Properties.setValue(key, value);
    } catch (e) {
      // A read-only property store is not worth crashing the face over.
    }
    Data.invalidateProperties();
  }
}

class DashboardSettingsMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsTitle) });
    addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.GraphSource), SettingsMenu.sourceLabel(), SettingsMenu.GRAPH_SOURCE_ITEM, null));
    addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.GraphHours), SettingsMenu.hoursLabel(Data.graphHours()), SettingsMenu.GRAPH_HOURS_ITEM, null));
    addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.HourColor), SettingsMenu.colorLabel(Data.hourColor()), SettingsMenu.HOUR_COLOR_ITEM, null));
    addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.MinuteColor), SettingsMenu.colorLabel(Data.minuteColor()), SettingsMenu.MINUTE_COLOR_ITEM, null));
  }
}

class DashboardSettingsDelegate extends WatchUi.Menu2InputDelegate {
  function initialize() {
    Menu2InputDelegate.initialize();
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    var id = item.getId();
    if (SettingsMenu.GRAPH_SOURCE_ITEM.equals(id)) {
      var labels = SettingsMenu.sourceLabels();
      var values = new [labels.size()];
      for (var i = 0; i < labels.size(); i++) {
        labels[i] = WatchUi.loadResource(labels[i]);
        values[i] = i;
      }
      push(Rez.Strings.GraphSource, labels, values, Data.graphSource(), SettingsMenu.GRAPH_SOURCE_ITEM, item);
    } else if (SettingsMenu.GRAPH_HOURS_ITEM.equals(id)) {
      var values = SettingsMenu.HOUR_CHOICES;
      var labels = new [values.size()];
      for (var i = 0; i < values.size(); i++) {
        labels[i] = SettingsMenu.hoursLabel(values[i]);
      }
      push(Rez.Strings.GraphHours, labels, values, Data.graphHours(), SettingsMenu.GRAPH_HOURS_ITEM, item);
    } else if (SettingsMenu.HOUR_COLOR_ITEM.equals(id)) {
      pushColors(Rez.Strings.HourColor, Data.hourColor(), SettingsMenu.HOUR_COLOR_ITEM, item);
    } else if (SettingsMenu.MINUTE_COLOR_ITEM.equals(id)) {
      pushColors(Rez.Strings.MinuteColor, Data.minuteColor(), SettingsMenu.MINUTE_COLOR_ITEM, item);
    }
  }

  hidden function pushColors(title as ResourceId, selected as Number, key as String, parent as WatchUi.MenuItem) as Void {
    var values = Data.clockColorChoices();
    var resIds = SettingsMenu.colorLabels();
    var labels = new [values.size()];
    for (var i = 0; i < values.size(); i++) {
      labels[i] = WatchUi.loadResource(resIds[i]);
    }
    push(title, labels, values, selected, key, parent);
  }

  function onBack() as Void {
    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
  }

  hidden function push(title as ResourceId, labels as Array, values as Array, selected as Number, key as String, parent as WatchUi.MenuItem) as Void {
    WatchUi.pushView(new OptionMenu(title, labels, values, selected), new OptionDelegate(key, labels, values, parent), WatchUi.SLIDE_IMMEDIATE);
  }
}

//! A flat list of choices with a dot next to the active one.
class OptionMenu extends WatchUi.Menu2 {
  function initialize(title as ResourceId, labels as Array, values as Array, selected as Number) {
    Menu2.initialize({ :title => WatchUi.loadResource(title) });
    for (var i = 0; i < labels.size(); i++) {
      addItem(new WatchUi.MenuItem(labels[i], values[i] == selected ? "•" : null, i, null));
    }
  }
}

class OptionDelegate extends WatchUi.Menu2InputDelegate {
  hidden var mKey as String;
  hidden var mLabels as Array;
  hidden var mValues as Array;
  hidden var mParent as WatchUi.MenuItem;

  function initialize(key as String, labels as Array, values as Array, parent as WatchUi.MenuItem) {
    Menu2InputDelegate.initialize();
    mKey = key;
    mLabels = labels;
    mValues = values;
    mParent = parent;
  }

  function onSelect(item as WatchUi.MenuItem) as Void {
    var index = item.getId() as Number;
    SettingsMenu.store(mKey, mValues[index]);
    mParent.setSubLabel(mLabels[index]);
    WatchUi.requestUpdate();
    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
  }

  function onBack() as Void {
    WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
  }
}
