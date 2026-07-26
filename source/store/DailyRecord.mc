using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

// Both scopes: Capture calls today() and make(), and the glance calls
// today() to compare against the stored record's day key.
(:background :glance)
module DailyRecord {

    // Device-local date as YYYYMMDD (ADR 0006). Guard and storage key use the
    // same function, so they can never disagree about which day it is.
    function dayKeyFor(moment as Time.Moment) as Lang.Number {
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return info.year * 10000 + info.month * 100 + info.day;
    }

    function today() as Lang.Number {
        return dayKeyFor(Time.now());
    }

    function make(
        dayKey as Lang.Number,
        score as Lang.Number,
        body as Lang.Number,
        recovery as Lang.Number?,
        rhr as Lang.Number?,
        overrideFired as Lang.Boolean
    ) as Lang.Dictionary {
        return {
            :day => dayKey,
            :score => score,
            :body => body,
            :recovery => recovery,
            :rhr => rhr,
            :overrideFired => overrideFired
        };
    }
}
