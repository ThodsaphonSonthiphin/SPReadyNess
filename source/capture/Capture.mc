using Toybox.Lang;

// Background only. BackgroundService.onTemporalEvent is the scheduled entry
// point; the glance never captures — it is passive by design (ADR 0014).
(:background)
module Capture {

    // Pure: raw inputs -> a record, or null. Kept separate from run() so the
    // whole scoring path is testable without a device.
    function buildRecord(
        bb as Lang.Number?,
        hours as Lang.Number?,
        rhrValue as Lang.Number?,
        baseline as Lang.Number?,
        dayKey as Lang.Number
    ) as Lang.Dictionary? {

        var cBody     = Components.fromBodyBattery(bb);
        var cRecovery = Components.fromRecoveryHours(hours);
        var cRhr      = Components.fromRhr(rhrValue, baseline);

        var delta = null;
        if (rhrValue != null && baseline != null) {
            delta = rhrValue - baseline;
        }

        var result = Readiness.compute(cBody, cRecovery, cRhr, delta);
        if (result == null) { return null; }

        return DailyRecord.make(
            dayKey,
            result[:score],
            cBody,
            cRecovery,
            cRhr,
            result[:overrideFired],
            rhrValue
        );
    }

    // The guard-and-store half of run(), with the sensor reads lifted out.
    // Idempotent per day (ADR 0012/0015): safe to call from the temporal
    // event AND from app launch. Returns true if a record was written.
    //
    // Split out from run() so the spec's idempotency requirement is
    // testable — run() reads hardware, this does not.
    function runWith(
        bb as Lang.Number?,
        hours as Lang.Number?,
        rhrValue as Lang.Number?,
        baseline as Lang.Number?,
        dayKey as Lang.Number
    ) as Lang.Boolean {

        if (RecordStore.hasRecordFor(dayKey)) { return false; }

        var record = buildRecord(bb, hours, rhrValue, baseline, dayKey);
        if (record == null) { return false; }

        RecordStore.put(record);
        return true;
    }

    // The two live entry points: the temporal event and app launch.
    function run() as Lang.Boolean {
        // One try/catch covers both. SensorHistory and UserProfile are
        // documented to return null on an unsupported device, but if either
        // throws instead, the exception would propagate out of
        // SPReadyNessApp.onStart (the app fails to launch outright) and out
        // of BackgroundService.onTemporalEvent (captures stop permanently).
        // Nothing else in the app swallows errors.
        try {
            var dayKey = DailyRecord.today();

            // The day guard is checked here as well as inside runWith, and
            // that is deliberate rather than redundant. ADR 0012 wants the
            // common firing — every 30 minutes, on a day already captured —
            // to cost a guard and an exit and nothing else. Delegating
            // straight to runWith would run bodyBatteryAtWake()'s walk over
            // the whole sensor history buffer on every one of them. The
            // second check costs one extra Storage read on the single
            // firing per day that actually writes.
            if (RecordStore.hasRecordFor(dayKey)) { return false; }

            return runWith(
                Sensors.bodyBatteryAtWake(),
                Sensors.recoveryHours(),
                Sensors.rhr(),
                Sensors.rhrBaseline(),
                dayKey
            );
        } catch (e) {
            return false;
        }
    }
}
