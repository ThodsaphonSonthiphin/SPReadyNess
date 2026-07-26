using Toybox.Lang;

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
            result[:overrideFired]
        );
    }

    // Idempotent per day (ADR 0012/0015): safe to call from the temporal
    // event AND from app launch. Returns true if a record was written.
    function run() as Lang.Boolean {
        var dayKey = DailyRecord.today();

        if (RecordStore.hasRecordFor(dayKey)) { return false; }

        var record = buildRecord(
            Sensors.bodyBatteryAtWake(),
            Sensors.recoveryHours(),
            Sensors.rhr(),
            Sensors.rhrBaseline(),
            dayKey
        );

        if (record == null) { return false; }

        RecordStore.put(record);
        return true;
    }
}
