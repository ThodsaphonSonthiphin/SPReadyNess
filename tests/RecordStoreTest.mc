using Toybox.Test;
using Toybox.Lang;

// Not (:test): the SDK's unit-test harness auto-invokes every (:test)-tagged
// top-level function as a test case with a single Test.Logger argument, so
// tagging this two-argument helper that way makes the harness call it wrong
// and error out. Ships as inert dead code in non-test builds instead.
function makeTestRecord(dayKey as Lang.Number, score as Lang.Number) as Lang.Dictionary {
    return DailyRecord.make(dayKey, score, 88, 73, 89, false, null);
}

(:test)
function writeThenReadBack(logger as Test.Logger) as Lang.Boolean {
    RecordStore.clear();
    RecordStore.put(makeTestRecord(20260726, 84));
    var latest = RecordStore.latest();
    Test.assertEqualMessage(latest[:score], 84, "score round-trips");
    Test.assertEqualMessage(latest[:day], 20260726, "day key round-trips");
    return true;
}

(:test)
function dailyRecordCarriesRawRhrBpm(logger as Test.Logger) as Lang.Boolean {
    var record = DailyRecord.make(20260726, 84, 88, 73, 89, false, 52);
    Test.assertEqualMessage(record[:rhrBpm], 52, "raw rhr bpm is carried on the record");
    return true;
}

(:test)
function hasRecordForToday(logger as Test.Logger) as Lang.Boolean {
    RecordStore.clear();
    RecordStore.put(makeTestRecord(20260726, 84));
    Test.assertMessage(RecordStore.hasRecordFor(20260726), "finds today");
    Test.assertMessage(!RecordStore.hasRecordFor(20260727), "does not find tomorrow");
    return true;
}

(:test)
function emptyStoreHasNoLatest(logger as Test.Logger) as Lang.Boolean {
    RecordStore.clear();
    // Test.assertEqualMessage crashes when the actual value is null (SDK 9.2.0
    // Run No Evil bug); assert on the equality instead of handing null to it.
    Test.assertMessage(RecordStore.latest() == null, "empty store returns null");
    Test.assertEqualMessage(RecordStore.all().size(), 0, "empty store is empty");
    return true;
}

(:test)
function evictsBeyondMaxRecords(logger as Test.Logger) as Lang.Boolean {
    RecordStore.clear();
    for (var i = 0; i < Constants.MAX_RECORDS + 10; i += 1) {
        RecordStore.put(makeTestRecord(20260000 + i, 50));
    }
    Test.assertEqualMessage(RecordStore.all().size(), Constants.MAX_RECORDS,
        "capped at MAX_RECORDS");
    var oldest = RecordStore.all()[0];
    Test.assertEqualMessage(oldest[:day], 20260000 + 10,
        "the ten oldest were evicted, not the newest");
    return true;
}

(:test)
function sameDayReplacesRatherThanDuplicates(logger as Test.Logger) as Lang.Boolean {
    RecordStore.clear();
    RecordStore.put(makeTestRecord(20260726, 84));
    RecordStore.put(makeTestRecord(20260726, 60));
    Test.assertEqualMessage(RecordStore.all().size(), 1, "one record per day");
    Test.assertEqualMessage(RecordStore.latest()[:score], 60, "later write wins");
    return true;
}

(:test)
function outOfOrderWriteLandsInDayOrder(logger as Test.Logger) as Lang.Boolean {
    // ADR 0006 accepts a timezone crossing moving the local date backward.
    // An earlier day written after a later one must still sort into place,
    // or latest() would return the older record as current.
    RecordStore.clear();
    RecordStore.put(makeTestRecord(20260726, 84));
    RecordStore.put(makeTestRecord(20260724, 50));
    var all = RecordStore.all();
    Test.assertEqualMessage(all.size(), 2, "both records kept");
    Test.assertEqualMessage(all[0][:day], 20260724, "oldest first");
    Test.assertEqualMessage(all[1][:day], 20260726, "newest last");
    Test.assertEqualMessage(RecordStore.latest()[:day], 20260726,
        "latest is the newest DAY, not the newest WRITE");
    return true;
}
