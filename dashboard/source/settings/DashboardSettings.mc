import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.WatchUi;

//! On-watch settings. Two choices for now: what the graph plots, and how far
//! back it reaches.
module SettingsMenu {
  const GRAPH_SOURCE_ITEM as String = "graphSource";
  const GRAPH_HOURS_ITEM as String = "graphHours";

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

  function sourceLabel() as String {
    return WatchUi.loadResource(sourceLabels()[Data.graphSource()]);
  }

  function hoursLabel(hours as Number) as String {
    return Lang.format(WatchUi.loadResource(Rez.Strings.HoursSuffix), [hours.format("%d")]);
  }

  function store(key as String, value as Number) as Void {
    try {
      Properties.setValue(key, value);
    } catch (e) {
      // A read-only property store is not worth crashing the face over.
    }
  }
}

class DashboardSettingsMenu extends WatchUi.Menu2 {
  function initialize() {
    Menu2.initialize({ :title => WatchUi.loadResource(Rez.Strings.SettingsTitle) });
    addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.GraphSource), SettingsMenu.sourceLabel(), SettingsMenu.GRAPH_SOURCE_ITEM, null));
    addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.GraphHours), SettingsMenu.hoursLabel(Data.graphHours()), SettingsMenu.GRAPH_HOURS_ITEM, null));
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
    }
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
