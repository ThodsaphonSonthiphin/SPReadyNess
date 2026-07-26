using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

// Always the Morning Score, never the Now Score (ADR 0014): a glance is
// passive, so answering an unasked question would present a drained evening
// Body Battery as a verdict.
(:glance)
class SPReadyNessGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.BACKGROUND, Theme.BACKGROUND);
        dc.clear();

        var state = DisplayState.forRecord(RecordStore.latest(), DailyRecord.today());
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Theme.PRIMARY_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(5, 2, Graphics.FONT_TINY, "Readiness", Graphics.TEXT_JUSTIFY_LEFT);

        if (state[:kind] == DisplayState.EMPTY) {
            dc.setColor(Theme.SECONDARY_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(5, h / 2, Graphics.FONT_XTINY, "First score tomorrow",
                        Graphics.TEXT_JUSTIFY_LEFT);
            return;
        }

        var record = state[:record];
        var current = (state[:kind] == DisplayState.CURRENT);
        var colour = current
            ? StatusBand.colourOf(StatusBand.of(record[:score]))
            : Theme.SECONDARY_TEXT;

        // UNCHECKED is TODAY's record with RHR missing, not an old one, so
        // it must not fall through to the age branch — DisplayState sets its
        // ageDays to 0 and the wearer would read "0d ago", which is both
        // confusing and false. The glance uses a short form because the card
        // is a narrow strip; the main screen spells it out in full.
        var label;
        if (current) {
            label = StatusBand.nameOf(StatusBand.of(record[:score]));
        } else if (state[:kind] == DisplayState.UNCHECKED) {
            label = WatchUi.loadResource(Rez.Strings.NoRhrShort) as Lang.String;
        } else if (state[:ageDays] <= 0) {
            // Reachable when a timezone crossing leaves a future-dated
            // record as the newest (ADR 0006).
            label = WatchUi.loadResource(Rez.Strings.NotToday) as Lang.String;
        } else if (state[:ageDays] == 1) {
            label = "1d ago";
        } else {
            label = state[:ageDays].toString() + "d ago";
        }

        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(5, h / 2 - 6, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(w - 5, h / 2 - 6, Graphics.FONT_SMALL, record[:score].toString(),
                    Graphics.TEXT_JUSTIFY_RIGHT);

        // Gradient bar (design baseline, "Components"): a red-to-green strip
        // with a position marker. An arc does not fit on a glance strip, so
        // this is the glance's whole visual scale.
        var barY    = h - 10;
        var barLeft = 5;
        var barW    = w - 10;

        dc.setPenWidth(6);

        if (current) {
            // Four abutting segments, left to right, at the real Status Band
            // boundaries — 0/40/60/80/100 — rather than four equal quarters.
            // Sized this way the marker always lands over its own band's
            // colour, so the strip and the label can never disagree.
            var edges = [ 0, 40, 60, 80, 100 ];
            for (var band = 0; band < 4; band += 1) {
                dc.setColor(StatusBand.colourOf(band), Graphics.COLOR_TRANSPARENT);
                dc.drawLine(barLeft + (barW * edges[band] / 100), barY,
                            barLeft + (barW * edges[band + 1] / 100), barY);
            }
        } else {
            // Uncoloured state: a gradient IS advice, so a score the app
            // cannot vouch for gets the flat desaturated track instead.
            dc.setColor(Theme.DIM_TRACK, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(barLeft, barY, barLeft + barW, barY);
        }

        // Marker on top, in primary text rather than a band colour: it marks
        // a position, it does not carry the recommendation.
        var markerX = barLeft + (barW * record[:score] / 100);
        // Clamp inside the bar. At score 0 and score 100 the marker sits
        // exactly on an end and would otherwise hang half off the strip.
        if (markerX < barLeft + 2)          { markerX = barLeft + 2; }
        if (markerX > barLeft + barW - 2)   { markerX = barLeft + barW - 2; }

        dc.setPenWidth(3);
        dc.setColor(Theme.PRIMARY_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(markerX, barY - 6, markerX, barY + 6);
    }
}
