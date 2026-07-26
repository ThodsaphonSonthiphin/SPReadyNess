using Toybox.Lang;

module Constants {
    // Score weights — exact fractions, never rounded percentages (ADR 0004/0005)
    const WEIGHT_BODY     = 0.50;
    const WEIGHT_RECOVERY = 0.30;
    const WEIGHT_RHR      = 0.20;

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
