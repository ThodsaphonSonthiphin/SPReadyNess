using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class NowView extends WatchUi.View {

    private var _result as Lang.Dictionary?;
    private var _body as Lang.Number?;
    private var _recovery as Lang.Number?;
    private var _rhr as Lang.Number?;
    private var _stamp as Lang.String;

    function initialize() {
        View.initialize();
        _result = null;
        _body = null;
        _recovery = null;
        _rhr = null;
        _stamp = "";
    }

    // Computed once on entry (ADR 0014). Paging down IS the demand; the
    // visible timestamp is what keeps a few-minutes-old value honest.
    function onShow() as Void {
        // CURRENT body battery, deliberately not the at-wake value (ADR 0010).
        _body     = Components.fromBodyBattery(Sensors.bodyBatteryNow());
        _recovery = Components.fromRecoveryHours(Sensors.recoveryHours());

        // RHR is a daily profile value and cannot change intraday, so it is
        // carried over rather than "re-read" — only two inputs actually move.
        var rhrValue = Sensors.rhr();
        var baseline = Sensors.rhrBaseline();
        _rhr = Components.fromRhr(rhrValue, baseline);
        var delta = (rhrValue != null && baseline != null) ? rhrValue - baseline : null;

        _result = Readiness.compute(_body, _recovery, _rhr, delta);

        var now = System.getClockTime();
        _stamp = "NOW " + now.hour.format("%02d") + ":" + now.min.format("%02d");
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.BACKGROUND, Theme.BACKGROUND);
        dc.clear();

        var cx = dc.getWidth() / 2;

        if (_result == null) {
            dc.setColor(Theme.SECONDARY_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 180, Graphics.FONT_MEDIUM, "NO DATA",
                        Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var score = _result[:score];

        // The uncoloured state is a rule about the SCORE, not about the
        // screen (ADR 0005, docs/design-baseline.md "The uncoloured state").
        // With RHR absent, compute() renormalises over the two remaining
        // weights and the illness override never runs, so the number is a
        // reading and not advice — on this page exactly as on the glance and
        // the Morning page. rhrChecked is what compute() reports for this.
        var vouched = _result[:rhrChecked];

        var colour = vouched
            ? StatusBand.colourOf(StatusBand.of(score))
            : Theme.SECONDARY_TEXT;

        var label = vouched
            ? StatusBand.nameOf(StatusBand.of(score))
            : WatchUi.loadResource(Rez.Strings.NoRhr) as Lang.String;

        // `dashed` and `dimmed` are independent and both are set here on
        // purpose. Dashed says "live, not the authoritative morning number";
        // dimmed says "the app cannot vouch for this". A Now Score is always
        // the former and only sometimes the latter.
        Draw.scoreArc(dc, score, colour, !vouched, true);

        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        // Pill width comes from the real measured text (FONT_SMALL "NOW
        // hh:mm" is ~189px wide, not the ~112px originally guessed before
        // this had ever been rendered) plus padding, so it can't drift out
        // of sync with the text again. Height/position keep the mockup's
        // slim-badge proportions unchanged: those already render correctly
        // (confirmed on screen) even though the font's reported bounding
        // box height overstates actual glyph ink for this string.
        var stampWidth = dc.getTextDimensions(_stamp, Graphics.FONT_SMALL)[0];
        var pillW = stampWidth + 32;
        dc.drawRoundedRectangle(cx - pillW / 2, 92, pillW, 34, 17);
        dc.drawText(cx, 95, Graphics.FONT_SMALL, _stamp, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 130, Graphics.FONT_MEDIUM, label,
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(vouched ? Theme.PRIMARY_TEXT : Theme.SECONDARY_TEXT,
                    Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 165, Graphics.FONT_NUMBER_THAI_HOT, score.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);

        drawDials(dc, cx, vouched);
    }

    // The same three Component Scores the headline was built from. Without
    // these the wearer cannot see WHY a live score differs from this
    // morning's — which is almost always Body Battery having drained by the
    // clock rather than by fatigue (ADR 0010).
    //
    // The dials follow the headline: when the score is not vouched for they
    // go grey and dimmed together with it, exactly as MorningView does in
    // its UNCHECKED state. Leaving Body and Recovery in full band colour
    // under a grey headline would put the advice channel back on screen by
    // the side door.
    function drawDials(dc as Graphics.Dc, cx as Lang.Number, vouched as Lang.Boolean) as Void {
        var y = 278;
        var dials = [
            [ cx - 83, _body,     "Body" ],
            [ cx,      _recovery, "Recov." ],
            [ cx + 83, _rhr,      "RHR" ]
        ];

        for (var i = 0; i < dials.size(); i += 1) {
            var value = dials[i][1];
            var colour = Theme.SECONDARY_TEXT;
            if (vouched && value != null) {
                colour = StatusBand.colourOf(StatusBand.of(value));
            }
            // Draw.componentDial(dc, x, y, value, colour, dimmed, caption) —
            // checked against the signature in source/ui/Draw.mc. `dimmed`
            // is a Boolean, so it cannot be transposed with `colour`.
            Draw.componentDial(dc, dials[i][0], y, value, colour, !vouched, dials[i][2]);
        }
    }
}
