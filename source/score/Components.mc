using Toybox.Lang;

module Components {

    function clamp(value as Lang.Float) as Lang.Number {
        if (value < 0.0)   { return 0; }
        if (value > 100.0) { return 100; }
        return value.toNumber();
    }

    function fromBodyBattery(bb as Lang.Number?) as Lang.Number? {
        if (bb == null) { return null; }
        return clamp(bb.toFloat());
    }

    // ADR 0005: zero hours means fully recovered, NOT missing data.
    // Only a genuine null is absent.
    function fromRecoveryHours(hours as Lang.Number?) as Lang.Number? {
        if (hours == null) { return null; }
        var full = Constants.RECOVERY_FULL_HOURS.toFloat();
        return clamp(100.0 - (hours.toFloat() / full * 100.0));
    }

    function fromRhr(rhr as Lang.Number?, baseline as Lang.Number?) as Lang.Number? {
        if (rhr == null || baseline == null) { return null; }
        var delta = rhr - baseline;
        if (delta <= 0) { return 100; }
        return clamp(100.0 - (delta.toFloat() * Constants.RHR_SLOPE));
    }
}
