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

        var label = current
            ? StatusBand.nameOf(StatusBand.of(record[:score]))
            : (state[:ageDays].toString() + "d ago");

        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(5, h / 2 - 6, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(w - 5, h / 2 - 6, Graphics.FONT_SMALL, record[:score].toString(),
                    Graphics.TEXT_JUSTIFY_RIGHT);

        // Position bar. Desaturated when the score carries no advice.
        var barY = h - 10;
        dc.setPenWidth(6);
        dc.setColor(current ? Theme.TRACK : Theme.DIM_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(5, barY, w - 5, barY);
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var markerX = 5 + ((w - 10) * record[:score] / 100);
        dc.drawLine(markerX - 2, barY - 5, markerX - 2, barY + 5);
    }
}
