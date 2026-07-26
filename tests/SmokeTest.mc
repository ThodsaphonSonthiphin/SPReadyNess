using Toybox.Test;
using Toybox.Lang;

(:test)
function smokeTestRuns(logger as Test.Logger) as Lang.Boolean {
    logger.debug("toolchain is alive");
    Test.assertEqual(2 + 2, 4);
    return true;
}
