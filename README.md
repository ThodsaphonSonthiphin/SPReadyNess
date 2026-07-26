# SPReadyNess

A Garmin Connect IQ watch app for the **Forerunner 165** that reports a daily
readiness score — the number Garmin reserves for its more expensive watches.

The 165 already measures Body Battery, recovery time and resting heart rate. It just
never combines them into a single "should I train hard today?" answer. This does that,
on the watch, from data the device already has.

> **Nothing here has ever been compiled.** The app was written in an environment
> without the Connect IQ SDK. Read [`HANDOFF.md`](HANDOFF.md) before trusting any of
> it — it lists what is unverified and where to look first if the build fails.

---

## What you get

| Surface | Shows |
|---|---|
| **Glance card** | Today's score, its band, and a red→green position bar |
| **Page 1** | The Morning Score — a 270° arc, the number, and three component dials |
| **Page 2** | A live "Now Score", computed on demand before a session |

Scores fall into four bands: **GO HARD** (80–100), **READY** (60–79), **GO EASY**
(40–59), **REST** (0–39).

The score is captured once each morning and then frozen for the day. It is built from
three inputs — Body Battery at wake (50%), outstanding recovery time (30%), and
resting heart rate against your own baseline (20%) — with a safety override: a
resting heart rate well above baseline caps the score regardless of the other two,
because that is the classic early signal of illness and an average would bury it.

---

## Requirements

| | |
|---|---|
| **Watch** | Forerunner 165 or 165 Music |
| **SDK** | Connect IQ SDK 5.x or later (the app targets API level 5.2) |
| **Tools** | `openssl`, and a USB cable for sideloading |
| **OS** | macOS, Windows or Linux — the SDK runs on all three |

---

## Install, step by step

### 1. Install the Connect IQ SDK

Download the **SDK Manager** from
[developer.garmin.com/connect-iq/sdk](https://developer.garmin.com/connect-iq/sdk/)
and run it. It manages SDK versions and device definitions for you.

In the SDK Manager:

1. Under the **SDK** tab, download the latest SDK and mark it **active**.
2. Under the **Devices** tab, tick **Forerunner 165** and download it. Without this
   the build has no device definition to compile against.

### 2. Put the SDK on your PATH

The build tools live in the SDK's `bin/` directory. Add it to your shell profile:

```bash
# macOS / Linux — adjust the version to match what you installed
export PATH="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-<version>/bin:$PATH"
```

On Windows the SDK usually lands under
`%APPDATA%\Garmin\ConnectIQ\Sdks\`; add that SDK's `bin` folder to your PATH.

Check it worked:

```bash
monkeyc --version
monkeydo --version
```

Both must resolve. If they don't, nothing below will run.

### 3. Get the code

```bash
git clone <your-fork-or-remote> SPReadyNess
cd SPReadyNess
```

### 4. Build and test

```bash
./verify.sh
```

That one command does everything: checks the SDK is present, generates a developer
signing key if you don't have one, builds the unit-test binary, runs the suite, and
builds the app. It fails loudly if anything breaks.

**This is the first real feedback this code has ever had.** If it fails, go to
[`HANDOFF.md`](HANDOFF.md) — the two most likely causes are named there in order.

If you'd rather run the steps by hand:

```bash
# a developer key, once
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER \
    -in developer_key.pem -out developer_key.der -nocrypt

# tests
monkeyc -f monkey.jungle -d fr165 -o bin/test.prg -y developer_key.der --unit-test
monkeydo bin/test.prg fr165 -t

# the app
monkeyc -f monkey.jungle -d fr165 -o bin/spreadyness.prg -y developer_key.der
```

Keep `developer_key.der` somewhere safe. It identifies you as the app's publisher, and
it is git-ignored deliberately — never commit it.

### 5. Try it in the simulator first

```bash
connectiq &                                   # starts the simulator
monkeydo bin/spreadyness.prg fr165
```

Do this before touching the watch. `verify.sh` prints a checklist of what to look at —
the four Morning Score states, the Now Score's dashed arc, the glance card, and page
navigation. Compare against the approved mockup in
[`docs/mockups/screens.html`](docs/mockups/screens.html).

To see the first-run state, use **Simulation → Reset app data**. It should show no
number at all — a zero would be a legitimate REST morning, and the two must never look
alike.

### 6. Put it on the watch

1. Connect the Forerunner 165 by USB. It mounts as a drive.
2. Copy `bin/spreadyness.prg` into **`GARMIN/APPS/`** on that drive.
3. Eject the watch properly and unplug it.
4. Find **SPReadyNess** in the watch's app list.

The glance card appears in your glance loop; you may need to enable it under
**Settings → Glances**.

---

## First run

The app tries to capture a score the moment you open it. If you install in the morning
and the watch has been on your wrist overnight, you'll usually have a real score within
seconds.

If it can't — installed late at night, or the watch wasn't worn — you'll see
**FIRST SCORE / TOMORROW MORNING** and no number. That is correct behaviour, not a
failure: the app declines to guess rather than showing you something it can't stand
behind.

From then on a background service captures one score each morning, whether or not you
open the app.

---

## Reading the screen

**Colour is the app's advice channel.** A band colour means "this is today's number,
act on it". Grey means "here's the figure, but don't".

You'll see grey when:

- the score isn't from today — the caption tells you how old it is;
- resting heart rate was unavailable, so the illness override never ran — the caption
  says `NO RHR — UNCHECKED`.

The Now Score on page 2 always draws a **dashed** arc, so a live reading can never be
mistaken for the morning's authoritative one.

**Expect the Now Score to read lower in the evening.** Body Battery drains by the
clock, not by fatigue, so an 18:00 reading is naturally below your morning one. The
three dials are there so you can see why — Body low while Recovery is high means the
clock, not your legs.

---

## Tuning it

Five constants in [`source/Constants.mc`](source/Constants.mc) set the shape of the
score. They were chosen to be plausible, **not derived from data**, and are meant to be
adjusted once you have a few weeks of your own records.

| Constant | Default | Effect |
|---|---|---|
| `RECOVERY_FULL_HOURS` | 48 | hours of outstanding recovery that scores 0 |
| `RHR_SLOPE` | 8 | points lost per bpm above baseline |
| `RHR_CAP_EASY_BPM` | 7 | deviation that caps the score at GO EASY |
| `RHR_CAP_REST_BPM` | 12 | deviation that caps it at REST |
| `WEIGHT_BODY/RECOVERY/RHR` | 50 / 30 / 20 | the three input weights |

**Keep the weights as integers.** The scoring path is deliberately integer arithmetic
end to end. Making them floats reintroduces a rounding bug that puts scores on the
wrong side of a band boundary — a sweep of all 1,061,208 input combinations found 139
wrong results, 20 of them crossing a band.

---

## Repository layout

```
source/          17 Monkey C files — scoring, storage, capture, views
tests/            7 test files, 36 tests
resources/        strings and the launcher icon
docs/adr/        15 architecture decision records
docs/superpowers/specs/    the design spec
docs/mockups/    the approved screen mockups
verify.sh        build + test + checklist
HANDOFF.md       what is unverified, and where to look first
```

Every non-obvious decision has an ADR explaining what was chosen and what was rejected.
If a piece of the code looks strange, that is where the reason lives.

---

## Not in this version

The 7-day, 30-day and 8-week history screens were cut. **The data behind them is still
being collected** — the app stores 120 daily records from day one — so those screens
can be added later and will open already populated. A chart can be built any time; the
past cannot.
