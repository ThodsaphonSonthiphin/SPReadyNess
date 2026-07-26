using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

class SPReadyNessApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as Lang.Array<WatchUi.Views or WatchUi.InputDelegates>? {
        return [ new WatchUi.View() ] as Lang.Array<WatchUi.Views>;
    }
}
