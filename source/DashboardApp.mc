import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class DashboardApp extends Application.AppBase {
  function initialize() {
    AppBase.initialize();
  }

  function onStart(state as Dictionary?) as Void {}

  function onStop(state as Dictionary?) as Void {}

  function getInitialView() {
    return [new DashboardView()];
  }

  //! Settings the user can reach from the watch itself, by holding the menu
  //! button on the face. Garmin Connect drives the same properties through
  //! resources/settings/settings.xml.
  function getSettingsView() {
    return [new DashboardSettingsMenu(), new DashboardSettingsDelegate()];
  }

  function onSettingsChanged() as Void {
    WatchUi.requestUpdate();
  }
}
