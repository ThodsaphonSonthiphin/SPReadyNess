using Toybox.Application;
using Toybox.Background;
using Toybox.Lang;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi;

class SPReadyNessApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Lang.Dictionary?) as Void {
        registerCapture();
        // ADR 0015: do not wait for the scheduled event. A fresh install at
        // 09:00 usually still has history reaching a 06:30 wake, so this
        // produces a real Morning Score at once and the empty state is
        // never seen. Idempotent per day, so racing the event is harmless.
        Capture.run();
    }

    function registerCapture() as Void {
        // Only one temporal event may exist; this overwrites any previous one.
        var interval = new Time.Duration(Constants.CAPTURE_INTERVAL_MINUTES * 60);
        Background.registerForTemporalEvent(interval);
    }

    function getServiceDelegate() as Lang.Array<System.ServiceDelegate> {
        return [ new BackgroundService() ] as Lang.Array<System.ServiceDelegate>;
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        WatchUi.requestUpdate();
    }

    function getInitialView() as Lang.Array<WatchUi.Views or WatchUi.InputDelegates>? {
        return [ new MorningView(), new PageDelegate() ]
            as Lang.Array<WatchUi.Views or WatchUi.InputDelegates>;
    }

    function getGlanceView() as Lang.Array<WatchUi.GlanceView>? {
        return [ new SPReadyNessGlanceView() ] as Lang.Array<WatchUi.GlanceView>;
    }
}
