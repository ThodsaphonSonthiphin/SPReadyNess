using Toybox.Lang;

// Both scopes: the background reads the weights and the override thresholds
// through Readiness/Components, and the glance reads STORAGE_KEY and
// MAX_RECORDS through RecordStore.
(:background :glance)
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

    // RHR sensor sanity floor (ADR 0016). Genuine human resting heart rate
    // essentially never goes below this, even for elite athletes — a sample
    // under it is a sensor artifact, not physiology. See Sensors.todaysRhr(),
    // which takes a MINIMUM and so is maximally outlier-sensitive.
    const RHR_FLOOR_BPM = 30;

    // Store (ADR 0006)
    const MAX_RECORDS   = 120;
    const STORAGE_KEY   = "records";

    // Capture schedule (ADR 0012)
    const CAPTURE_INTERVAL_MINUTES = 30;
}
