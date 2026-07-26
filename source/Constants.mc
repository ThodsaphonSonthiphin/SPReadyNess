using Toybox.Lang;

module Constants {
    // Score weights as INTEGER numerators over their runtime sum — exact
    // fractions, never rounded percentages (ADR 0004/0005), and never floats.
    // 0.5f + 0.3f is 0.800000011920929, not 0.8, which pushes exact .5 ties
    // below the boundary and rounds them down. Integers have no such error.
    const WEIGHT_BODY     = 50;
    const WEIGHT_RECOVERY = 30;
    const WEIGHT_RHR      = 20;

    // Component normalisation (ADR 0004) — plausibility-chosen, to be tuned
    const RECOVERY_FULL_HOURS = 48;
    const RHR_SLOPE           = 8;

    // RHR override (ADR 0004)
    const RHR_CAP_EASY_BPM  = 7;
    const RHR_CAP_REST_BPM  = 12;
    const CAP_EASY_CEILING  = 59;
    const CAP_REST_CEILING  = 39;

    // Store (ADR 0006)
    const MAX_RECORDS   = 120;
    const STORAGE_KEY   = "records";

    // Capture schedule (ADR 0012)
    const CAPTURE_INTERVAL_MINUTES = 30;
}
