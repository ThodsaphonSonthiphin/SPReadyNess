using Toybox.Test;
using Toybox.Lang;

(:test)
function recoveryZeroMeansFullyRecovered(logger as Test.Logger) as Lang.Boolean {
    // ADR 0005: zero hours outstanding is the BEST case, not missing data
    Test.assertEqualMessage(Components.fromRecoveryHours(0), 100, "0h = fully recovered");
    Test.assertEqualMessage(Components.fromRecoveryHours(null), null, "null = absent");
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
function rhrAtOrBelowBaselineIsPerfect(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(Components.fromRhr(50, 50), 100, "at baseline = 100");
    Test.assertEqualMessage(Components.fromRhr(45, 50), 100, "below baseline clamps to 100");
    return true;
}

(:test)
function rhrDeviationScales(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(Components.fromRhr(55, 50), 60, "+5bpm x8 = 100-40");
    Test.assertEqualMessage(Components.fromRhr(70, 50), 0,  "+20bpm clamps to 0");
    Test.assertEqualMessage(Components.fromRhr(null, 50), null, "no rhr = absent");
    Test.assertEqualMessage(Components.fromRhr(50, null), null, "no baseline = absent");
    return true;
}

(:test)
function bodyBatteryPassesThrough(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(Components.fromBodyBattery(88), 88);
    Test.assertEqual(Components.fromBodyBattery(null), null);
    return true;
}
