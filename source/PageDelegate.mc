using Toybox.Lang;
using Toybox.WatchUi;

// Page 1 Morning Score, page 2 Now Score, reached by DOWN (ADR 0014).
class PageDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() as Lang.Boolean {
        // NowPageDelegate, not another PageDelegate. Handing page 2 its own
        // delegate would make it its own next page: every DOWN press would
        // push a further copy of NowView and re-run onShow's sensor reads,
        // stacking views without bound.
        WatchUi.pushView(new NowView(), new NowPageDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    // Page 1 is the root view. Popping it exits the app, which is not what
    // UP means on a page stack, so UP here does nothing.
    function onPreviousPage() as Lang.Boolean {
        return false;
    }
}

// Page 2. There is no page 3, so DOWN goes nowhere; UP returns to page 1.
class NowPageDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() as Lang.Boolean {
        return false;
    }

    function onPreviousPage() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
