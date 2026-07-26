using Toybox.Background;
using Toybox.Lang;
using Toybox.System;

(:background)
class BackgroundService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    // Guarded so almost every firing costs two comparisons and an exit
    // (ADR 0012). Only the first firing after wake does real work.
    function onTemporalEvent() as Void {
        // No exit payload. The record is already in Storage, and
        // onBackgroundData ignores `data` and calls requestUpdate(), which
        // re-reads the store anyway — so building a payload would buy a
        // second RecordStore.latest() (a full Storage read and array
        // deserialise) in the tightest-budgeted context in the app and then
        // throw the result away. The exit itself is the refresh nudge.
        Capture.run();
        Background.exit(null);
    }
}
