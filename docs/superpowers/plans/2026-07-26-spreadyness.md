# SPReadyNess Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Connect IQ watch app for the Garmin Forerunner 165 that computes a daily Readiness Score from Body Battery, recovery time and resting heart rate, and shows it on a glance card and two pages.

**Architecture:** Pure scoring logic is isolated in stateless modules so it can be unit-tested without a device. A background service captures one Daily Record per day and writes it to a single Storage key holding an array. Views are thin: a pure function decides *which* display state applies (coloured / uncoloured / empty) and the view only draws it.

**Tech Stack:** Monkey C, Connect IQ SDK (API 5.2 target), `Toybox.Test` for unit tests, `monkeyc` / `monkeydo` CLI.

## Global Constraints

- **Target device:** `fr165` (and `fr165m` for the Music variant) — 390 × 390 round AMOLED, **API level 5.2**.
- **Permissions:** `Background` is required in `manifest.xml`.
- **Background Storage writes require CIQ ≥ 3.2.0.** The FR165 satisfies this; do not port the background write path to older devices without moving it to the foreground.
- **Storage:** one key holds an array of at most **120** Daily Records. Individual Storage values cap at **32 KB**.
- **Temporal events:** minimum interval **5 minutes**; only **one** may be registered at a time — `registerForTemporalEvent` overwrites any previous registration.
- **`Background.exit()` payload caps at ~8 KB.**
- **Colours (exact):** GO HARD `#00E676` · READY `#C6D62B` · GO EASY `#FF9500` · REST `#FF3B30` · Track `#3A3A3C` · Secondary text `#9E9E9E` · Background `#000000` (pure black, non-negotiable — AMOLED).
- **Weights are exact fractions, never rounded percentages:** full `0.50 / 0.30 / 0.20`; Recovery absent → `50/70`, `20/70`; RHR absent → `50/80`, `30/80`.
- **All five formula constants are named constants, never inline literals:** `RECOVERY_FULL_HOURS = 48`, `RHR_SLOPE = 8`, `RHR_CAP_EASY_BPM = 7`, `RHR_CAP_REST_BPM = 12`, plus the three weights.
- **A Now Score is never written to storage.**
- **Build:** `monkeyc -f monkey.jungle -d fr165 -o bin/spreadyness.prg -y $DEVELOPER_KEY`
- **Test:** `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y $DEVELOPER_KEY --unit-test && monkeydo bin/test.prg fr165 -t`
- A developer key is required: `openssl genrsa -out developer_key.pem 4096 && openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt`

**Source of truth:** [design spec](../specs/2026-07-26-spreadyness-design.md) · [ADRs](../../adr/) · [design baseline](../../design-baseline.md) · [mockup](../../mockups/screens.html)

---

## File Structure

| File | Responsibility |
|---|---|
| `manifest.xml` | app id, permissions, target devices, min API |
| `monkey.jungle` | build config, source paths |
| `source/Constants.mc` | every tunable constant in one place |
| `source/score/StatusBand.mc` | score → band name + colour |
| `source/score/Components.mc` | raw sensor value → 0–100 Component Score |
| `source/score/Readiness.mc` | weighting, renormalisation, RHR override |
| `source/store/DailyRecord.mc` | record construction + dictionary serialisation |
| `source/store/RecordStore.mc` | the single-key array, eviction, today lookup |
| `source/capture/Capture.mc` | read sensors, build a record, persist — used by both triggers |
| `source/capture/BackgroundService.mc` | `ServiceDelegate`, temporal event handler |
| `source/ui/Theme.mc` | design-baseline colours and fonts |
| `source/ui/DisplayState.mc` | pure: record + now → which state to draw |
| `source/ui/Draw.mc` | score arc and component dial primitives |
| `source/ui/MorningView.mc` | page 1 |
| `source/ui/NowView.mc` | page 2 |
| `source/ui/SPReadyNessGlanceView.mc` | glance card |
| `source/SPReadyNessApp.mc` | `AppBase`, entry points, view wiring |
| `source/PageDelegate.mc` | UP/DOWN paging |
| `tests/*.mc` | `(:test)` functions, one file per module under test |

---

## Task 1: Project skeleton that builds and runs one test

Proves the toolchain end-to-end before any logic exists. If this task doesn't pass, nothing else can be trusted.

**Files:**
- Create: `manifest.xml`, `monkey.jungle`, `source/SPReadyNessApp.mc`, `tests/SmokeTest.mc`, `.gitignore`

**Interfaces:**
- Consumes: nothing
- Produces: a buildable project; `SPReadyNessApp extends Application.AppBase`

- [ ] **Step 1: Create the manifest**

Create `manifest.xml`:

```xml
<?xml version="1.0"?>
<iq:manifest xmlns:iq="http://www.garmin.com/xml/connectiq" version="3">
    <iq:application entry="SPReadyNessApp"
                    id="a1b2c3d4e5f64718293a4b5c6d7e8f90"
                    launcherIcon="@Drawables.LauncherIcon"
                    name="@Strings.AppName"
                    minApiLevel="3.3.0"
                    type="watch-app">
        <iq:products>
            <iq:product id="fr165"/>
            <iq:product id="fr165m"/>
        </iq:products>
        <iq:permissions>
            <iq:uses-permission id="Background"/>
        </iq:permissions>
        <iq:languages>
            <iq:language>eng</iq:language>
        </iq:languages>
        <iq:barrels/>
    </iq:application>
</iq:manifest>
```

`minApiLevel` is `3.3.0` because `getBodyBatteryHistory()` and `timeToRecovery` require it.

- [ ] **Step 2: Create the jungle and resources**

Create `monkey.jungle`:

```
project.manifest = manifest.xml
base.sourcePath = source
base.resourcePath = resources
```

Create `resources/strings/strings.xml`:

```xml
<strings>
    <string id="AppName">SPReadyNess</string>
    <string id="FirstScore">FIRST SCORE</string>
    <string id="TomorrowMorning">TOMORROW MORNING</string>
    <string id="NoRhr">NO RHR — UNCHECKED</string>
</strings>
```

Create `resources/drawables/drawables.xml`:

```xml
<drawables>
    <bitmap id="LauncherIcon" filename="launcher_icon.png"/>
</drawables>
```

Create a 40×40 PNG at `resources/drawables/launcher_icon.png` (any solid-colour placeholder is fine for now).

- [ ] **Step 3: Create the minimal app**

Create `source/SPReadyNessApp.mc`:

```monkeyc
using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

class SPReadyNessApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as Lang.Array<WatchUi.Views or WatchUi.InputDelegates>? {
        return [ new WatchUi.View() ] as Lang.Array<WatchUi.Views>;
    }
}
```

- [ ] **Step 4: Write a smoke test**

Create `tests/SmokeTest.mc`:

