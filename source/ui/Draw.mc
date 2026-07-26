using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

module Draw {

    // Every angle below is built by SUBTRACTING a sweep from a start angle,
    // so end angles go negative routinely: the 270-degree track alone is
    // 225 - 270 = -45. Whether Dc.drawArc normalises a negative angle itself
    // is NOT documented, and without a simulator it is unproven either way.
    // This is therefore defensive: if drawArc already normalises, norm() is
    // a no-op; if it does not, it is the difference between a correct track
    // and a missing or wrong one on all three surfaces, every frame.
    function norm(angle as Lang.Number) as Lang.Number {
        return ((angle % 360) + 360) % 360;
    }

    // 270-degree arc opening at the bottom, filled clockwise (design baseline).
    // `dashed` marks a Now Score so it can never be read as a Morning Score.
    function scoreArc(
        dc as Graphics.Dc,
        score as Lang.Number,
        colour as Lang.Number,
        dimmed as Lang.Boolean,
        dashed as Lang.Boolean
    ) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        dc.setPenWidth(Theme.ARC_WIDTH);

        // The track dims with the state. A score the app cannot vouch for
        // recedes entirely, ring included — matching mockup screens 02s/02e.
        dc.setColor(dimmed ? Theme.DIM_TRACK : Theme.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, Theme.ARC_RADIUS, Graphics.ARC_CLOCKWISE,
                   norm(Theme.ARC_START_DEGREES),
                   norm(Theme.ARC_START_DEGREES - Theme.ARC_SWEEP_DEGREES));

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
                dc.drawArc(cx, cy, Theme.ARC_RADIUS, Graphics.ARC_CLOCKWISE,
                           norm(from), norm(to));
            }
        } else {
            dc.drawArc(cx, cy, Theme.ARC_RADIUS, Graphics.ARC_CLOCKWISE,
                       norm(Theme.ARC_START_DEGREES),
                       norm(Theme.ARC_START_DEGREES - sweep));
        }
    }

    function componentDial(
        dc as Graphics.Dc,
        x as Lang.Number,
        y as Lang.Number,
        value as Lang.Number?,
        colour as Lang.Number,
        dimmed as Lang.Boolean,
        caption as Lang.String
    ) as Void {
        dc.setPenWidth(Theme.DIAL_WIDTH);

        // `dimmed` is a Boolean rather than a second colour parameter on
        // purpose. Two adjacent Lang.Number colours can be transposed at a
        // call site with no compile or runtime error, rendering wrongly and
        // silently; a Boolean cannot be confused with a colour int.
        dc.setColor(dimmed ? Theme.DIM_TRACK : Theme.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, Theme.DIAL_RADIUS);

        // Guard the degenerate arc exactly as scoreArc does. A start angle
        // equal to its end angle is not reliably "draw nothing" in Connect
        // IQ — it can render a FULL circle, which would paint a Component
        // Score of 0 as a completely filled ring. Zero is reachable on real
        // mornings: 48+ hours of recovery outstanding, or RHR 12+ bpm above
        // baseline. Those are exactly the days a full ring misleads most.
        if (value != null && value > 0) {
            dc.setColor(colour, Graphics.COLOR_TRANSPARENT);

            // Cap the sweep one degree short of a full turn. A Component
            // Score of 100 is common (RHR at or below baseline scores
            // exactly 100), and 360 degrees normalises the end angle back
            // onto the start angle — the same degenerate start == end case
            // the guard above exists to avoid, which can render as NOTHING
            // and would paint a perfect component as an empty ring. One
            // degree at radius 31 is under half a pixel of gap.
            var sweep = 360 * value / 100;
            if (sweep > 359) { sweep = 359; }

            dc.drawArc(x, y, Theme.DIAL_RADIUS, Graphics.ARC_CLOCKWISE,
                       norm(90), norm(90 - sweep));
        }

        // A Component Score of 0 still shows its number — only the ring fill
        // is suppressed. Absent (null) shows neither.
        if (value != null) {
            // The number dims with the state as well. A stale score whose
            // dial figures stayed full white would read as live at a glance,
            // which is exactly what the uncoloured state exists to prevent.
            dc.setColor(dimmed ? Theme.SECONDARY_TEXT : Theme.PRIMARY_TEXT,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y - 14, Graphics.FONT_SMALL, value.toString(),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Theme.SECONDARY_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + Theme.DIAL_RADIUS + 8, Graphics.FONT_XTINY, caption,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }
}
