using Toybox.Test;
using Toybox.Lang;

function makeTestRecord(dayKey as Lang.Number, score as Lang.Number) as Lang.Dictionary {
    return DailyRecord.make(dayKey, score, 88, 73, 89, false);
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
    Test.assertEqualMessage(RecordStore.latest(), null, "empty store returns null");
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
