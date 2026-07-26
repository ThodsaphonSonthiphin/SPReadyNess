using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

module Draw {

    // 270-degree arc opening at the bottom, filled clockwise (design baseline).
    // `dashed` marks a Now Score so it can never be read as a Morning Score.
    function scoreArc(
        dc as Graphics.Dc,
        score as Lang.Number,
        colour as Lang.Number,
        dashed as Lang.Boolean
    ) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        dc.setPenWidth(Theme.ARC_WIDTH);

        dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, Theme.ARC_RADIUS, Graphics.ARC_CLOCKWISE,
                   Theme.ARC_START_DEGREES,
                   Theme.ARC_START_DEGREES - Theme.ARC_SWEEP_DEGREES);

        if (score <= 0) { return; }

        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var sweep = Theme.ARC_SWEEP_DEGREES * score / 100;

        if (dashed) {
            // Approximate a dashed stroke with short segments
            var step = 10;
            for (var d = 0; d < sweep; d += step * 2) {
                var from = Theme.ARC_START_DEGREES - d;
                var to = from - step;
                if (d + step > sweep) { to = Theme.ARC_START_DEGREES - sweep; }
                dc.drawArc(cx, cy, Theme.ARC_RADIUS, Graphics.ARC_CLOCKWISE, from, to);
            }
        } else {
            dc.drawArc(cx, cy, Theme.ARC_RADIUS, Graphics.ARC_CLOCKWISE,
                       Theme.ARC_START_DEGREES, Theme.ARC_START_DEGREES - sweep);
        }
    }

    function componentDial(
        dc as Graphics.Dc,
        x as Lang.Number,
        y as Lang.Number,
        value as Lang.Number?,
        colour as Lang.Number,
        caption as Lang.String
    ) as Void {
        dc.setPenWidth(Theme.DIAL_WIDTH);

        dc.setColor(Theme.DIM_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, Theme.DIAL_RADIUS);

        if (value != null) {
            dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(x, y, Theme.DIAL_RADIUS, Graphics.ARC_CLOCKWISE,
                       90, 90 - (360 * value / 100));

            dc.setColor(Theme.PRIMARY_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y - 14, Graphics.FONT_SMALL, value.toString(),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Theme.SECONDARY_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + Theme.DIAL_RADIUS + 8, Graphics.FONT_XTINY, caption,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}
