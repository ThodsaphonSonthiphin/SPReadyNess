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

    function rhrBaseline() as Lang.Number? {
        var profile = UserProfile.getProfile();
        if (profile == null) { return null; }
        if (!(profile has :averageRestingHeartRate)) { return null; }
        return profile.averageRestingHeartRate;
    }
}
