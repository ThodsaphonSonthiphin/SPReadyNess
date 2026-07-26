using Toybox.Test;
using Toybox.Lang;

(:test)
function buildsARecordFromRawInputs(logger as Test.Logger) as Lang.Boolean {
    // 88 BB, 24h recovery -> 50, rhr 50 vs baseline 50 -> 100
    // 0.50*88 + 0.30*50 + 0.20*100 = 44 + 15 + 20 = 79
    var record = Capture.buildRecord(88, 24, 50, 50, 20260726);
    Test.assertEqualMessage(record[:score], 79, "score from raw inputs");
    Test.assertEqualMessage(record[:day], 20260726, "carries the day key");
    Test.assertEqualMessage(record[:body], 88, "stores the body component");
    return true;
}

(:test)
function noBodyBatteryBuildsNoRecord(logger as Test.Logger) as Lang.Boolean {
    // ADR 0013: history no longer reaching wake yields null, and null means no record
    Test.assertEqualMessage(Capture.buildRecord(null, 24, 50, 50, 20260726), null,
        "no BB at wake, no record");
    return true;
}

(:test)
function recoveryZeroStillBuildsARecord(logger as Test.Logger) as Lang.Boolean {
    // The rest-day case: 0 hours is fully recovered, not missing
    var record = Capture.buildRecord(90, 0, 50, 50, 20260726);
    Test.assertMessage(record != null, "0h recovery is valid input");
    // 0.50*90 + 0.30*100 + 0.20*100 = 45 + 30 + 20 = 95
    Test.assertEqualMessage(record[:score], 95, "rest day scores high");
    return true;
}

// Spec, Testing: "launch-triggered Capture is idempotent with the scheduled
// one for the same day". SPReadyNessApp.onStart calls Capture.run() and so
// does BackgroundService.onTemporalEvent; on the first morning after an
// install both fire minutes apart. The second must write nothing rather than
// overwrite the morning's record with a later, lower Body Battery.
(:test)
function secondCaptureForTheSameDayWritesNothing(logger as Test.Logger) as Lang.Boolean {
    RecordStore.clear();

    var first = Capture.runWith(88, 24, 50, 50, 20260726);
    Test.assertMessage(first, "the first capture of the day writes a record");

    var second = Capture.runWith(70, 24, 50, 50, 20260726);
    Test.assertEqualMessage(second, false,
        "the second capture for the same day writes nothing");
    Test.assertEqualMessage(RecordStore.all().size(), 1,
        "still exactly one record for the day");
    Test.assertEqualMessage(RecordStore.latest()[:body], 88,
        "the first capture's value survived, not the later one");
    return true;
}

(:test)
function overrideIsRecordedOnTheRecord(logger as Test.Logger) as Lang.Boolean {
    // rhr 58 vs baseline 50 = +8bpm -> caps at 59
    var record = Capture.buildRecord(85, 0, 58, 50, 20260726);
    Test.assertEqualMessage(record[:score], 59, "override capped the score");
    Test.assertEqualMessage(record[:overrideFired], true, "flag persisted");
    return true;
}
