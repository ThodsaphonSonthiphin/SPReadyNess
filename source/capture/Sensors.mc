using Toybox.ActivityMonitor;
using Toybox.Lang;
using Toybox.SensorHistory;
using Toybox.System;
using Toybox.Time;
using Toybox.UserProfile;

// Background only. Capture reads hardware here. NowView also calls
// bodyBatteryNow(), recoveryHours() and rhrBaseline() — it no longer reads
// today's RHR live, taking it from the stored DailyRecord instead (ADR 0018)
// — but NowView lives in the app scope, which is not one of the excluded
// ones.
(:background)
module Sensors {

    // ADR 0013: the Capture fires up to 30 minutes after waking, but Body
    // Battery drains from the moment you are up. Reading the current value
    // would bias every Morning Score low by a VARYING amount, making scores
    // incomparable across days. So walk back to the sample at wake.
    //
    // Buffer depth is undocumented but interrogable — if it no longer reaches
    // wake, return null and let the caller decline to score.
    function bodyBatteryAtWake() as Lang.Number? {
        var profile = UserProfile.getProfile();
        if (profile == null || profile.wakeTime == null) { return null; }

        var wakeMoment = Time.today().add(profile.wakeTime);

        // ORDER_OLDEST_FIRST is load-bearing, not stylistic. The walk below
        // returns the FIRST sample at or after wake. Garmin's default is
        // ORDER_NEWEST_FIRST, under which the very first sample is "now" —
        // which trivially satisfies that test and would return the current
        // value, collapsing this function into bodyBatteryNow() and silently
        // destroying the at-wake resolution the whole function exists for.
        var iter = SensorHistory.getBodyBatteryHistory({
            :order => SensorHistory.ORDER_OLDEST_FIRST
        });
        if (iter == null) { return null; }

        var oldest = iter.getOldestSampleTime();
        if (oldest == null || oldest.greaterThan(wakeMoment)) {
            return null; // buffer no longer covers wake
        }

        var sample = iter.next();
        while (sample != null) {
            if (sample.data != null && !sample.when.lessThan(wakeMoment)) {
                return sample.data.toNumber();
            }
            sample = iter.next();
        }
        return null;
    }

    // The Now Score deliberately uses the CURRENT value, not the at-wake one.
    // Reusing bodyBatteryAtWake() here would make the Now Score identical to
    // the Morning Score and defeat ADR 0010 entirely.
    function bodyBatteryNow() as Lang.Number? {
        // NEWEST_FIRST stated explicitly rather than left to the default, so
        // the contrast with bodyBatteryAtWake is visible at both call sites.
        var iter = SensorHistory.getBodyBatteryHistory({
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });
        if (iter == null) { return null; }
        var newest = iter.next();
        if (newest == null || newest.data == null) { return null; }
        return newest.data.toNumber();
    }

    function recoveryHours() as Lang.Number? {
        var info = ActivityMonitor.getInfo();
        if (info == null) { return null; }
        if (!(info has :timeToRecovery)) { return null; }
        return info.timeToRecovery; // may legitimately be 0 = fully recovered
    }

    // ADR 0016: Profile.restingHeartRate is a user-configured setting that
    // stays null indefinitely for most real users (confirmed on real fr165
    // hardware and Garmin's own bug tracker) — not the watch's auto-computed
    // resting HR. This derives an effective value from raw heart-rate
    // history instead: the minimum bpm sample among whatever the
    // SensorHistory buffer holds at or before wake.
    //
    // Deliberately NOT "strictly from local midnight". Heart rate is
    // sampled far more densely than Body Battery, so a same-capacity buffer
    // likely covers far fewer hours — requiring the walk to reach all the
    // way back to midnight would return null far more often than intended.
    // Whatever the buffer covers, however far back, is used instead: a
    // partial night still captures the low point during rest for most wake
    // times, and more history than expected can only lower or maintain the
    // minimum, never distort it upward.
    //
    // OLDEST_FIRST with an early break the instant a sample is after wake —
    // NOT NEWEST_FIRST with no break (/scrutinize caught this: an unbounded
    // walk over the ENTIRE buffer, run synchronously from
    // SPReadyNessApp.onStart per ADR 0015, risks a perceptible hang on
    // launch if the app hasn't been opened in a while and the buffer has
    // filled with a day's worth of continuous samples — bodyBatteryAtWake()
    // avoids exactly this with its own early return). Oldest-first samples
    // are monotonically increasing in time, so once one is past wake, every
    // remaining sample is too — breaking there bounds the walk to "buffer
    // oldest through wake" and nothing further, with the identical result.
    function todaysRhr() as Lang.Number? {
        var profile = UserProfile.getProfile();
        if (profile == null || profile.wakeTime == null) { return null; }

        var wakeMoment = Time.today().add(profile.wakeTime);

        // Decline outright before today's wake — the one state in which the
        // early break below cannot bound the walk at all. Capture.run() fires
        // every CAPTURE_INTERVAL_MINUTES all night, and its hasRecordFor()
        // guard cannot short-circuit until the day's first successful
        // capture, which cannot happen before wake (bodyBatteryAtWake()
        // returns null until then, and Readiness.compute() refuses to score
        // without Body Battery). So this ran on every overnight firing with
        // wakeMoment set to a FUTURE timestamp: no sample can be later than a
        // future moment, the break never fired, and the walk covered the
        // ENTIRE buffer every half hour — the same unbounded walk described
        // above, back through a different door.
        //
        // Clamping the comparison to Time.now() would not bound it either:
        // every buffered sample is already in the past, so a now-bounded walk
        // is still the whole buffer. Only declining to walk bounds it — and
        // declining is the honest answer anyway, since "today's RHR" is the
        // minimum at or before today's wake and before wake that window has
        // not closed. Nothing observable changes: a pre-wake capture could
        // never write a record, so this value was already being discarded.
        if (wakeMoment.greaterThan(Time.now())) { return null; }

        var iter = SensorHistory.getHeartRateHistory({
            :order => SensorHistory.ORDER_OLDEST_FIRST
        });
        if (iter == null) { return null; }

        var min = null;
        var sample = iter.next();
        while (sample != null && !sample.when.greaterThan(wakeMoment)) {
            // Samples below RHR_FLOOR_BPM are dropped like nulls rather than
            // allowed to compete for the minimum. A minimum is the most
            // outlier-sensitive statistic there is, and one artifact — a loose
            // strap reporting 0, or 35 — does not merely skew the score, it
            // INVERTS the intended failure mode. Traced end to end: with a
            // baseline of 52, Components.fromRhr(35, 52) sees delta -17 <= 0
            // and returns a perfect 100, while Readiness.compute() marks the
            // day rhrChecked yet fires neither the illness nor the
            // overreaching override, as both need a POSITIVE delta. The app
            // would confidently vouch for a possibly-ill wearer with the
            // safety tripwire disarmed. Skipping the sample instead fails
            // toward a missing RHR and an UNCHECKED day, which is the honest
            // direction to fail in.
            if (sample.data != null && sample.data >= Constants.RHR_FLOOR_BPM
                    && (min == null || sample.data < min)) {
                min = sample.data;
            }
            sample = iter.next();
        }
        return (min == null) ? null : min.toNumber();
    }

    function rhrBaseline() as Lang.Number? {
        var profile = UserProfile.getProfile();
        if (profile == null) { return null; }
        if (!(profile has :averageRestingHeartRate)) { return null; }
        return profile.averageRestingHeartRate;
    }
}
