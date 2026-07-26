using Toybox.Lang;

module Readiness {

    // Returns null when Body Battery is absent (ADR 0005) — without it,
    // half the weight and the whole HRV/sleep/stress signal are gone, so
    // what remains is a different measurement, not a degraded one.
    function compute(
        body as Lang.Number?,
        recovery as Lang.Number?,
        rhr as Lang.Number?,
        rhrDeltaBpm as Lang.Number?
    ) as Lang.Dictionary? {

        if (body == null) { return null; }

        var wBody     = Constants.WEIGHT_BODY;
        var wRecovery = (recovery == null) ? 0 : Constants.WEIGHT_RECOVERY;
        var wRhr      = (rhr == null)      ? 0 : Constants.WEIGHT_RHR;

        var total = wBody + wRecovery + wRhr;

        var sum = body * wBody;
        if (recovery != null) { sum += recovery * wRecovery; }
        if (rhr != null)      { sum += rhr * wRhr; }

        // Integer arithmetic end to end. floor((2*sum + total) / (2*total))
        // is exact round-half-up with no floating point anywhere.
        //
        // Do NOT reintroduce floats here. Weighting in float and adding 0.5
        // looks equivalent and is not: 0.5f + 0.3f evaluates to
        // 0.800000011920929, so in the RHR-absent branch an exact .5 tie
        // lands just below the boundary and truncates DOWN. A sweep of all
        // 1,030,301 input combinations found 139 such cases, 20 of which
        // cross a Status Band threshold — e.g. compute(58, 62, null, null)
        // is exactly 59.5 and must be 60 (READY), not 59 (GO EASY).
        //
        // sum peaks at 100*50 + 100*30 + 100*20 = 10000, so 2*sum is far
        // inside 32-bit range. All values are non-negative, so Monkey C's
        // truncating integer division is floor().
        var score = (2 * sum + total) / (2 * total);

        // The override is a tripwire, not a slider (ADR 0004). It can only
        // lower a score, and only when RHR was actually measured (ADR 0005).
        var rhrChecked = (rhr != null && rhrDeltaBpm != null);
        var overrideFired = false;

        if (rhrChecked) {
            if (rhrDeltaBpm >= Constants.RHR_CAP_REST_BPM && score > Constants.CAP_REST_CEILING) {
                score = Constants.CAP_REST_CEILING;
                overrideFired = true;
            } else if (rhrDeltaBpm >= Constants.RHR_CAP_EASY_BPM && score > Constants.CAP_EASY_CEILING) {
                score = Constants.CAP_EASY_CEILING;
                overrideFired = true;
            }
        }

        return {
            :score => score,
            :overrideFired => overrideFired,
            :rhrChecked => rhrChecked
        };
    }
}
