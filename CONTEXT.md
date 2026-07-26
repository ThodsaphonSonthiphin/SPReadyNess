# SPReadyNess

A Garmin Connect IQ app for the Forerunner 165 that reports a daily readiness
score derived from the watch's own recovery metrics.

## Language

**Readiness Score**:
A 0–100 number expressing how recovered the wearer is and how hard they can
train today.
_Avoid_: readiness, score, rating

**Morning Score**:
The Readiness Score as captured once for a given day. This is the only Readiness
Score that exists for that day — it does not change as the day goes on.
_Avoid_: daily score, today's score, snapshot

**Now Score**:
A Readiness Score computed on demand from current sensor values, for deciding
whether to train at this moment. Distinct from the Morning Score, never stored,
and expected to read lower later in the day.
_Avoid_: live score, current score, instant readiness

**Status Band**:
The named range a Readiness Score falls into, which drives the label and colour
shown on screen: GO HARD, READY, GO EASY, REST.
_Avoid_: level, status, zone, category

**Daily Record**:
The app's own stored entry for one calendar day, holding that day's Morning Score
and the input values it was computed from. The history screens are drawn from
Daily Records, not from the watch's sensor history.
_Avoid_: history entry, sample, data point

**Component Score**:
One input's contribution to the Readiness Score, normalised to 0–100 and shown as
its own dial. There are three: Body Battery, Recovery, and Resting Heart Rate.
_Avoid_: sub-score, factor, metric, dial

**RHR Baseline**:
The wearer's own multi-day average resting heart rate, which Today's RHR is
measured against. Read from `Profile.averageRestingHeartRate` — confirmed
reliable on real hardware (ADR 0017, rejected) even though `restingHeartRate`
itself is not.
_Avoid_: average RHR, 7-day average, normal RHR

**Today's RHR**:
The minimum heart-rate sensor sample between local midnight and wake time (ADR
0016), used as the day's resting heart rate reading. Derived by the app from raw
`SensorHistory` samples — `Profile.restingHeartRate` was confirmed unreliable on
real hardware (stays null indefinitely for most users).
_Avoid_: current RHR, live RHR, HR reading, `restingHeartRate`

**Capture**:
The once-daily act of reading the inputs and writing the Daily Record, performed
by the background service.
_Avoid_: sync, refresh, update, poll
