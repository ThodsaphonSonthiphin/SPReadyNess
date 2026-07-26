using Toybox.Lang;

// Glance only. The glance card picks the band label and the gradient-bar
// segment colours here. The background never draws and never bands.
(:glance)
module StatusBand {
    enum {
        REST = 0,
        GO_EASY = 1,
        READY = 2,
        GO_HARD = 3
    }

    function of(score as Lang.Number) as Lang.Number {
        if (score >= 80) { return GO_HARD; }
        if (score >= 60) { return READY; }
        if (score >= 40) { return GO_EASY; }
        return REST;
    }

    function colourOf(band as Lang.Number) as Lang.Number {
        if (band == GO_HARD) { return 0x00E676; }
        if (band == READY)   { return 0xC6D62B; }
        if (band == GO_EASY) { return 0xFF9500; }
        return 0xFF3B30;
    }

    function nameOf(band as Lang.Number) as Lang.String {
        if (band == GO_HARD) { return "GO HARD"; }
        if (band == READY)   { return "READY"; }
        if (band == GO_EASY) { return "GO EASY"; }
        return "REST";
    }
}
