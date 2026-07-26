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
        var wrote = Capture.run();
        if (wrote) {
            var latest = RecordStore.latest();
            // Payload is a refresh nudge for a running app, NOT a second
            // persistence path — the record is already in Storage.
            Background.exit({ :score => latest[:score] });
        } else {
            Background.exit(null);
        }
    }
}
