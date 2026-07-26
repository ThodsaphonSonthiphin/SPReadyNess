using Toybox.Lang;

// Background only. Capture normalises the raw sensor values here; the glance
// renders an already-stored record and never scores anything.
(:background)
module Components {

    // Rounds rather than truncates, matching Readiness.compute. Truncating
    // here biased every Component Score down by up to a point before the
    // weighting even ran — 25 hours of recovery gave 47.92, stored as 47.
    //
    // fromRecoveryHours is the only producer of a fractional value; the other
    // two always yield whole numbers, so this changes nothing for them. The
    // float tie-rounding hazard that forced integer arithmetic in Readiness
    // does not arise here: an exact .5 needs hours ≡ 6 (mod 12), and every
    // such value makes hours/48 an exact eighth (1/8, 3/8, 5/8, 7/8), which
    // is representable without error.
    function clamp(value as Lang.Float) as Lang.Number {
        if (value < 0.0)   { return 0; }
        if (value > 100.0) { return 100; }
        return (value + 0.5).toNumber();
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
