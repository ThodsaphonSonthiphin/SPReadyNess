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
    // Test.assertEqualMessage crashes when the actual value is null (SDK 9.2.0
    // Run No Evil bug); assert on the equality instead of handing null to it.
    Test.assertMessage(Readiness.compute(null, 73, 89, 0) == null, "no BB, no score");
    return true;
}

(:test)
function missingRecoveryRenormalises(logger as Test.Logger) as Lang.Boolean {
    // Weights become 50/70 and 20/70.
    // (80*0.5 + 60*0.2) / 0.7 = 52 / 0.7 = 74.285... -> 74
    // The expected value is a LITERAL. Recomputing it with the same
    // arithmetic the implementation uses would make this test tautological:
    // it would pass even if the formula were wrong.
    var r = Readiness.compute(80, null, 60, 0);
    Test.assertEqualMessage(r[:score], 74, "renormalised to 50/70 and 20/70");
    return true;
}

(:test)
function missingRhrRenormalisesAndDisablesOverride(logger as Test.Logger) as Lang.Boolean {
    // Weights become 50/80 and 30/80; override cannot run.
    // (80*0.5 + 60*0.3) / 0.8 = 58 / 0.8 = 72.5 -> 73 (rounds up, not 72)
    var r = Readiness.compute(80, 60, null, null);
    Test.assertEqualMessage(r[:score], 73, "renormalised to 50/80 and 30/80");
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
    Test.assertEqualMessage(r[:overrideFired], false, "a cap that cannot lower must not report firing");
    return true;
}

(:test)
function exactHalfTieRoundsUp(logger as Test.Logger) as Lang.Boolean {
    // (58*50 + 62*30) / 80 = 4760/80 = exactly 59.5 -> 60, NOT 59.
    // 60 is READY; 59 is GO EASY. Float weighting got this wrong.
    var r = Readiness.compute(58, 62, null, null);
    Test.assertEqualMessage(r[:score], 60, "exact .5 tie rounds up, crossing a band boundary");
    return true;
}

(:test)
function onlyBodyBatteryStillScores(logger as Test.Logger) as Lang.Boolean {
    // total = 50; the score is just Body Battery
    var r = Readiness.compute(77, null, null, null);
    Test.assertEqualMessage(r[:score], 77, "body battery alone");
    Test.assertEqualMessage(r[:rhrChecked], false, "no rhr to check");
    return true;
}
