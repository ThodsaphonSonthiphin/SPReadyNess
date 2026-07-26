using Toybox.Test;
using Toybox.Lang;

(:test)
function recoveryZeroMeansFullyRecovered(logger as Test.Logger) as Lang.Boolean {
    // ADR 0005: zero hours outstanding is the BEST case, not missing data
    Test.assertEqualMessage(Components.fromRecoveryHours(0), 100, "0h = fully recovered");
    // Test.assertEqualMessage crashes when the actual value is null (SDK 9.2.0
    // Run No Evil bug); assert on the equality instead of handing null to it.
    Test.assertMessage(Components.fromRecoveryHours(null) == null, "null = absent");
    return true;
}

(:test)
function recoveryScales(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(Components.fromRecoveryHours(24), 50, "24h of 48 = 50");
    Test.assertEqualMessage(Components.fromRecoveryHours(48), 0,  "48h = 0");
    Test.assertEqualMessage(Components.fromRecoveryHours(96), 0,  "clamped at 0");
    return true;
}

(:test)
function recoveryRoundsRatherThanTruncates(logger as Test.Logger) as Lang.Boolean {
    // 100 - (25/48 * 100) = 47.9166..., which must land on 48, not 47.
    // Truncating here biased every Component Score down by up to a point
    // before the weighting ran, and disagreed with Readiness.compute.
    Test.assertEqualMessage(Components.fromRecoveryHours(25), 48,
        "47.92 rounds up to 48");
    // An exact .5 case: hours ≡ 6 (mod 12) makes hours/48 an exact eighth,
    // so this is representable and rounds up without float error.
    // 100 - (6/48 * 100) = 87.5 -> 88
    Test.assertEqualMessage(Components.fromRecoveryHours(6), 88,
        "87.5 rounds up to 88");
    // Values that were already exact must be unchanged.
    Test.assertEqualMessage(Components.fromRecoveryHours(24), 50, "24h still 50");
    Test.assertEqualMessage(Components.fromRecoveryHours(0), 100, "0h still 100");
    return true;
}

(:test)
function rhrAtOrBelowBaselineIsPerfect(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(Components.fromRhr(50, 50), 100, "at baseline = 100");
    Test.assertEqualMessage(Components.fromRhr(45, 50), 100, "below baseline clamps to 100");
    return true;
}

(:test)
function rhrDeviationScales(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(Components.fromRhr(55, 50), 60, "+5bpm x8 = 100-40");
    Test.assertEqualMessage(Components.fromRhr(70, 50), 0,  "+20bpm clamps to 0");
    // Test.assertEqualMessage crashes when the actual value is null (SDK 9.2.0
    // Run No Evil bug); assert on the equality instead of handing null to it.
    Test.assertMessage(Components.fromRhr(null, 50) == null, "no rhr = absent");
    Test.assertMessage(Components.fromRhr(50, null) == null, "no baseline = absent");
    return true;
}

(:test)
function bodyBatteryPassesThrough(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(Components.fromBodyBattery(88), 88);
    // Test.assertEqual crashes when the actual value is null (SDK 9.2.0
    // Run No Evil bug); assert on the equality instead of handing null to it.
    Test.assertMessage(Components.fromBodyBattery(null) == null, "null body battery = absent");
    return true;
}
