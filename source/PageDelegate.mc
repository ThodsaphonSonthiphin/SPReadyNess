using Toybox.Lang;
using Toybox.WatchUi;

// Page 1 Morning Score, page 2 Now Score, reached by DOWN (ADR 0014).
class PageDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onNextPage() as Lang.Boolean {
        WatchUi.pushView(new NowView(), new PageDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onPreviousPage() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
