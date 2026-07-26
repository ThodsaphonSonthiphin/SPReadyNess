using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class NowView extends WatchUi.View {

    private var _result as Lang.Dictionary?;
    private var _stamp as Lang.String;

    function initialize() {
        View.initialize();
        _result = null;
        _stamp = "";
    }

    // Computed once on entry (ADR 0014). Paging down IS the demand; the
    // visible timestamp is what keeps a few-minutes-old value honest.
    function onShow() as Void {
        // CURRENT body battery, deliberately not the at-wake value (ADR 0010).
        var cBody     = Components.fromBodyBattery(Sensors.bodyBatteryNow());
        var cRecovery = Components.fromRecoveryHours(Sensors.recoveryHours());

        // RHR is a daily profile value and cannot change intraday, so it is
        // carried over rather than "re-read" — only two inputs actually move.
        var rhrValue = Sensors.rhr();
        var baseline = Sensors.rhrBaseline();
        var cRhr = Components.fromRhr(rhrValue, baseline);
        var delta = (rhrValue != null && baseline != null) ? rhrValue - baseline : null;

        _result = Readiness.compute(cBody, cRecovery, cRhr, delta);

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
        var colour = StatusBand.colourOf(StatusBand.of(score));

        // Dashed: a Now Score must never be mistaken for a Morning Score.
        Draw.scoreArc(dc, score, colour, false, true);

        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 95, Graphics.FONT_SMALL, _stamp, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, 130, Graphics.FONT_MEDIUM,
                    StatusBand.nameOf(StatusBand.of(score)),
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Theme.PRIMARY_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 165, Graphics.FONT_NUMBER_THAI_HOT, score.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}
