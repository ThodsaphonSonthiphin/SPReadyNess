using Toybox.Test;
using Toybox.Lang;

(:test)
function fullFormulaMatchesTheSpec(logger as Test.Logger) as Lang.Boolean {
    // Spec worked example: 0.50*88 + 0.30*73 + 0.20*89 = 83.7 -> 84
    var r = Readiness.compute(88, 73, 89, 0);
    Test.assertEqualMessage(r[:score], 84, "spec worked example");
    Test.assertEqualMessage(r[:overrideFired], false, "no override at delta 0");
    Test.assertEqualMessage(r[:rhrChecked], true, "rhr was present");
    return true;
}

(:test)
function noBodyBatteryMeansNoScore(logger as Test.Logger) as Lang.Boolean {
    // ADR 0005: Body Battery is load-bearing, not merely weighted
    Test.assertEqualMessage(Readiness.compute(null, 73, 89, 0), null, "no BB, no score");
    return true;
}

(:test)
function missingRecoveryRenormalises(logger as Test.Logger) as Lang.Boolean {
    // weights become 50/70 and 20/70
    var r = Readiness.compute(80, null, 60, 0);
    var expected = (80 * 50.0 / 70.0) + (60 * 20.0 / 70.0); // 57.14 + 17.14 = 74.28
    Test.assertEqualMessage(r[:score], expected.toNumber(), "renormalised to 50/70 and 20/70");
    return true;
}

(:test)
function missingRhrRenormalisesAndDisablesOverride(logger as Test.Logger) as Lang.Boolean {
    // weights become 50/80 and 30/80; override cannot run
    var r = Readiness.compute(80, 60, null, null);
    var expected = (80 * 50.0 / 80.0) + (60 * 30.0 / 80.0); // 50 + 22.5 = 72.5
    Test.assertEqualMessage(r[:score], expected.toNumber(), "renormalised to 50/80 and 30/80");
    Test.assertEqualMessage(r[:rhrChecked], false, "override could not run");
    Test.assertEqualMessage(r[:overrideFired], false, "override did not fire");
    return true;
}

(:test)
function overrideCapsAtGoEasy(logger as Test.Logger) as Lang.Boolean {
    // The case ADR 0004 exists for: high BB masking an elevated RHR
    var r = Readiness.compute(85, 90, 45, 8);
    Test.assertEqualMessage(r[:score], 59, "+8bpm caps at the GO EASY ceiling");
    Test.assertEqualMessage(r[:overrideFired], true, "override fired");
    return true;
}

(:test)
function overrideCapsAtRest(logger as Test.Logger) as Lang.Boolean {
    var r = Readiness.compute(85, 90, 20, 12);
    Test.assertEqualMessage(r[:score], 39, "+12bpm caps at the REST ceiling");
    Test.assertEqualMessage(r[:overrideFired], true, "override fired");
    return true;
}

(:test)
function overrideNeverRaisesAScore(logger as Test.Logger) as Lang.Boolean {
    // A cap is a ceiling, not an assignment
    var r = Readiness.compute(20, 20, 20, 8);
    Test.assertMessage(r[:score] < 59, "already below the ceiling, unchanged");
    return true;
}
