# SPReadyNess — handoff

The app is implemented: 13 tasks, 24 Monkey C files, 8 test files. Design in
[`docs/superpowers/specs/`](docs/superpowers/specs/2026-07-26-spreadyness-design.md),
decisions in [`docs/adr/`](docs/adr/), plan in
[`docs/superpowers/plans/`](docs/superpowers/plans/2026-07-26-spreadyness.md).

## Nothing here has ever been compiled

The Connect IQ SDK was not available in the environment that wrote this code. Every
verification to date is static reading and hand-tracing. No build, no test run, no
simulator, no device.

**Start here:**

```bash
./verify.sh
```

It checks for the SDK, generates a developer key if needed, builds and runs the unit
tests, and builds the app.

## Where to look first if the build fails

In order of likelihood. Each was flagged during review and could not be settled
without the SDK.

1. **`Profile.wakeTime`'s return type** — `source/capture/Sensors.mc`, in
   `bodyBatteryAtWake()`. The code does `Time.today().add(profile.wakeTime)`,
   assuming `wakeTime` is a `Time.Duration`. If it is a raw `Number` the `.add()`
   fails. Expect a loud error, not silent corruption.
2. **`Moment.subtract(Moment).value()`** — `source/ui/DisplayState.mc`, in
   `ageInDays()`. Assumes the subtraction yields something with `.value()` in
   seconds.
3. **Anything else** — the tree is otherwise a faithful transcription of reviewed
   code, but a first compile of 24 never-compiled files will find typos no amount of
   reading catches.

## What only the simulator can settle

- **Arc geometry.** The score arc should be 270°, opening at the bottom, filling
  clockwise. The angle arithmetic was hand-traced against Connect IQ's convention
  (0° at 3 o'clock, counter-clockwise) but never rendered.
- **Degenerate arcs.** `Draw.scoreArc` and `Draw.componentDial` both guard against
  drawing an arc whose start angle equals its end angle, because Connect IQ may
  render that as a full circle rather than nothing. If it renders as nothing, the
  guards are harmless; if as a full circle, they are load-bearing. Unproven either
  way.
- **The four Morning Score states** — current, stale, RHR-unchecked, empty. Reset app
  data in the simulator to see the empty state.
- **The Now Score page** — dashed arc, `NOW hh:mm` pill, and that it greys entirely
  when RHR is absent.
- **The glance card**, including its gradient bar.

Compare against the approved mockup: [`docs/mockups/screens.html`](docs/mockups/screens.html).

## Memory ceilings — unmeasured

Garmin does not document the background-process or glance memory limits, and their
documentation pages would not load during development. Both scopes are populated via
`(:background)` and `(:glance)` annotations on the modules each needs.

If either scope overruns on a real build, the lever is to shrink what those scopes
pull in — the glance currently reaches `RecordStore`, `DisplayState`, `StatusBand`
and `Theme`. A previous attempt to add `excludeAnnotations` to `monkey.jungle` was
reverted: it would have broken the app build, and the annotations already do the
scoping on their own.

The total `Application.Storage` budget on the FR165 is also unmeasured. 120 records
at roughly 25 bytes is about 3 KB, and individual values cap at 32 KB, so this is
expected to be comfortable — but unconfirmed.

## Calibration, once real data exists

Five constants in [`source/Constants.mc`](source/Constants.mc) were chosen for
plausibility, not derived from data:

| Constant | Value | What it controls |
|---|---|---|
| `RECOVERY_FULL_HOURS` | 48 | hours of outstanding recovery that scores 0 |
| `RHR_SLOPE` | 8 | points lost per bpm above baseline |
| `RHR_CAP_EASY_BPM` | 7 | deviation that caps the score at GO EASY |
| `RHR_CAP_REST_BPM` | 12 | deviation that caps it at REST |
| weights | 50 / 30 / 20 | Body Battery, Recovery, RHR |

Two assumptions behind the override thresholds are also unverified: the averaging
window of `Profile.averageRestingHeartRate`, and whether `restingHeartRate` reflects
the night just ended or lags a day. If it lags, the illness override fires a day
late. Both need a real device to settle.

**The weights must stay integers.** The scoring path is integer arithmetic
throughout — `(2 * sum + total) / (2 * total)` — because a float `total` puts exact
`.5` ties on the wrong side of a Status Band boundary. A sweep of all 1,061,208 input
combinations found 139 wrong results before this was fixed, 20 of them crossing a
band threshold.

## Deferred, non-blocking

- The app UUID in `manifest.xml` is synthetic. Fine for sideloading; needs a real one
  before store submission.
- `Components.fromRecoveryHours` truncates where `Readiness` rounds — worth at most
  1 point on a dial, 0.3 on the score.
- The glance's position marker uses full-brightness white in the uncoloured states,
  where it should arguably stay grey.
- `Capture.run()`'s temporal-event registration is re-established only in `onStart`.
  If the OS drops it without an app launch, captures stop until the app is next
  opened. No better hook exists in Connect IQ.

## What the tests actually prove

Genuinely covered: Status Band boundaries, all missing-input renormalisations, both
override caps, the exact-`.5` tie, store round-trip, eviction at 120, same-day
replacement, out-of-order insertion, all four display states, and real calendar
arithmetic across month, year and leap boundaries.

**Not covered at all:** every drawing call, page navigation, the app lifecycle, and
the entire sensor-read path in `source/capture/Sensors.mc`. That last one cannot be
tested without hardware — and it is where the most serious defect of the build was
found by review rather than by tests: both Body Battery reads originally shared an
unspecified iteration order, which would have silently made the at-wake read return
the current value instead.
