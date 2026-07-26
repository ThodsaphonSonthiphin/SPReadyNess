# RHR Data Source Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `Sensors.rhr()`'s data source (currently `UserProfile.Profile.restingHeartRate`, confirmed `null` indefinitely on real hardware) with a value derived from raw `SensorHistory.getHeartRateHistory()` samples, and let `NowView` reuse that stored value later in the day instead of re-deriving it live.

**Architecture:** Bottom-up: extend the `DailyRecord` in-memory shape with one new raw field, extend `RecordStore`'s storage boundary to persist it, add the new sensor-read function and wire it into `Capture`, then update `NowView` to consume the stored value instead of a live sensor read. `Sensors.rhrBaseline()`, the override formula, the weights, and all display logic are untouched — see spec's Scope section.

**Tech Stack:** Monkey C, Connect IQ SDK 9.2.0, `monkeyc`/`monkeydo` unit-test harness, `Toybox.SensorHistory`/`Toybox.UserProfile`.

## Global Constraints

- **Design spec:** `docs/superpowers/specs/2026-07-26-rhr-datasource-redesign-design.md`. ADRs: 0016 (accepted), 0017 (rejected, historical), 0018 (accepted, revised).
- **Out of scope — do not touch:** `Sensors.rhrBaseline()`, `Components.fromRhr()`, `Readiness.compute()`, the override thresholds/weights in `Constants.mc`, `DisplayState.mc`, `MorningView.mc`, `SPReadyNessGlanceView.mc`. None of these change in this plan.
- **Backward compatibility:** `RecordStore.fromStorable` must keep returning `null` for a missing dictionary key rather than throwing (existing behavior) — a pre-redesign stored record has no `:rhrBpm`, and that must degrade to "RHR absent," not a crash.
- **SDK on PATH:** this machine's SDK is at `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-*/bin` — resolve the exact versioned path with `ls` (don't hardcode the version) and `export PATH="$SDK_DIR/bin:/opt/homebrew/opt/openjdk@17/bin:$PATH"` inline in every command; it is not on PATH by default in a non-interactive shell.
- **Simulator must be running** before any `monkeydo` call, including `--unit-test` runs, or they fail with `Unable to connect to simulator` (not a build error): `connectiq &`, wait a few seconds.
- **`monkeydo <prg> <device> -t`'s exit code is always 1** in this SDK build, pass or fail — parse the `PASSED (...)`/`FAILED (...)` summary line in its stdout instead.
- **`Test.assertEqualMessage`/`Test.assertEqual` crash if the actual value is `null`** (confirmed SDK bug) — assert `expr == null` via `Test.assertMessage` instead.
- Every test file lives in `tests/`, uses `(:test)` tags on `(logger as Test.Logger) as Lang.Boolean` functions, and `monkey.jungle`'s `base.sourcePath = source;tests` already includes them — no jungle changes needed for new tests.
- Build/test commands (run from the repo root, with PATH exported per above):
  - Test binary: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test`
  - Run tests: `monkeydo bin/test.prg fr165 -t` (parse output for `PASSED (`/`FAILED (`)
  - App binary: `monkeyc -f monkey.jungle -d fr165 -o bin/spreadyness.prg -y developer_key.der`

---

### Task 1: `DailyRecord` gains a raw `:rhrBpm` field

**Files:**
- Modify: `source/store/DailyRecord.mc`
- Modify: `source/capture/Capture.mc:30-38` (the `DailyRecord.make(...)` call inside `buildRecord`)
- Modify: `tests/DisplayStateTest.mc` (6 call sites)
- Modify: `tests/RecordStoreTest.mc:8-10` (`makeTestRecord` helper)
- Test: `tests/RecordStoreTest.mc` (new test added in this task)

**Interfaces:**
- Produces: `DailyRecord.make(dayKey as Lang.Number, score as Lang.Number, body as Lang.Number, recovery as Lang.Number?, rhr as Lang.Number?, overrideFired as Lang.Boolean, rhrBpm as Lang.Number?) as Lang.Dictionary` — note the new 7th parameter. The returned dictionary gains key `:rhrBpm`.

- [ ] **Step 1: Write the failing test**

Add to `tests/RecordStoreTest.mc` (after the `writeThenReadBack` test):

```monkeyc
(:test)
function dailyRecordCarriesRawRhrBpm(logger as Test.Logger) as Lang.Boolean {
    var record = DailyRecord.make(20260726, 84, 88, 73, 89, false, 52);
    Test.assertEqualMessage(record[:rhrBpm], 52, "raw rhr bpm is carried on the record");
    return true;
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test`
Expected: FAIL — compile error, too many arguments to `DailyRecord.make`.

- [ ] **Step 3: Update `DailyRecord.mc`**

In `source/store/DailyRecord.mc`, change the `make` function:

```monkeyc
    function make(
        dayKey as Lang.Number,
        score as Lang.Number,
        body as Lang.Number,
        recovery as Lang.Number?,
        rhr as Lang.Number?,
        overrideFired as Lang.Boolean,
        rhrBpm as Lang.Number?
    ) as Lang.Dictionary {
        return {
            :day => dayKey,
            :score => score,
            :body => body,
            :recovery => recovery,
            :rhr => rhr,
            :overrideFired => overrideFired,
            :rhrBpm => rhrBpm
        };
    }
```

- [ ] **Step 4: Update the real caller in `Capture.mc`**

In `source/capture/Capture.mc`, `buildRecord` currently ends with:

```monkeyc
        return DailyRecord.make(
            dayKey,
            result[:score],
            cBody,
            cRecovery,
            cRhr,
            result[:overrideFired]
        );
```

Change to:

```monkeyc
        return DailyRecord.make(
            dayKey,
            result[:score],
            cBody,
            cRecovery,
            cRhr,
            result[:overrideFired],
            rhrValue
        );
```

(`rhrValue` is already a parameter of `buildRecord` — this passes the raw bpm reading through alongside the normalised `cRhr` Component Score, unchanged.)

- [ ] **Step 5: Update the six call sites in `tests/DisplayStateTest.mc`**

None of these tests exercise the new field, so append `null` to each. Every occurrence of `DailyRecord.make(<5 args>, false)` becomes `DailyRecord.make(<same 5 args>, false, null)`. Concretely, these six lines:

```monkeyc
    var record = DailyRecord.make(20260726, 84, 88, 73, 89, false);
```
```monkeyc
    var record = DailyRecord.make(20260724, 84, 88, 73, 89, false);
```
```monkeyc
    var feb = DailyRecord.make(20260228, 84, 88, 73, 89, false);
```
```monkeyc
    var dec = DailyRecord.make(20251231, 84, 88, 73, 89, false);
```
```monkeyc
    var leap = DailyRecord.make(20240228, 84, 88, 73, 89, false);
```
```monkeyc
    var record = DailyRecord.make(20260726, 72, 80, 60, null, false);
```

each get `, null)` in place of their trailing `)`, e.g. the first becomes:

```monkeyc
    var record = DailyRecord.make(20260726, 84, 88, 73, 89, false, null);
```

- [ ] **Step 6: Update `makeTestRecord` in `tests/RecordStoreTest.mc`**

```monkeyc
function makeTestRecord(dayKey as Lang.Number, score as Lang.Number) as Lang.Dictionary {
    return DailyRecord.make(dayKey, score, 88, 73, 89, false, null);
}
```

- [ ] **Step 7: Run to verify all pass**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: `PASSED (passed=35, failed=0, errors=0)` (34 existing + the new test).

- [ ] **Step 8: Commit**

```bash
git add source/store/DailyRecord.mc source/capture/Capture.mc tests/DisplayStateTest.mc tests/RecordStoreTest.mc
git commit -m "feat: DailyRecord carries the raw RHR bpm reading (ADR 0018)"
```

---

### Task 2: `RecordStore` persists `:rhrBpm` through the Storage boundary

**Files:**
- Modify: `source/store/RecordStore.mc` (`toStorable`/`fromStorable`)
- Test: `tests/RecordStoreTest.mc`

**Interfaces:**
- Consumes: `DailyRecord.make(...)` from Task 1 (now returns a dict with `:rhrBpm`).
- Produces: `RecordStore.toStorable`/`fromStorable` now also map `"rhrBpm"` (String key, the `Storage`-safe boundary per the project's existing Symbol↔String translation) — `RecordStore.put`/`all`/`latest` behavior otherwise unchanged.

- [ ] **Step 1: Write the failing tests**

Add to `tests/RecordStoreTest.mc`:

```monkeyc
(:test)
function rhrBpmRoundTripsThroughStorage(logger as Test.Logger) as Lang.Boolean {
    RecordStore.clear();
    RecordStore.put(DailyRecord.make(20260726, 84, 88, 73, 89, false, 52));
    var latest = RecordStore.latest();
    Test.assertEqualMessage(latest[:rhrBpm], 52, "raw rhr bpm round-trips through Storage");
    return true;
}

(:test)
function missingRhrBpmKeyDoesNotThrow(logger as Test.Logger) as Lang.Boolean {
    // Simulates a record stored before this field existed: no "rhrBpm" key
    // at all in the persisted (String-keyed) dictionary.
    var oldStyleStored = {
        "day" => 20260726,
        "score" => 84,
        "body" => 88,
        "recovery" => 73,
        "rhr" => 89,
        "overrideFired" => false
    };
    var record = RecordStore.fromStorable(oldStyleStored);
    Test.assertMessage(record[:rhrBpm] == null,
        "a pre-migration record with no rhrBpm key degrades to null, not a throw");
    return true;
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: `rhrBpmRoundTripsThroughStorage` FAIL — `latest[:rhrBpm]` is `null`, expected `52` (`toStorable`/`fromStorable` don't carry the key yet). `missingRhrBpmKeyDoesNotThrow` PASSes already (a genuinely missing key already returns `null` from `fromStorable`'s current unconditional key-by-key mapping) — that's fine, it's here to pin the behavior so a future change can't regress it silently.

- [ ] **Step 3: Update `RecordStore.mc`**

```monkeyc
    function toStorable(record as Lang.Dictionary) as Lang.Dictionary {
        return {
            "day"           => record[:day],
            "score"         => record[:score],
            "body"          => record[:body],
            "recovery"      => record[:recovery],
            "rhr"           => record[:rhr],
            "overrideFired" => record[:overrideFired],
            "rhrBpm"        => record[:rhrBpm]
        };
    }

    function fromStorable(stored as Lang.Dictionary) as Lang.Dictionary {
        return {
            :day           => stored["day"],
            :score         => stored["score"],
            :body          => stored["body"],
            :recovery      => stored["recovery"],
            :rhr           => stored["rhr"],
            :overrideFired => stored["overrideFired"],
            :rhrBpm        => stored["rhrBpm"]
        };
    }
```

- [ ] **Step 4: Run to verify all pass**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: `PASSED (passed=37, failed=0, errors=0)`.

- [ ] **Step 5: Commit**

```bash
git add source/store/RecordStore.mc tests/RecordStoreTest.mc
git commit -m "feat: persist raw RHR bpm through the Storage boundary, null-safe for old records"
```

---

### Task 3: `Sensors.todaysRhr()` replaces `Sensors.rhr()`, wired into `Capture`

**Files:**
- Modify: `source/capture/Sensors.mc` (remove `rhr()`, add `todaysRhr()`)
- Modify: `source/capture/Capture.mc:84-90` (`run()`'s call site)
- Test: `tests/CaptureTest.mc`

**Interfaces:**
- Consumes: `SensorHistory.getHeartRateHistory({:order => ...}) as SensorHistory.SensorHistoryIterator?` (API 2.1.0+, confirmed available at this device's API level).
- Produces: `Sensors.todaysRhr() as Lang.Number?` — minimum bpm sample among whatever heart-rate history the buffer holds at or before `profile.wakeTime`. Replaces `Sensors.rhr()`, which is deleted (its only two callers, here and `NowView.mc`, are both updated in this plan — Task 4 handles `NowView`).
- **No unit test exists for `Sensors.todaysRhr()` itself** — it needs real `SensorHistory` data, and every other function in `Sensors.mc` (`bodyBatteryAtWake`, `bodyBatteryNow`, `recoveryHours`, `rhrBaseline`) is untested for the same reason (HANDOFF.md: "the entire sensor-read path... cannot be tested without hardware"). This task's testable deliverable is `Capture.buildRecord`'s wiring (below) plus a clean app build.

- [ ] **Step 1: Write the failing test**

Add to `tests/CaptureTest.mc`:

```monkeyc
(:test)
function buildRecordCarriesRawRhrBpm(logger as Test.Logger) as Lang.Boolean {
    var record = Capture.buildRecord(88, 24, 52, 50, 20260726);
    Test.assertEqualMessage(record[:rhrBpm], 52, "buildRecord threads the raw rhr reading onto the record");
    return true;
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: `buildRecordCarriesRawRhrBpm` FAIL — `record[:rhrBpm]` is `null`, expected `52` (`buildRecord` doesn't pass `rhrValue` through yet).

- [ ] **Step 3: Update `Capture.buildRecord`**

In `source/capture/Capture.mc`, `buildRecord` must end with `rhrValue` passed as the 7th arg to `DailyRecord.make` (this is the same change as Task 1 Step 4 — if Task 1 already ran, this is a no-op check, not a second edit):

```monkeyc
        return DailyRecord.make(
            dayKey,
            result[:score],
            cBody,
            cRecovery,
            cRhr,
            result[:overrideFired],
            rhrValue
        );
```

- [ ] **Step 4: Replace `Sensors.rhr()` with `Sensors.todaysRhr()`**

In `source/capture/Sensors.mc`, remove:

```monkeyc
    function rhr() as Lang.Number? {
        var profile = UserProfile.getProfile();
        if (profile == null) { return null; }
        if (!(profile has :restingHeartRate)) { return null; }
        return profile.restingHeartRate;
    }
```

Replace with:

```monkeyc
    // ADR 0016: Profile.restingHeartRate is a user-configured setting that
    // stays null indefinitely for most real users (confirmed on real fr165
    // hardware and Garmin's own bug tracker) — not the watch's auto-computed
    // resting HR. This derives an effective value from raw heart-rate
    // history instead: the minimum bpm sample among whatever the
    // SensorHistory buffer holds at or before wake.
    //
    // Deliberately NOT "strictly from local midnight". Heart rate is
    // sampled far more densely than Body Battery, so a same-capacity buffer
    // likely covers far fewer hours — requiring the walk to reach all the
    // way back to midnight would return null far more often than intended.
    // Whatever the buffer covers, however far back, is used instead: a
    // partial night still captures the low point during rest for most wake
    // times, and more history than expected can only lower or maintain the
    // minimum, never distort it upward.
    //
    // OLDEST_FIRST with an early break the instant a sample is after wake —
    // NOT NEWEST_FIRST with no break (/scrutinize caught this: an unbounded
    // walk over the ENTIRE buffer, run synchronously from
    // SPReadyNessApp.onStart per ADR 0015, risks a perceptible hang on
    // launch if the app hasn't been opened in a while and the buffer has
    // filled with a day's worth of continuous samples — bodyBatteryAtWake()
    // avoids exactly this with its own early return). Oldest-first samples
    // are monotonically increasing in time, so once one is past wake, every
    // remaining sample is too — breaking there bounds the walk to "buffer
    // oldest through wake" and nothing further, with the identical result.
    function todaysRhr() as Lang.Number? {
        var profile = UserProfile.getProfile();
        if (profile == null || profile.wakeTime == null) { return null; }

        var wakeMoment = Time.today().add(profile.wakeTime);

        var iter = SensorHistory.getHeartRateHistory({
            :order => SensorHistory.ORDER_OLDEST_FIRST
        });
        if (iter == null) { return null; }

        var min = null;
        var sample = iter.next();
        while (sample != null && !sample.when.greaterThan(wakeMoment)) {
            if (sample.data != null && (min == null || sample.data < min)) {
                min = sample.data;
            }
            sample = iter.next();
        }
        return (min == null) ? null : min.toNumber();
    }
```

- [ ] **Step 5: Update `Capture.run()`'s call site**

In `source/capture/Capture.mc`, `run()` currently reads:

```monkeyc
            return runWith(
                Sensors.bodyBatteryAtWake(),
                Sensors.recoveryHours(),
                Sensors.rhr(),
                Sensors.rhrBaseline(),
                dayKey
            );
```

Change the `Sensors.rhr()` line to `Sensors.todaysRhr()`:

```monkeyc
            return runWith(
                Sensors.bodyBatteryAtWake(),
                Sensors.recoveryHours(),
                Sensors.todaysRhr(),
                Sensors.rhrBaseline(),
                dayKey
            );
```

- [ ] **Step 6: Run to verify all pass**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: `PASSED (passed=38, failed=0, errors=0)`.

- [ ] **Step 7: Build the app binary to confirm `todaysRhr()` compiles cleanly end-to-end**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/spreadyness.prg -y developer_key.der`
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 8: Commit**

```bash
git add source/capture/Sensors.mc source/capture/Capture.mc tests/CaptureTest.mc
git commit -m "feat: derive today's RHR from heart-rate history instead of the unreliable Profile field"
```

---

### Task 4: `NowView` reuses today's stored RHR instead of re-deriving it live

**Files:**
- Modify: `source/ui/NowView.mc:25-41` (`onShow()`)
- Modify: `verify.sh` (extend the printed manual-verification checklist)

**Interfaces:**
- Consumes: `RecordStore.latest() as Lang.Dictionary?`, `DailyRecord.today() as Lang.Number` (both already used elsewhere in the app, e.g. `MorningView.mc:15`, confirmed reachable from this same unannotated default scope), `Sensors.rhrBaseline() as Lang.Number?` (unchanged).
- **No unit test exists for `NowView`** — it draws to a `Graphics.Dc` and has zero existing test coverage (HANDOFF.md: "Not covered at all: every drawing call... the app lifecycle"), matching every other view file in this project. This task's testable deliverable is a clean app build plus the manual on-device verification step added below, using the same mechanism `verify.sh` already relies on for other real-device-only UI behavior.

- [ ] **Step 1: Update `NowView.onShow()`**

In `source/ui/NowView.mc`, replace:

```monkeyc
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
```

with:

```monkeyc
    function onShow() as Void {
        // CURRENT body battery, deliberately not the at-wake value (ADR 0010).
        _body     = Components.fromBodyBattery(Sensors.bodyBatteryNow());
        _recovery = Components.fromRecoveryHours(Sensors.recoveryHours());

        // RHR is a daily value and cannot change intraday, so it is read
        // from today's already-captured record rather than re-derived (ADR
        // 0018) — re-walking SensorHistory this late in the day risks the
        // buffer having rolled past this morning's overnight window
        // entirely. Sensors.rhrBaseline() has no such buffer (a Profile
        // field, confirmed reliable), so it stays a live read.
        var record = RecordStore.latest();
        var today = DailyRecord.today();
        var rhrValue = (record != null && record[:day] == today) ? record[:rhrBpm] : null;
        var baseline = Sensors.rhrBaseline();
        _rhr = Components.fromRhr(rhrValue, baseline);
        var delta = (rhrValue != null && baseline != null) ? rhrValue - baseline : null;

        _result = Readiness.compute(_body, _recovery, _rhr, delta);

        var now = System.getClockTime();
        _stamp = "NOW " + now.hour.format("%02d") + ":" + now.min.format("%02d");
    }
```

- [ ] **Step 2: Run the full test suite to confirm nothing else broke**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test && monkeydo bin/test.prg fr165 -t`
Expected: `PASSED (passed=38, failed=0, errors=0)` (unchanged from Task 3 — `NowView` has no tests to add to this count).

- [ ] **Step 3: Build the app binary**

Run: `monkeyc -f monkey.jungle -d fr165 -o bin/spreadyness.prg -y developer_key.der`
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 4: Extend `verify.sh`'s manual-verification checklist**

In `verify.sh`, the script ends by printing a numbered checklist of things that need a human eye in the simulator/real device. Add one more item to that list (after the existing item 9, "Background is pure black..."):

```bash
echo "  10. Now Score's RHR component matches the Morning Score's value all"
echo "      day, even hours after wake (ADR 0018) — check on a real device,"
echo "      not just the simulator, since this is exactly the scenario a"
echo "      stale SensorHistory buffer would silently break."
echo ""
```

- [ ] **Step 5: Commit**

```bash
git add source/ui/NowView.mc verify.sh
git commit -m "fix: NowView reuses today's stored RHR instead of re-deriving it live (ADR 0018)"
```
