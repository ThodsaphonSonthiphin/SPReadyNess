using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

// Glance only. The glance calls forRecord() to decide between the coloured,
// stale, unchecked and empty presentations. Capture stores records without
// ever asking how they should be presented.
(:glance)
module DisplayState {
    enum {
        EMPTY = 0,      // nothing ever captured — no number at all (ADR 0015)
        CURRENT = 1,    // today's score, full band colour
        STALE = 2,      // older score, dimmed, age shown (ADR 0009)
        UNCHECKED = 3   // today's score but RHR absent, dimmed (ADR 0005)
    }

    // Seconds in a day. A unit definition, not a tunable — unlike the five
    // formula constants, this one has exactly one correct value.
    const SECONDS_PER_DAY = 86400;

    // A YYYYMMDD key back to a Moment. Gregorian.moment treats its fields as
    // UTC, which is correct here: both sides of the subtraction use the same
    // frame, so the offset cancels.
    function momentFor(dayKey as Lang.Number) as Time.Moment {
        return Gregorian.moment({
            :year   => dayKey / 10000,
            :month  => (dayKey / 100) % 100,
            :day    => dayKey % 100,
            :hour   => 0,
            :minute => 0,
            :second => 0
        });
    }

    // Real calendar arithmetic, not an approximation. An earlier version
    // treated a month as 30 days, which made 1 March against 28 February
    // read as 3 days instead of 1 — a visible lie on the stale caption, and
    // wrong across every month boundary and every leap year.
    //
    // Rounds to the nearest day rather than truncating. Whether
    // Gregorian.moment resolves its fields as UTC or device-local is not
    // documented; if local, a DST transition inside the interval makes
    // elapsed 23 or 25 hours instead of a clean multiple of 86400, and
    // truncation would silently drop a whole day from the caption. Rounding
    // absorbs a shift of up to 12 hours, far beyond any DST step in use.
    function ageInDays(recordDay as Lang.Number, todayKey as Lang.Number) as Lang.Number {
        var elapsed = momentFor(todayKey).subtract(momentFor(recordDay));
        return ((elapsed.value() + SECONDS_PER_DAY / 2) / SECONDS_PER_DAY).toNumber();
    }

    function forRecord(record as Lang.Dictionary?, todayKey as Lang.Number) as Lang.Dictionary {
        if (record == null) {
            return { :kind => EMPTY, :record => null, :ageDays => null };
        }

        if (record[:day] != todayKey) {
            return {
                :kind => STALE,
                :record => record,
                :ageDays => ageInDays(record[:day], todayKey)
            };
        }

        if (record[:rhr] == null) {
            return { :kind => UNCHECKED, :record => record, :ageDays => 0 };
        }

        return { :kind => CURRENT, :record => record, :ageDays => 0 };
    }
}
