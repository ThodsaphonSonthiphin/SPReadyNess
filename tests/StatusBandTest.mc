using Toybox.Test;
using Toybox.Lang;

(:test)
function bandBoundaries(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(StatusBand.of(100), StatusBand.GO_HARD, "100 is GO HARD");
    Test.assertEqualMessage(StatusBand.of(80),  StatusBand.GO_HARD, "80 is the GO HARD floor");
    Test.assertEqualMessage(StatusBand.of(79),  StatusBand.READY,   "79 is READY");
    Test.assertEqualMessage(StatusBand.of(60),  StatusBand.READY,   "60 is the READY floor");
    Test.assertEqualMessage(StatusBand.of(59),  StatusBand.GO_EASY, "59 is GO EASY");
    Test.assertEqualMessage(StatusBand.of(40),  StatusBand.GO_EASY, "40 is the GO EASY floor");
    Test.assertEqualMessage(StatusBand.of(39),  StatusBand.REST,    "39 is REST");
    Test.assertEqualMessage(StatusBand.of(0),   StatusBand.REST,    "0 is REST");
    return true;
}

(:test)
function bandColours(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(StatusBand.colourOf(StatusBand.GO_HARD), 0x00E676);
    Test.assertEqual(StatusBand.colourOf(StatusBand.READY),   0xC6D62B);
    Test.assertEqual(StatusBand.colourOf(StatusBand.GO_EASY), 0xFF9500);
    Test.assertEqual(StatusBand.colourOf(StatusBand.REST),    0xFF3B30);
    return true;
}