```monkeyc
using Toybox.Test;
using Toybox.Lang;

(:test)
function smokeTestRuns(logger as Test.Logger) as Lang.Boolean {
    logger.debug("toolchain is alive");
    Test.assertEqual(2 + 2, 4);
    return true;
}
```

Add the tests directory to `monkey.jungle`:

```
base.sourcePath = source;tests
```

- [ ] **Step 5: Generate a developer key and build**

Run:

```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test
```

Expected: build succeeds, `bin/test.prg` exists.

- [ ] **Step 6: Run the test**

Run: `monkeydo bin/test.prg fr165 -t`
Expected: `smokeTestRuns` PASS.

- [ ] **Step 7: Commit**

Create `.gitignore`:

```
bin/
developer_key.pem
developer_key.der
*.prg
*.iq
```

```bash
git add manifest.xml monkey.jungle source tests resources .gitignore
git commit -m "feat: connect iq project skeleton with passing smoke test"
```

---

## Task 2: Constants and Status Bands

**Files:**
- Create: `source/Constants.mc`, `source/score/StatusBand.mc`, `tests/StatusBandTest.mc`

**Interfaces:**
- Produces: `Constants.WEIGHT_BODY/WEIGHT_RECOVERY/WEIGHT_RHR`, `Constants.RECOVERY_FULL_HOURS`, `Constants.RHR_SLOPE`, `Constants.RHR_CAP_EASY_BPM`, `Constants.RHR_CAP_REST_BPM`, `Constants.MAX_RECORDS`, `Constants.CAP_EASY_CEILING`, `Constants.CAP_REST_CEILING` — **all `Lang.Number`, never Float**. The weights are integer numerators over their runtime sum; a Float anywhere in that path silently reintroduces the tie-rounding bug. `StatusBand.of(score as Lang.Number) as Lang.Number` returning `StatusBand.GO_HARD|READY|GO_EASY|REST`; `StatusBand.colourOf(band as Lang.Number) as Lang.Number`; `StatusBand.nameOf(band as Lang.Number) as Lang.String`

- [ ] **Step 1: Write the failing test**

Create `tests/StatusBandTest.mc`:

```monkeyc
using Toybox.Test;
using Toybox.Lang;

(:test)
function bandBoundaries(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(StatusBand.of(100), StatusBand.GO_HARD, "100 is GO HARD");
    Test.assertEqualMessage(StatusBand.of(80),  StatusBand.GO_HARD, "80 is the GO HARD floor");
    Test.assertEqualMessage(StatusBand.of(79),  StatusBand.READY,   "79 is READY");
    Test.assertEqualMessage(StatusBand.of(60),  StatusBand.READY,   "60 is the READY floor");
    Test.assertEqualMessage(StatusBand.of(59),  StatusBand.GO_EASY, "59 is GO EASY");
    Test.assertEqualMessage(StatusBand.of(40),  StatusBand.GO_EASY, "40 is the GO EASY floor");
    Test.assertEqualMessage(StatusBand.of(39),  StatusBand.REST,    "39 is REST");
    Test.assertEqualMessage(StatusBand.of(0),   StatusBand.REST,    "0 is REST");
    return true;
}

(:test)
function bandColours(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(StatusBand.colourOf(StatusBand.GO_HARD), 0x00E676);
    Test.assertEqual(StatusBand.colourOf(StatusBand.READY),   0xC6D62B);
    Test.assertEqual(StatusBand.colourOf(StatusBand.GO_EASY), 0xFF9500);
    Test.assertEqual(StatusBand.colourOf(StatusBand.REST),    0xFF3B30);
    return true;
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test`
Expected: FAIL — compile error, `StatusBand` undefined.

- [ ] **Step 3: Write the constants**

Create `source/Constants.mc`:

```monkeyc
using Toybox.Lang;

module Constants {
    // Score weights as INTEGER numerators over their runtime sum — exact
    // fractions, never rounded percentages (ADR 0004/0005), and never floats.
    // 0.5f + 0.3f is 0.800000011920929, not 0.8, which pushes exact .5 ties
    // below the boundary and rounds them down. Integers have no such error.
    const WEIGHT_BODY     = 50;
    const WEIGHT_RECOVERY = 30;
    const WEIGHT_RHR      = 20;

    // Component normalisation (ADR 0004) — plausibility-chosen, to be tuned
    const RECOVERY_FULL_HOURS = 48;
    const RHR_SLOPE           = 8;

    // RHR override (ADR 0004)
    const RHR_CAP_EASY_BPM  = 7;
    const RHR_CAP_REST_BPM  = 12;
    const CAP_EASY_CEILING  = 59;
    const CAP_REST_CEILING  = 39;

    // Store (ADR 0006)
    const MAX_RECORDS   = 120;
    const STORAGE_KEY   = "records";

    // Capture schedule (ADR 0012)
    const CAPTURE_INTERVAL_MINUTES = 30;
}
```

- [ ] **Step 4: Write StatusBand**

Create `source/score/StatusBand.mc`:

```monkeyc
using Toybox.Lang;

module StatusBand {
    enum {
        REST = 0,
        GO_EASY = 1,
        READY = 2,
        GO_HARD = 3
    }

    function of(score as Lang.Number) as Lang.Number {
        if (score >= 80) { return GO_HARD; }
        if (score >= 60) { return READY; }
        if (score >= 40) { return GO_EASY; }
        return REST;
    }

    function colourOf(band as Lang.Number) as Lang.Number {
        if (band == GO_HARD) { return 0x00E676; }
        if (band == READY)   { return 0xC6D62B; }
        if (band == GO_EASY) { return 0xFF9500; }
        return 0xFF3B30;
    }

    function nameOf(band as Lang.Number) as Lang.String {
        if (band == GO_HARD) { return "GO HARD"; }
        if (band == READY)   { return "READY"; }
        if (band == GO_EASY) { return "GO EASY"; }
        return "REST";
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: `bandBoundaries` PASS, `bandColours` PASS.

- [ ] **Step 6: Commit**

```bash
git add source/Constants.mc source/score/StatusBand.mc tests/StatusBandTest.mc
git commit -m "feat: status bands and tunable constants"
```

---

## Task 3: Component Score normalisation

The three raw→0–100 conversions. Note the `timeToRecovery` null-vs-zero distinction — this is the trap ADR 0005 exists to prevent.

**Files:**
- Create: `source/score/Components.mc`, `tests/ComponentsTest.mc`

**Interfaces:**
- Consumes: `Constants`
- Produces: `Components.fromBodyBattery(bb as Lang.Number?) as Lang.Number?`, `Components.fromRecoveryHours(hours as Lang.Number?) as Lang.Number?`, `Components.fromRhr(rhr as Lang.Number?, baseline as Lang.Number?) as Lang.Number?` — each returns `null` when its input is unavailable

- [ ] **Step 1: Write the failing tests**

Create `tests/ComponentsTest.mc`:

```monkeyc
using Toybox.Test;
using Toybox.Lang;

