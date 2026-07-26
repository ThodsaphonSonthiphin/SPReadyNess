using Toybox.ActivityMonitor;
using Toybox.Lang;
using Toybox.SensorHistory;
using Toybox.System;
using Toybox.Time;
using Toybox.UserProfile;

// Background only. Capture reads hardware here. NowView also calls
// bodyBatteryNow() and rhr(), but NowView lives in the app scope, which is
// not one of the excluded ones.
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

    function rhr() as Lang.Number? {
        var profile = UserProfile.getProfile();
        if (profile == null) { return null; }
        if (!(profile has :restingHeartRate)) { return null; }
        return profile.restingHeartRate;
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

        var iter = SensorHistory.getHeartRateHistory({
            :order => SensorHistory.ORDER_OLDEST_FIRST
        });
        if (iter == null) { return null; }

        var min = null;
        var sample = iter.next();
        while (sample != null && !sample.when.greaterThan(wakeMoment)) {
            if (sample.data != null && (min == null || sample.data < min)) {
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
