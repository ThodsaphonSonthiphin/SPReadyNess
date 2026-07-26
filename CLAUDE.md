# SPReadyNess

Garmin Connect IQ watch app for the Forerunner 165 (daily readiness score).
See [README.md](README.md) for install/build steps and [HANDOFF.md](HANDOFF.md)
for design context and open questions as of the last handoff.

## Toolchain setup (this machine)

- SDK: `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-*/bin`
  on PATH — but only in an interactive shell. Claude Code's own Bash tool
  spawns a fresh non-interactive shell per call with no exports carried over,
  so every agent Bash command needing `monkeyc`/`monkeydo` must `export PATH`
  inline with the full resolved SDK dir (the version suffix changes, so `ls`
  it first rather than hardcoding it).
- Java: `monkeyc` needs a JRE. Installed via `brew install openjdk@17` — **not**
  the `--cask temurin@17` cask, which runs a signed `.pkg` needing interactive
  sudo and fails in a non-interactive shell. Add
  `/opt/homebrew/opt/openjdk@17/bin` to PATH (it's keg-only, not auto-linked).
- Simulator: `connectiq &` then `monkeydo bin/spreadyness.prg fr165`. **No CLI
  way found to send page-navigation/button input to the simulator** — visual
  verification of any screen requires the user to manually navigate (page
  down, reset app data, etc.) and take a screenshot. Budget for several
  rebuild/redeploy/screenshot round-trips per UI bug.
- `./verify.sh` and any bare `monkeydo` call require the Connect IQ simulator
  process already running (`connectiq &`, give it a few seconds) — otherwise
  they fail with `Unable to connect to simulator`, which reads like a build
  problem but isn't.

## Getting a crash log off the real device

There is no live debugger/logging attach to a real watch (simulator only —
see the Simulator bullet above). The only real-device evidence is a crash
record the watch itself writes. Steps, verified against a Garmin Forums
thread on decoding these (not guessed):

1. Connect the watch via USB — it mounts as a normal mass-storage drive, the
   same mount used for sideloading `bin/spreadyness.prg` into `GARMIN/APPS/`.
2. Look for `GARMIN/APPS/LOGS/CIQ_LOG.YAML` (older Connect IQ: `CIQ_LOG.TXT`).
   This is written for a sideloaded dev-key build the same as a store build.
3. Each crash entry has a `pc:` field in **hex** (e.g. `pc: 0x100014eb`) and
   no human-readable function/line — the device does not resolve this.
4. Convert that hex value to decimal (e.g. `0x100014eb` -> `268440811`).
5. Open the `bin/spreadyness.prg.debug.xml` produced by the **same build**
   that's installed on the watch (every `monkeyc` run regenerates this file —
   an old one from a different build won't match). Search its `<entry ...
   pc="...">` values for one close to the decimal number from step 4 (usually
   within a few units) — that entry's `filename`/`lineNum`/`symbol`
   attributes are the actual crash site, e.g. `pc="268440815"` ->
   `filename=".../PiGdView.mc" lineNum="118" symbol="initialize"` means the
   crash happened at/near line 118 inside `initialize`.
6. Keep the debug.xml from whichever build is currently installed — rebuilding
   before decoding a log invalidates the offsets.

Source: [Garmin Forums — "so you have a ciq_log file, but all you see is
pc:..."](https://forums.garmin.com/developer/connect-iq/f/discussion/231129/so-you-have-a-ciq_log-file-but-all-you-see-is-pc-without-a-friendly-stack-trace---what-to-do/1095959)

## Connect IQ SDK 9.2.0 gotchas (discovered getting this app to compile and run for the first time)

HANDOFF.md was written before any of this code had ever been compiled. These
are the facts found by actually building and running it — several resolve
open questions HANDOFF.md left unsettled.

- `hidden` is not a Monkey C keyword. Module-scope functions accept only
  `public` as an explicit modifier (or no modifier); `private`/`protected`
  are class-scope only and the compiler rejects them at module scope.
- `AppBase.getServiceDelegate` / `getInitialView` / `getGlanceView` overrides
  must match the base class's exact bracket-tuple return types (e.g.
  `as [System.ServiceDelegate]`), not `Lang.Array<T>` — the compiler rejects
  an override whose return type isn't spelled identically to the base's.
- `Application.Storage.KeyType`/`ValueType` explicitly exclude `Symbol` (the
  SDK's own docs note "Symbols... are not to be used for Keys or Values").
  A Symbol-keyed Dictionary passed to `Storage.setValue` throws
  `UnexpectedTypeException: Given value cannot be serialized` — translate to
  String keys at the storage boundary (see `RecordStore.toStorable`/
  `fromStorable`).
- `Graphics.Dc.drawText`'s y-coordinate is the **top** of the text's bounding
  box, not vertical-center, unless `TEXT_JUSTIFY_VCENTER` is also passed. A
  large font (e.g. `FONT_NUMBER_THAI_HOT`) drawn assuming center-anchoring
  will overflow far past where expected.
- `getTextDimensions`'s reported height can wildly overstate visible glyph
  ink for numeral-only strings — e.g. `FONT_NUMBER_THAI_HOT` reported 152px
  tall for "39", yet the existing layout (built around that number) renders
  with no visible overlap. Trust *width* measurements more than *height* when
  sizing a container around text; verify height changes visually rather than
  by the raw reported number.
- `Test.assertEqualMessage`/`Test.assertEqual` crash with
  `Unexpected Type Error: Failed invoking <symbol>` when the **actual** value
  is `null` (confirmed via an isolated probe — a Run No Evil bug in this SDK
  build, unrelated to app code). Assert on `expr == null` via
  `Test.assertMessage` instead of passing `null` as the actual value.
- Any top-level function tagged `(:test)` gets auto-invoked by the generated
  test harness as a test case with a single `Test.Logger` argument,
  regardless of its real signature. Don't tag shared test helpers with
  `(:test)` — reserve it for actual `(logger) -> Boolean` test functions;
  a mis-tagged helper ships as inert dead code in non-test builds instead,
  which is harmless.
- `monkeydo <prg> <device> -t` exits `1` unconditionally in this SDK build,
  even on a fully passing suite. Don't gate success on its exit code — parse
  the `PASSED (...)`/`FAILED (...)` summary line in its output instead (see
  `verify.sh`).
- **`(:glance)`-scoped code cannot access the generated `Rez` symbol at all —
  confirmed on a real device** (fr165, firmware 28.05, ConnectIQ 6.0.2), not
  just theorized: `WatchUi.loadResource(Rez.Strings.*)` inside
  `SPReadyNessGlanceView` crashed with `Illegal Access (Out of Bounds): Could
  not access symbol 'Rez'` per `GARMIN/APPS/LOGS/CIQ_LOG.YAML`, even though it
  compiled cleanly and ran fine in the simulator. This settles HANDOFF.md's
  open question about what the `(:glance)` annotation actually does, at least
  for resources: it is NOT an inert label here — it excludes `Rez` from the
  glance's compiled scope. Use plain string literals in glance-scoped code
  instead of `Rez.Strings.*`.