(:test)
function recoveryZeroMeansFullyRecovered(logger as Test.Logger) as Lang.Boolean {
    // ADR 0005: zero hours outstanding is the BEST case, not missing data
    Test.assertEqualMessage(Components.fromRecoveryHours(0), 100, "0h = fully recovered");
    Test.assertEqualMessage(Components.fromRecoveryHours(null), null, "null = absent");
    return true;
}

(:test)
function recoveryScales(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(Components.fromRecoveryHours(24), 50, "24h of 48 = 50");
    Test.assertEqualMessage(Components.fromRecoveryHours(48), 0,  "48h = 0");
    Test.assertEqualMessage(Components.fromRecoveryHours(96), 0,  "clamped at 0");
    return true;
}

(:test)
function rhrAtOrBelowBaselineIsPerfect(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(Components.fromRhr(50, 50), 100, "at baseline = 100");
    Test.assertEqualMessage(Components.fromRhr(45, 50), 100, "below baseline clamps to 100");
    return true;
}

(:test)
function rhrDeviationScales(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqualMessage(Components.fromRhr(55, 50), 60, "+5bpm x8 = 100-40");
    Test.assertEqualMessage(Components.fromRhr(70, 50), 0,  "+20bpm clamps to 0");
    Test.assertEqualMessage(Components.fromRhr(null, 50), null, "no rhr = absent");
    Test.assertEqualMessage(Components.fromRhr(50, null), null, "no baseline = absent");
    return true;
}

