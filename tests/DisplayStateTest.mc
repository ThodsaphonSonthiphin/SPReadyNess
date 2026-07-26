using Toybox.Test;
using Toybox.Lang;

(:test)
function noRecordEverIsEmpty(logger as Test.Logger) as Lang.Boolean {
    // ADR 0015: distinct from stale — there is no number to dim
    var state = DisplayState.forRecord(null, 20260726);
    Test.assertEqualMessage(state[:kind], DisplayState.EMPTY, "empty, not stale");
    Test.assertEqualMessage(state[:ageDays], null, "empty has no age to report");
    return true;
}

(:test)
function todaysRecordIsCurrent(logger as Test.Logger) as Lang.Boolean {
    var record = DailyRecord.make(20260726, 84, 88, 73, 89, false);
    var state = DisplayState.forRecord(record, 20260726);
    Test.assertEqualMessage(state[:kind], DisplayState.CURRENT, "today is current");
    Test.assertEqualMessage(state[:ageDays], 0, "today is zero days old");
    return true;
}

(:test)
function olderRecordIsStaleWithAge(logger as Test.Logger) as Lang.Boolean {
    var record = DailyRecord.make(20260724, 84, 88, 73, 89, false);
    var state = DisplayState.forRecord(record, 20260726);
    Test.assertEqualMessage(state[:kind], DisplayState.STALE, "older is stale");
    Test.assertEqualMessage(state[:ageDays], 2, "two days old");
    return true;
}

(:test)
function ageCrossesMonthAndYearBoundaries(logger as Test.Logger) as Lang.Boolean {
    // A month is not 30 days. 1 March is ONE day after 28 February in a
    // non-leap year, and 1 January is ONE day after 31 December.
    var feb = DailyRecord.make(20260228, 84, 88, 73, 89, false);
    Test.assertEqualMessage(DisplayState.forRecord(feb, 20260301)[:ageDays], 1,
        "28 Feb to 1 Mar is one day");

    var dec = DailyRecord.make(20251231, 84, 88, 73, 89, false);
    Test.assertEqualMessage(DisplayState.forRecord(dec, 20260101)[:ageDays], 1,
        "31 Dec to 1 Jan is one day");

    var leap = DailyRecord.make(20240228, 84, 88, 73, 89, false);
    Test.assertEqualMessage(DisplayState.forRecord(leap, 20240301)[:ageDays], 2,
        "2024 is a leap year, so 28 Feb to 1 Mar is two days");
    return true;
}

(:test)
function todaysRecordWithoutRhrIsUnchecked(logger as Test.Logger) as Lang.Boolean {
    // ADR 0005: the override could not run, so the score carries no colour
    var record = DailyRecord.make(20260726, 72, 80, 60, null, false);
    var state = DisplayState.forRecord(record, 20260726);
    Test.assertEqualMessage(state[:kind], DisplayState.UNCHECKED, "no rhr = unchecked");
    Test.assertEqualMessage(state[:ageDays], 0, "unchecked is still today");
    return true;
}
