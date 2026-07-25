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
The wearer's own multi-day average resting heart rate, which today's resting heart
rate is measured against. Read from `Profile.averageRestingHeartRate` rather than
computed by the app.
_Avoid_: average RHR, 7-day average, normal RHR

**Capture**:
The once-daily act of reading the inputs and writing the Daily Record, performed
by the background service.
_Avoid_: sync, refresh, update, poll