(:test)
function bodyBatteryPassesThrough(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(Components.fromBodyBattery(88), 88);
    Test.assertEqual(Components.fromBodyBattery(null), null);
    return true;
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test`
Expected: FAIL — `Components` undefined.

- [ ] **Step 3: Implement**

Create `source/score/Components.mc`:

```monkeyc
using Toybox.Lang;

module Components {

    function clamp(value as Lang.Float) as Lang.Number {
        if (value < 0.0)   { return 0; }
        if (value > 100.0) { return 100; }
        return value.toNumber();
    }

    function fromBodyBattery(bb as Lang.Number?) as Lang.Number? {
        if (bb == null) { return null; }
        return clamp(bb.toFloat());
    }

    // ADR 0005: zero hours means fully recovered, NOT missing data.
    // Only a genuine null is absent.
    function fromRecoveryHours(hours as Lang.Number?) as Lang.Number? {
        if (hours == null) { return null; }
        var full = Constants.RECOVERY_FULL_HOURS.toFloat();
        return clamp(100.0 - (hours.toFloat() / full * 100.0));
    }

    function fromRhr(rhr as Lang.Number?, baseline as Lang.Number?) as Lang.Number? {
        if (rhr == null || baseline == null) { return null; }
        var delta = rhr - baseline;
        if (delta <= 0) { return 100; }
        return clamp(100.0 - (delta.toFloat() * Constants.RHR_SLOPE));
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: all five PASS.

- [ ] **Step 5: Commit**

```bash
git add source/score/Components.mc tests/ComponentsTest.mc
git commit -m "feat: component score normalisation"
```

---

## Task 4: The Readiness Score — weighting, renormalisation, override

The heart of the product. Every branch of ADR 0004 and ADR 0005 is tested here.

**Files:**
- Create: `source/score/Readiness.mc`, `tests/ReadinessTest.mc`

**Interfaces:**
- Consumes: `Constants`
- Produces: `Readiness.compute(body as Lang.Number?, recovery as Lang.Number?, rhr as Lang.Number?, rhrDeltaBpm as Lang.Number?) as Lang.Dictionary?` returning `{ :score => Number, :overrideFired => Boolean, :rhrChecked => Boolean }`, or `null` when Body Battery is absent

- [ ] **Step 1: Write the failing tests**

Create `tests/ReadinessTest.mc`:

```monkeyc
using Toybox.Test;
using Toybox.Lang;

(:test)
function fullFormulaMatchesTheSpec(logger as Test.Logger) as Lang.Boolean {
    // Spec worked example: 0.50*88 + 0.30*73 + 0.20*89 = 83.7 -> 84
    var r = Readiness.compute(88, 73, 89, 0);
    Test.assertEqualMessage(r[:score], 84, "spec worked example");
    Test.assertEqualMessage(r[:overrideFired], false, "no override at delta 0");
    Test.assertEqualMessage(r[:rhrChecked], true, "rhr was present");
    return true;
}

(:test)
function noBodyBatteryMeansNoScore(logger as Test.Logger) as Lang.Boolean {
    // ADR 0005: Body Battery is load-bearing, not merely weighted
    Test.assertEqualMessage(Readiness.compute(null, 73, 89, 0), null, "no BB, no score");
    return true;
}

(:test)
function missingRecoveryRenormalises(logger as Test.Logger) as Lang.Boolean {
    // Weights become 50/70 and 20/70.
    // (80*0.5 + 60*0.2) / 0.7 = 52 / 0.7 = 74.285... -> 74
    // The expected value is a LITERAL. Recomputing it with the same
    // arithmetic the implementation uses would make this test tautological:
    // it would pass even if the formula were wrong.
    var r = Readiness.compute(80, null, 60, 0);
    Test.assertEqualMessage(r[:score], 74, "renormalised to 50/70 and 20/70");
    return true;
}

(:test)
function missingRhrRenormalisesAndDisablesOverride(logger as Test.Logger) as Lang.Boolean {
    // Weights become 50/80 and 30/80; override cannot run.
    // (80*0.5 + 60*0.3) / 0.8 = 58 / 0.8 = 72.5 -> 73 (rounds up, not 72)
    var r = Readiness.compute(80, 60, null, null);
    Test.assertEqualMessage(r[:score], 73, "renormalised to 50/80 and 30/80");
    Test.assertEqualMessage(r[:rhrChecked], false, "override could not run");
    Test.assertEqualMessage(r[:overrideFired], false, "override did not fire");
    return true;
}

(:test)
function overrideCapsAtGoEasy(logger as Test.Logger) as Lang.Boolean {
    // The case ADR 0004 exists for: high BB masking an elevated RHR
    var r = Readiness.compute(85, 90, 45, 8);
    Test.assertEqualMessage(r[:score], 59, "+8bpm caps at the GO EASY ceiling");
    Test.assertEqualMessage(r[:overrideFired], true, "override fired");
    return true;
}

(:test)
function overrideCapsAtRest(logger as Test.Logger) as Lang.Boolean {
    var r = Readiness.compute(85, 90, 20, 12);
    Test.assertEqualMessage(r[:score], 39, "+12bpm caps at the REST ceiling");
    Test.assertEqualMessage(r[:overrideFired], true, "override fired");
    return true;
}

(:test)
function overrideNeverRaisesAScore(logger as Test.Logger) as Lang.Boolean {
    // A cap is a ceiling, not an assignment
    var r = Readiness.compute(20, 20, 20, 8);
    Test.assertMessage(r[:score] < 59, "already below the ceiling, unchanged");
    return true;
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test`
Expected: FAIL — `Readiness` undefined.

- [ ] **Step 3: Implement**

Create `source/score/Readiness.mc`:

```monkeyc
using Toybox.Lang;

module Readiness {

    // Returns null when Body Battery is absent (ADR 0005) — without it,
    // half the weight and the whole HRV/sleep/stress signal are gone, so
    // what remains is a different measurement, not a degraded one.
    function compute(
        body as Lang.Number?,
        recovery as Lang.Number?,
        rhr as Lang.Number?,
        rhrDeltaBpm as Lang.Number?
    ) as Lang.Dictionary? {

        if (body == null) { return null; }

        var wBody     = Constants.WEIGHT_BODY;
        var wRecovery = (recovery == null) ? 0 : Constants.WEIGHT_RECOVERY;
        var wRhr      = (rhr == null)      ? 0 : Constants.WEIGHT_RHR;

        var total = wBody + wRecovery + wRhr;

        var sum = body * wBody;
        if (recovery != null) { sum += recovery * wRecovery; }
        if (rhr != null)      { sum += rhr * wRhr; }

        // Integer arithmetic end to end. floor((2*sum + total) / (2*total))
        // is exact round-half-up with no floating point anywhere.
        //
        // Do NOT reintroduce floats here. Weighting in float and adding 0.5
        // looks equivalent and is not: 0.5f + 0.3f evaluates to
        // 0.800000011920929, so in the RHR-absent branch an exact .5 tie
        // lands just below the boundary and truncates DOWN. A sweep of all
        // 1,030,301 input combinations found 139 such cases, 20 of which
        // cross a Status Band threshold — e.g. compute(58, 62, null, null)
        // is exactly 59.5 and must be 60 (READY), not 59 (GO EASY).
        //
        // sum peaks at 100*50 + 100*30 + 100*20 = 10000, so 2*sum is far
        // inside 32-bit range. All values are non-negative, so Monkey C's
        // truncating integer division is floor().
        var score = (2 * sum + total) / (2 * total);

        // The override is a tripwire, not a slider (ADR 0004). It can only
        // lower a score, and only when RHR was actually measured (ADR 0005).
        var rhrChecked = (rhr != null && rhrDeltaBpm != null);
        var overrideFired = false;

        if (rhrChecked) {
            if (rhrDeltaBpm >= Constants.RHR_CAP_REST_BPM && score > Constants.CAP_REST_CEILING) {
                score = Constants.CAP_REST_CEILING;
                overrideFired = true;
            } else if (rhrDeltaBpm >= Constants.RHR_CAP_EASY_BPM && score > Constants.CAP_EASY_CEILING) {
                score = Constants.CAP_EASY_CEILING;
                overrideFired = true;
            }
        }

        return {
            :score => score,
            :overrideFired => overrideFired,
            :rhrChecked => rhrChecked
        };
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: all seven PASS.

- [ ] **Step 5: Commit**

```bash
git add source/score/Readiness.mc tests/ReadinessTest.mc
git commit -m "feat: readiness score with renormalisation and rhr override"
```

---

## Task 5: Daily Record and the store

One Storage key holding an array, evicted oldest-first at 120. Keyed by device-local date.

**Files:**
- Create: `source/store/DailyRecord.mc`, `source/store/RecordStore.mc`, `tests/RecordStoreTest.mc`

**Interfaces:**
- Consumes: `Constants.MAX_RECORDS`, `Constants.STORAGE_KEY`
- Produces:
  - `DailyRecord.make(dayKey as Lang.Number, score as Lang.Number, body as Lang.Number, recovery as Lang.Number?, rhr as Lang.Number?, overrideFired as Lang.Boolean) as Lang.Dictionary`
  - `DailyRecord.dayKeyFor(moment as Time.Moment) as Lang.Number` — device-local `YYYYMMDD`
  - `RecordStore.all() as Lang.Array`, `RecordStore.put(record as Lang.Dictionary) as Void`, `RecordStore.latest() as Lang.Dictionary?`, `RecordStore.hasRecordFor(dayKey as Lang.Number) as Lang.Boolean`, `RecordStore.clear() as Void`

- [ ] **Step 1: Write the failing tests**

Create `tests/RecordStoreTest.mc`:

```monkeyc
using Toybox.Test;
using Toybox.Lang;

function makeTestRecord(dayKey as Lang.Number, score as Lang.Number) as Lang.Dictionary {
    return DailyRecord.make(dayKey, score, 88, 73, 89, false);
}

(:test)
function writeThenReadBack(logger as Test.Logger) as Lang.Boolean {
    RecordStore.clear();
    RecordStore.put(makeTestRecord(20260726, 84));
    var latest = RecordStore.latest();
    Test.assertEqualMessage(latest[:score], 84, "score round-trips");
    Test.assertEqualMessage(latest[:day], 20260726, "day key round-trips");
    return true;
}

(:test)
function hasRecordForToday(logger as Test.Logger) as Lang.Boolean {
    RecordStore.clear();
    RecordStore.put(makeTestRecord(20260726, 84));
    Test.assertMessage(RecordStore.hasRecordFor(20260726), "finds today");
    Test.assertMessage(!RecordStore.hasRecordFor(20260727), "does not find tomorrow");
    return true;
}

(:test)
function emptyStoreHasNoLatest(logger as Test.Logger) as Lang.Boolean {
    RecordStore.clear();
    Test.assertEqualMessage(RecordStore.latest(), null, "empty store returns null");
    Test.assertEqualMessage(RecordStore.all().size(), 0, "empty store is empty");
    return true;
}

(:test)
function evictsBeyondMaxRecords(logger as Test.Logger) as Lang.Boolean {
    RecordStore.clear();
    for (var i = 0; i < Constants.MAX_RECORDS + 10; i += 1) {
        RecordStore.put(makeTestRecord(20260000 + i, 50));
    }
    Test.assertEqualMessage(RecordStore.all().size(), Constants.MAX_RECORDS,
        "capped at MAX_RECORDS");
    var oldest = RecordStore.all()[0];
    Test.assertEqualMessage(oldest[:day], 20260000 + 10,
        "the ten oldest were evicted, not the newest");
    return true;
}

(:test)
function sameDayReplacesRatherThanDuplicates(logger as Test.Logger) as Lang.Boolean {
    RecordStore.clear();
    RecordStore.put(makeTestRecord(20260726, 84));
    RecordStore.put(makeTestRecord(20260726, 60));
    Test.assertEqualMessage(RecordStore.all().size(), 1, "one record per day");
    Test.assertEqualMessage(RecordStore.latest()[:score], 60, "later write wins");
    return true;
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test`
Expected: FAIL — `DailyRecord` / `RecordStore` undefined.

- [ ] **Step 3: Implement DailyRecord**

Create `source/store/DailyRecord.mc`:

```monkeyc
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

module DailyRecord {

    // Device-local date as YYYYMMDD (ADR 0006). Guard and storage key use the
    // same function, so they can never disagree about which day it is.
    function dayKeyFor(moment as Time.Moment) as Lang.Number {
        var info = Gregorian.info(moment, Time.FORMAT_SHORT);
        return info.year * 10000 + info.month * 100 + info.day;
    }

    function today() as Lang.Number {
        return dayKeyFor(Time.now());
    }

    function make(
        dayKey as Lang.Number,
        score as Lang.Number,
        body as Lang.Number,
        recovery as Lang.Number?,
        rhr as Lang.Number?,
        overrideFired as Lang.Boolean
    ) as Lang.Dictionary {
        return {
            :day => dayKey,
            :score => score,
            :body => body,
            :recovery => recovery,
            :rhr => rhr,
            :overrideFired => overrideFired
        };
    }
}
```

- [ ] **Step 4: Implement RecordStore**

Create `source/store/RecordStore.mc`:

```monkeyc
using Toybox.Application;
using Toybox.Lang;

// One Storage key holding an array, oldest first (ADR 0006). Values cap at
// 32 KB; 120 records at ~25 bytes is ~3 KB, comfortably inside one value.
module RecordStore {

    function all() as Lang.Array {
        var stored = Application.Storage.getValue(Constants.STORAGE_KEY);
        if (stored == null) { return []; }
        return stored as Lang.Array;
    }

    function save(records as Lang.Array) as Void {
        Application.Storage.setValue(Constants.STORAGE_KEY, records);
    }

    function clear() as Void {
        Application.Storage.setValue(Constants.STORAGE_KEY, []);
    }

    function hasRecordFor(dayKey as Lang.Number) as Lang.Boolean {
        var records = all();
        for (var i = 0; i < records.size(); i += 1) {
            if (records[i][:day] == dayKey) { return true; }
        }
        return false;
    }

    function latest() as Lang.Dictionary? {
        var records = all();
        if (records.size() == 0) { return null; }
        return records[records.size() - 1];
    }

    // Inserts in day order rather than appending. Appending would be correct
    // only while the local date never moves backward — but ADR 0006 explicitly
    // accepts a wearer crossing a timezone, which can do exactly that. An
    // out-of-order array makes latest() return a stale record as current, and
    // latest() is what decides whether the screen shows a band colour or the
    // greyed stale state.
    function put(record as Lang.Dictionary) as Void {
        var records = all();
        var out = [];
        var inserted = false;

        for (var i = 0; i < records.size(); i += 1) {
            // One record per day: a rewrite of the same day replaces it
            if (records[i][:day] == record[:day]) { continue; }

            if (!inserted && records[i][:day] > record[:day]) {
                out.add(record);
                inserted = true;
            }
            out.add(records[i]);
        }
        if (!inserted) { out.add(record); }

        // Evict oldest-first
        while (out.size() > Constants.MAX_RECORDS) {
            out = out.slice(1, out.size());
        }

        save(out);
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: all five PASS.

- [ ] **Step 6: Commit**

```bash
git add source/store tests/RecordStoreTest.mc
git commit -m "feat: daily record store with oldest-first eviction"
```

---

## Task 6: Sensor reads and the Capture

Reads the three inputs, resolving Body Battery **back to wake time** (ADR 0013) rather than using the current value. Sensor access is behind a small seam so the capture logic stays testable.

**Files:**
- Create: `source/capture/Sensors.mc`, `source/capture/Capture.mc`, `tests/CaptureTest.mc`

**Interfaces:**
- Consumes: `Components`, `Readiness`, `DailyRecord`, `RecordStore`
- Produces:
  - `Sensors.bodyBatteryAtWake() as Lang.Number?` — null when history does not reach wake
  - `Sensors.bodyBatteryNow() as Lang.Number?`
  - `Sensors.recoveryHours() as Lang.Number?`
  - `Sensors.rhr() as Lang.Number?`, `Sensors.rhrBaseline() as Lang.Number?`
  - `Capture.buildRecord(bb as Lang.Number?, hours as Lang.Number?, rhr as Lang.Number?, baseline as Lang.Number?, dayKey as Lang.Number) as Lang.Dictionary?`
  - `Capture.run() as Lang.Boolean` — true if a record was written

- [ ] **Step 1: Write the failing tests**

Create `tests/CaptureTest.mc`:

```monkeyc
using Toybox.Test;
using Toybox.Lang;

(:test)
function buildsARecordFromRawInputs(logger as Test.Logger) as Lang.Boolean {
    // 88 BB, 24h recovery -> 50, rhr 50 vs baseline 50 -> 100
    // 0.50*88 + 0.30*50 + 0.20*100 = 44 + 15 + 20 = 79
    var record = Capture.buildRecord(88, 24, 50, 50, 20260726);
    Test.assertEqualMessage(record[:score], 79, "score from raw inputs");
    Test.assertEqualMessage(record[:day], 20260726, "carries the day key");
    Test.assertEqualMessage(record[:body], 88, "stores the body component");
    return true;
}

(:test)
function noBodyBatteryBuildsNoRecord(logger as Test.Logger) as Lang.Boolean {
    // ADR 0013: history no longer reaching wake yields null, and null means no record
    Test.assertEqualMessage(Capture.buildRecord(null, 24, 50, 50, 20260726), null,
        "no BB at wake, no record");
    return true;
}

(:test)
function recoveryZeroStillBuildsARecord(logger as Test.Logger) as Lang.Boolean {
    // The rest-day case: 0 hours is fully recovered, not missing
    var record = Capture.buildRecord(90, 0, 50, 50, 20260726);
    Test.assertMessage(record != null, "0h recovery is valid input");
    // 0.50*90 + 0.30*100 + 0.20*100 = 45 + 30 + 20 = 95
    Test.assertEqualMessage(record[:score], 95, "rest day scores high");
    return true;
}

(:test)
function overrideIsRecordedOnTheRecord(logger as Test.Logger) as Lang.Boolean {
    // rhr 58 vs baseline 50 = +8bpm -> caps at 59
    var record = Capture.buildRecord(85, 0, 58, 50, 20260726);
    Test.assertEqualMessage(record[:score], 59, "override capped the score");
    Test.assertEqualMessage(record[:overrideFired], true, "flag persisted");
    return true;
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test`
Expected: FAIL — `Capture` undefined.

- [ ] **Step 3: Implement Sensors**

Create `source/capture/Sensors.mc`:

```monkeyc
using Toybox.ActivityMonitor;
using Toybox.Lang;
using Toybox.SensorHistory;
using Toybox.System;
using Toybox.Time;
using Toybox.UserProfile;

module Sensors {

    // ADR 0013: the Capture fires up to 30 minutes after waking, but Body
    // Battery drains from the moment you are up. Reading the current value
    // would bias every Morning Score low by a VARYING amount, making scores
    // incomparable across days. So walk back to the sample at wake.
    //
    // Buffer depth is undocumented but interrogable — if it no longer reaches
    // wake, return null and let the caller decline to score.
    function bodyBatteryAtWake() as Lang.Number? {
        var profile = UserProfile.getProfile();
        if (profile == null || profile.wakeTime == null) { return null; }

        var wakeMoment = Time.today().add(profile.wakeTime);

        // ORDER_OLDEST_FIRST is load-bearing, not stylistic. The walk below
        // returns the FIRST sample at or after wake. Garmin's default is
        // ORDER_NEWEST_FIRST, under which the very first sample is "now" —
        // which trivially satisfies that test and would return the current
        // value, collapsing this function into bodyBatteryNow() and silently
        // destroying the at-wake resolution the whole function exists for.
        var iter = SensorHistory.getBodyBatteryHistory({
            :order => SensorHistory.ORDER_OLDEST_FIRST
        });
        if (iter == null) { return null; }

        var oldest = iter.getOldestSampleTime();
        if (oldest == null || oldest.greaterThan(wakeMoment)) {
            return null; // buffer no longer covers wake
        }

        var sample = iter.next();
        while (sample != null) {
            if (sample.data != null && !sample.when.lessThan(wakeMoment)) {
                return sample.data.toNumber();
            }
            sample = iter.next();
        }
        return null;
    }

    // The Now Score deliberately uses the CURRENT value, not the at-wake one.
    // Reusing bodyBatteryAtWake() here would make the Now Score identical to
    // the Morning Score and defeat ADR 0010 entirely.
    function bodyBatteryNow() as Lang.Number? {
        // NEWEST_FIRST stated explicitly rather than left to the default, so
        // the contrast with bodyBatteryAtWake is visible at both call sites.
        var iter = SensorHistory.getBodyBatteryHistory({
            :order => SensorHistory.ORDER_NEWEST_FIRST
        });
        if (iter == null) { return null; }
        var newest = iter.next();
        if (newest == null || newest.data == null) { return null; }
        return newest.data.toNumber();
    }

    function recoveryHours() as Lang.Number? {
        var info = ActivityMonitor.getInfo();
        if (info == null) { return null; }
        if (!(info has :timeToRecovery)) { return null; }
        return info.timeToRecovery; // may legitimately be 0 = fully recovered
    }

    function rhr() as Lang.Number? {
        var profile = UserProfile.getProfile();
        if (profile == null) { return null; }
        return profile.restingHeartRate;
    }

    function rhrBaseline() as Lang.Number? {
        var profile = UserProfile.getProfile();
        if (profile == null) { return null; }
        if (!(profile has :averageRestingHeartRate)) { return null; }
        return profile.averageRestingHeartRate;
    }
}
```

- [ ] **Step 4: Implement Capture**

Create `source/capture/Capture.mc`:

```monkeyc
using Toybox.Lang;

module Capture {

    // Pure: raw inputs -> a record, or null. Kept separate from run() so the
    // whole scoring path is testable without a device.
    function buildRecord(
        bb as Lang.Number?,
        hours as Lang.Number?,
        rhrValue as Lang.Number?,
        baseline as Lang.Number?,
        dayKey as Lang.Number
    ) as Lang.Dictionary? {

        var cBody     = Components.fromBodyBattery(bb);
        var cRecovery = Components.fromRecoveryHours(hours);
        var cRhr      = Components.fromRhr(rhrValue, baseline);

        var delta = null;
        if (rhrValue != null && baseline != null) {
            delta = rhrValue - baseline;
        }

        var result = Readiness.compute(cBody, cRecovery, cRhr, delta);
        if (result == null) { return null; }

        return DailyRecord.make(
            dayKey,
            result[:score],
            cBody,
            cRecovery,
            cRhr,
            result[:overrideFired]
        );
    }

    // Idempotent per day (ADR 0012/0015): safe to call from the temporal
    // event AND from app launch. Returns true if a record was written.
    function run() as Lang.Boolean {
        var dayKey = DailyRecord.today();

        if (RecordStore.hasRecordFor(dayKey)) { return false; }

        var record = buildRecord(
            Sensors.bodyBatteryAtWake(),
            Sensors.recoveryHours(),
            Sensors.rhr(),
            Sensors.rhrBaseline(),
            dayKey
        );

        if (record == null) { return false; }

        RecordStore.put(record);
        return true;
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: all four PASS.

- [ ] **Step 6: Commit**

```bash
git add source/capture tests/CaptureTest.mc
git commit -m "feat: capture with body battery resolved at wake"
```

---

## Task 7: Background service and temporal event

**Files:**
- Create: `source/capture/BackgroundService.mc`
- Modify: `source/SPReadyNessApp.mc`

**Interfaces:**
- Consumes: `Capture.run()`, `Constants.CAPTURE_INTERVAL_MINUTES`
- Produces: `SPReadyNessApp.getServiceDelegate()`, `SPReadyNessApp.onBackgroundData(data)`

- [ ] **Step 1: Implement the service delegate**

Create `source/capture/BackgroundService.mc`:

```monkeyc
using Toybox.Background;
using Toybox.Lang;
using Toybox.System;

(:background)
class BackgroundService extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    // Guarded so almost every firing costs two comparisons and an exit
    // (ADR 0012). Only the first firing after wake does real work.
    function onTemporalEvent() as Void {
        var wrote = Capture.run();
        if (wrote) {
            var latest = RecordStore.latest();
            // Payload is a refresh nudge for a running app, NOT a second
            // persistence path — the record is already in Storage.
            Background.exit({ :score => latest[:score] });
        } else {
            Background.exit(null);
        }
    }
}
```

- [ ] **Step 2: Wire registration into the app**

Replace `source/SPReadyNessApp.mc` with:

```monkeyc
using Toybox.Application;
using Toybox.Background;
using Toybox.Lang;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi;

class SPReadyNessApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Lang.Dictionary?) as Void {
        registerCapture();
        // ADR 0015: do not wait for the scheduled event. A fresh install at
        // 09:00 usually still has history reaching a 06:30 wake, so this
        // produces a real Morning Score at once and the empty state is
        // never seen. Idempotent per day, so racing the event is harmless.
        Capture.run();
    }

    function registerCapture() as Void {
        // Only one temporal event may exist; this overwrites any previous one.
        var interval = new Time.Duration(Constants.CAPTURE_INTERVAL_MINUTES * 60);
        Background.registerForTemporalEvent(interval);
    }

    function getServiceDelegate() as Lang.Array<System.ServiceDelegate> {
        return [ new BackgroundService() ] as Lang.Array<System.ServiceDelegate>;
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        WatchUi.requestUpdate();
    }

    function getInitialView() as Lang.Array<WatchUi.Views or WatchUi.InputDelegates>? {
        // Placeholder until Task 13 swaps in MorningView + PageDelegate.
        // Keeping a real View here means the tree compiles at every commit.
        return [ new WatchUi.View() ] as Lang.Array<WatchUi.Views>;
    }
}
```

**The tree must compile at every commit.** `getInitialView` keeps returning a plain
`WatchUi.View` until Task 13 has both `MorningView` and `PageDelegate` to swap in.
Do not reference either class before then.

- [ ] **Step 3: Commit**

```bash
git add source/capture/BackgroundService.mc source/SPReadyNessApp.mc
git commit -m "feat: background service on a guarded 30-minute temporal event"
```

---

## Task 8: Display state selection

Pure logic deciding which of the three states a view should draw. Extracting this is what makes the UI testable.

**Files:**
- Create: `source/ui/DisplayState.mc`, `tests/DisplayStateTest.mc`

**Interfaces:**
- Produces: `DisplayState.forRecord(record as Lang.Dictionary?, todayKey as Lang.Number) as Lang.Dictionary` returning `{ :kind => EMPTY|CURRENT|STALE|UNCHECKED, :record => Dictionary?, :ageDays => Number? }`

- [ ] **Step 1: Write the failing tests**

Create `tests/DisplayStateTest.mc`:

```monkeyc
using Toybox.Test;
using Toybox.Lang;

(:test)
function noRecordEverIsEmpty(logger as Test.Logger) as Lang.Boolean {
    // ADR 0015: distinct from stale — there is no number to dim
    var state = DisplayState.forRecord(null, 20260726);
    Test.assertEqualMessage(state[:kind], DisplayState.EMPTY, "empty, not stale");
    return true;
}

(:test)
function todaysRecordIsCurrent(logger as Test.Logger) as Lang.Boolean {
    var record = DailyRecord.make(20260726, 84, 88, 73, 89, false);
    var state = DisplayState.forRecord(record, 20260726);
    Test.assertEqualMessage(state[:kind], DisplayState.CURRENT, "today is current");
    return true;
}

(:test)
function olderRecordIsStaleWithAge(logger as Test.Logger) as Lang.Boolean {
    var record = DailyRecord.make(20260724, 84, 88, 73, 89, false);
    var state = DisplayState.forRecord(record, 20260726);
    Test.assertEqualMessage(state[:kind], DisplayState.STALE, "older is stale");
    Test.assertEqualMessage(state[:ageDays], 2, "two days old");
    return true;
}

(:test)
function ageCrossesMonthAndYearBoundaries(logger as Test.Logger) as Lang.Boolean {
    // A month is not 30 days. 1 March is ONE day after 28 February in a
    // non-leap year, and 1 January is ONE day after 31 December.
    var feb = DailyRecord.make(20260228, 84, 88, 73, 89, false);
    Test.assertEqualMessage(DisplayState.forRecord(feb, 20260301)[:ageDays], 1,
        "28 Feb to 1 Mar is one day");

    var dec = DailyRecord.make(20251231, 84, 88, 73, 89, false);
    Test.assertEqualMessage(DisplayState.forRecord(dec, 20260101)[:ageDays], 1,
        "31 Dec to 1 Jan is one day");

    var leap = DailyRecord.make(20240228, 84, 88, 73, 89, false);
    Test.assertEqualMessage(DisplayState.forRecord(leap, 20240301)[:ageDays], 2,
        "2024 is a leap year, so 28 Feb to 1 Mar is two days");
    return true;
}

(:test)
function todaysRecordWithoutRhrIsUnchecked(logger as Test.Logger) as Lang.Boolean {
    // ADR 0005: the override could not run, so the score carries no colour
    var record = DailyRecord.make(20260726, 72, 80, 60, null, false);
    var state = DisplayState.forRecord(record, 20260726);
    Test.assertEqualMessage(state[:kind], DisplayState.UNCHECKED, "no rhr = unchecked");
    return true;
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test`
Expected: FAIL — `DisplayState` undefined.

- [ ] **Step 3: Implement**

Create `source/ui/DisplayState.mc`:

```monkeyc
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

module DisplayState {
    enum {
        EMPTY = 0,      // nothing ever captured — no number at all (ADR 0015)
        CURRENT = 1,    // today's score, full band colour
        STALE = 2,      // older score, dimmed, age shown (ADR 0009)
        UNCHECKED = 3   // today's score but RHR absent, dimmed (ADR 0005)
    }

    // Seconds in a day. A unit definition, not a tunable — unlike the five
    // formula constants, this one has exactly one correct value.
    const SECONDS_PER_DAY = 86400;

    // A YYYYMMDD key back to a Moment. Gregorian.moment treats its fields as
    // UTC, which is correct here: both sides of the subtraction use the same
    // frame, so the offset cancels.
    function momentFor(dayKey as Lang.Number) as Time.Moment {
        return Gregorian.moment({
            :year   => dayKey / 10000,
            :month  => (dayKey / 100) % 100,
            :day    => dayKey % 100,
            :hour   => 0,
            :minute => 0,
            :second => 0
        });
    }

    // Real calendar arithmetic, not an approximation. An earlier version
    // treated a month as 30 days, which made 1 March against 28 February
    // read as 3 days instead of 1 — a visible lie on the stale caption, and
    // wrong across every month boundary and every leap year.
    //
    // Rounds to the nearest day rather than truncating. Whether
    // Gregorian.moment resolves its fields as UTC or device-local is not
    // documented; if local, a DST transition inside the interval makes
    // elapsed 23 or 25 hours instead of a clean multiple of 86400, and
    // truncation would silently drop a whole day from the caption. Rounding
    // absorbs a shift of up to 12 hours, far beyond any DST step in use.
    function ageInDays(recordDay as Lang.Number, todayKey as Lang.Number) as Lang.Number {
        var elapsed = momentFor(todayKey).subtract(momentFor(recordDay));
        return ((elapsed.value() + SECONDS_PER_DAY / 2) / SECONDS_PER_DAY).toNumber();
    }

    function forRecord(record as Lang.Dictionary?, todayKey as Lang.Number) as Lang.Dictionary {
        if (record == null) {
            return { :kind => EMPTY, :record => null, :ageDays => null };
        }

        if (record[:day] != todayKey) {
            return {
                :kind => STALE,
                :record => record,
                :ageDays => ageInDays(record[:day], todayKey)
            };
        }

        if (record[:rhr] == null) {
            return { :kind => UNCHECKED, :record => record, :ageDays => 0 };
        }

        return { :kind => CURRENT, :record => record, :ageDays => 0 };
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: all four PASS.

- [ ] **Step 5: Commit**

```bash
git add source/ui/DisplayState.mc tests/DisplayStateTest.mc
git commit -m "feat: display state selection for the three score states"
```

---

## Task 9: Theme and drawing primitives

**Files:**
- Create: `source/ui/Theme.mc`, `source/ui/Draw.mc`

**Interfaces:**
- Produces: `Theme.BACKGROUND`, `Theme.PRIMARY_TEXT`, `Theme.SECONDARY_TEXT`, `Theme.TRACK`, `Theme.DIM_TRACK`; `Draw.scoreArc(dc, score, colour, dimmed, dashed)`, `Draw.componentDial(dc, x, y, value, colour, dimmed, caption)`

- [ ] **Step 1: Write the theme**

Create `source/ui/Theme.mc`:

```monkeyc
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
```

- [ ] **Step 2: Write the drawing primitives**

Create `source/ui/Draw.mc`:

```monkeyc
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
            dc.drawArc(x, y, Theme.DIAL_RADIUS, Graphics.ARC_CLOCKWISE,
                       90, 90 - (360 * value / 100));
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
```

- [ ] **Step 3: Commit**

```bash
git add source/ui/Theme.mc source/ui/Draw.mc
git commit -m "feat: theme tokens and arc/dial drawing primitives"
```

---

## Task 10: Morning Score view — all three states

**Files:**
- Create: `source/ui/MorningView.mc`

**Interfaces:**
- Consumes: `DisplayState`, `Draw`, `Theme`, `StatusBand`, `RecordStore`, `DailyRecord`
- Produces: `class MorningView extends WatchUi.View`

- [ ] **Step 1: Implement the view**

Create `source/ui/MorningView.mc`:

```monkeyc
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
            Draw.componentDial(dc, dials[i][0], y, value, colour, !current, dials[i][2]);
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add source/ui/MorningView.mc
git commit -m "feat: morning score view with current, stale and empty states"
```

---

## Task 11: Now Score view

**Files:**
- Create: `source/ui/NowView.mc`

**Interfaces:**
- Consumes: `Sensors`, `Components`, `Readiness`, `Draw`, `Theme`, `StatusBand`
- Produces: `class NowView extends WatchUi.View`

- [ ] **Step 1: Implement the view**

Create `source/ui/NowView.mc`:

```monkeyc
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
```

- [ ] **Step 2: Commit**

```bash
git add source/ui/NowView.mc
git commit -m "feat: now score view with dashed arc and timestamp"
```

---

## Task 12: Glance view

**Files:**
- Create: `source/ui/SPReadyNessGlanceView.mc`
- Modify: `source/SPReadyNessApp.mc`

**Interfaces:**
- Produces: `class SPReadyNessGlanceView extends WatchUi.GlanceView`; `SPReadyNessApp.getGlanceView()`

- [ ] **Step 1: Implement the glance**

Create `source/ui/SPReadyNessGlanceView.mc`:

```monkeyc
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
```

- [ ] **Step 2: Register the glance in the app**

Add to `source/SPReadyNessApp.mc`, inside the class:

```monkeyc
    function getGlanceView() as Lang.Array<WatchUi.GlanceView>? {
        return [ new SPReadyNessGlanceView() ] as Lang.Array<WatchUi.GlanceView>;
    }
```

Add the glance annotation to `manifest.xml`'s `<iq:application>` element by ensuring the app type supports it — `type="watch-app"` with a `(:glance)` view requires no manifest change on API 3.3+, but confirm the SDK does not warn.

- [ ] **Step 3: Commit**

```bash
git add source/ui/SPReadyNessGlanceView.mc source/SPReadyNessApp.mc
git commit -m "feat: glance card showing the morning score"
```

---

## Task 13: Paging, full build, and simulator verification

Closes the compile gap left by Task 7 and verifies the whole app against the approved mockup.

**Files:**
- Create: `source/PageDelegate.mc`

**Interfaces:**
- Consumes: `MorningView`, `NowView`
- Produces: `class PageDelegate extends WatchUi.BehaviorDelegate`

- [ ] **Step 1: Swap the placeholder view for the real one**

In `source/SPReadyNessApp.mc`, replace the placeholder `getInitialView` body left by
Task 7 with:

```monkeyc
    function getInitialView() as Lang.Array<WatchUi.Views or WatchUi.InputDelegates>? {
        return [ new MorningView(), new PageDelegate() ]
            as Lang.Array<WatchUi.Views or WatchUi.InputDelegates>;
    }
```

- [ ] **Step 2: Implement paging**

Create `source/PageDelegate.mc`:

```monkeyc
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
```

- [ ] **Step 3: Build the app**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/spreadyness.prg -y developer_key.der`
Expected: build succeeds with no errors.

- [ ] **Step 4: Run the full test suite**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: all tests from Tasks 2–8 PASS.

- [ ] **Step 5: Verify against the mockup in the simulator**

Run:

```bash
connectiq &
monkeydo bin/spreadyness.prg fr165
```

In the simulator, check each against [the approved mockup](../../mockups/screens.html):

- Fresh install (Simulation → Reset app data) shows **no number** and `FIRST SCORE / TOMORROW MORNING` — never a zero.
- With today's record: solid arc, band-coloured score, three dials.
- Page down: dashed arc, `NOW hh:mm`, and a score that may legitimately differ.
- Background is pure black in every state.

- [ ] **Step 6: Commit**

```bash
git add source/PageDelegate.mc source/SPReadyNessApp.mc
git commit -m "feat: page navigation and full app build"
```

---

## Self-Review

**Spec coverage.** Every spec section maps to a task: the formula and bands → Tasks 2–4; missing-input branches → Task 4; Capture and the at-wake resolution → Task 6; the guarded schedule → Task 7; the store, layout and day key → Task 5; the three display states → Tasks 8, 10; the three surfaces → Tasks 10–12; the launch-triggered Capture → Task 7 Step 2. The spec's six required test cases are all present in Tasks 3–8.

**Deferred by design, not omission:** the 7-day, 30-day and 8-week screens (ADR 0011). The store that feeds them is built and tested in Task 5.

**Known open items carried from the spec** — these are *verification* tasks for a real device, not plan gaps:

1. Background process memory ceiling — if the Capture exceeds it, move sensor reads into fewer locals.
2. Glance memory ceiling — the glance draws a bar and reads the store; if it exceeds, cache the latest score in a separate small Storage key.
3. Total Object Store budget.
4. `averageRestingHeartRate` window and `restingHeartRate` freshness — both affect override calibration, not correctness.
5. `Profile.wakeTime` return type — Task 6 assumes it is a `Time.Duration` addable to `Time.today()`. **If the build fails at `Time.today().add(profile.wakeTime)`, this is why**; adjust the conversion and keep the rest.
6. `monkeyc --unit-test` / `monkeydo -t` flags are from community sources; Garmin's own pages would not load. If they differ in your SDK, run `monkeyc --help`.

**Type consistency.** `Lang.Dictionary` keys are symbols throughout (`:score`, `:day`, `:body`, `:recovery`, `:rhr`, `:overrideFired`). `Components.*` and `Readiness.compute` return `null` rather than a sentinel. `StatusBand.of` takes a score and returns a band; `colourOf`/`nameOf` take a band — never mixed.

**Placeholder scan.** No TBDs. Every code step carries real code. The one intentional forward reference is Task 7's `MorningView`/`PageDelegate`, called out inline and closed in Task 13.
