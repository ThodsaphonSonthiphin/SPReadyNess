using Toybox.Graphics;
using Toybox.Lang;

// Tokens from docs/design-baseline.md. Pure black is non-negotiable: on an
// AMOLED panel a black pixel is an unlit pixel, so #000000 is both the
// highest-contrast and lowest-power ground.
module Theme {
    const BACKGROUND     = 0x000000;
    const PRIMARY_TEXT   = 0xFFFFFF;
    const SECONDARY_TEXT = 0x9E9E9E;
    const TRACK          = 0x3A3A3C;
    const DIM_TRACK      = 0x262628;

    const ARC_RADIUS  = 150;
    const ARC_WIDTH   = 13;
    const DIAL_RADIUS = 31;
    const DIAL_WIDTH  = 7;

    // 270 degrees opening at the bottom
    const ARC_START_DEGREES = 225;
    const ARC_SWEEP_DEGREES = 270;
}
