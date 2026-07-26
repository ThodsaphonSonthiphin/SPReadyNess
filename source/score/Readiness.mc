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
        var wRecovery = (recovery == null) ? 0.0 : Constants.WEIGHT_RECOVERY;
        var wRhr      = (rhr == null)      ? 0.0 : Constants.WEIGHT_RHR;

        var total = wBody + wRecovery + wRhr;

        var sum = body * wBody;
        if (recovery != null) { sum += recovery * wRecovery; }
        if (rhr != null)      { sum += rhr * wRhr; }

        // Round, do not truncate. Monkey C's .toNumber() truncates toward
        // zero, which would turn the spec's 83.7 into 83 and bias every
        // score down by up to a point — worst exactly at a band boundary,
        // where 79.9 would read READY instead of GO HARD. All scores are
        // non-negative, so +0.5 then truncate is exact rounding here.
        var score = (sum / total + 0.5).toNumber();

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
