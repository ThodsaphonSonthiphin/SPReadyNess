using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class MorningView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.BACKGROUND, Theme.BACKGROUND);
        dc.clear();

        var state = DisplayState.forRecord(RecordStore.latest(), DailyRecord.today());

        if (state[:kind] == DisplayState.EMPTY) {
            drawEmpty(dc);
            return;
        }

        var record = state[:record];
        var current = (state[:kind] == DisplayState.CURRENT);

        // Colour carries the recommendation, so a score the app cannot vouch
        // for is drawn grey (ADR 0009 / ADR 0005).
        var colour = current
            ? StatusBand.colourOf(StatusBand.of(record[:score]))
            : Theme.SECONDARY_TEXT;

        var caption = current
            ? StatusBand.nameOf(StatusBand.of(record[:score]))
            : captionFor(state);

        Draw.scoreArc(dc, record[:score], colour, !current, false);

        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, 100, Graphics.FONT_MEDIUM, caption,
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(current ? Theme.PRIMARY_TEXT : Theme.SECONDARY_TEXT,
                    Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, 145, Graphics.FONT_NUMBER_THAI_HOT,
                    record[:score].toString(), Graphics.TEXT_JUSTIFY_CENTER);

        drawDials(dc, record, current);
    }

    function captionFor(state as Lang.Dictionary) as Lang.String {
        if (state[:kind] == DisplayState.UNCHECKED) {
            return WatchUi.loadResource(Rez.Strings.NoRhr) as Lang.String;
        }
        var days = state[:ageDays];
        // ADR 0006: a timezone crossing can move the local date backward, so
        // latest() can return a record dated later than today. ageInDays
        // then goes negative, and Monkey C truncates toward zero, landing on
        // 0 — indistinguishable from "today" if left unguarded. Neither a
        // negative nor a zero age here is a real elapsed day, so both get a
        // caption that doesn't claim one.
        if (days <= 0) {
            return WatchUi.loadResource(Rez.Strings.NotToday) as Lang.String;
        }
        if (days == 1) { return "1 DAY AGO"; }
        return days.toString() + " DAYS AGO";
    }

    // ADR 0015: no number at all. A zero would be a legitimate REST morning,
    // and the two must never look alike.
    function drawEmpty(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;

        Draw.scoreArc(dc, 0, Theme.TRACK, true, false);
        dc.setColor(Theme.SECONDARY_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 160, Graphics.FONT_MEDIUM,
                    WatchUi.loadResource(Rez.Strings.FirstScore) as Lang.String,
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 195, Graphics.FONT_MEDIUM,
                    WatchUi.loadResource(Rez.Strings.TomorrowMorning) as Lang.String,
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Mockup 02e keeps the three rings visible but empty, so the screen's
        // structure is identical in every state and nothing jumps position
        // when the first score arrives. A null value draws ring and caption
        // only — no number, which is the whole point of the empty state.
        Draw.componentDial(dc, cx - 83, 268, null, Theme.SECONDARY_TEXT, true, "Body");
        Draw.componentDial(dc, cx,      268, null, Theme.SECONDARY_TEXT, true, "Recov.");
        Draw.componentDial(dc, cx + 83, 268, null, Theme.SECONDARY_TEXT, true, "RHR");
    }

    function drawDials(dc as Graphics.Dc, record as Lang.Dictionary, current as Lang.Boolean) as Void {
        var y = 268;
        var cx = dc.getWidth() / 2;
        var dials = [
            [ cx - 83, record[:body],     "Body" ],
            [ cx,      record[:recovery], "Recov." ],
            [ cx + 83, record[:rhr],      "RHR" ]
        ];

        for (var i = 0; i < dials.size(); i += 1) {
            var value = dials[i][1];
            var colour = Theme.SECONDARY_TEXT;
            if (current && value != null) {
                colour = StatusBand.colourOf(StatusBand.of(value));
            }
            // Draw.componentDial(dc, x, y, value, colour, dimmed, caption) —
            // verified against the signature in source/ui/Draw.mc. `dimmed`
            // is a Boolean (not a second colour int), so there is no
            // transposition risk with `colour` at this call site.
            Draw.componentDial(dc, dials[i][0], y, value, colour, !current, dials[i][2]);
        }
    }
}
