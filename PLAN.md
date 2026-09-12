# CarLyrics — working plan

Refined from [docs/original-plan.md](docs/original-plan.md). Only the deltas and the live milestone
table are here; the original stays as reference for the reasoning.

## Refinements

1. **XcodeGen, not a hand-written project.** [project.yml](project.yml) is the source of truth; CI runs
   `xcodegen generate`. No `.xcodeproj`, `Info.plist` or `.entitlements` in git.
2. **Ad-hoc sign on CI, not fully unsigned.** SideStore copies entitlements out of the existing code
   signature when it re-signs. An unsigned binary carries none, so the App Group would silently
   vanish. CI does `codesign -s - --entitlements` on appex then app.
3. **App Group id is resolved at runtime.** SideStore/AltStore append the team id to bundle and group
   ids. `AppGroup.id` reads the real group from `embedded.mobileprovision` in whichever bundle is
   running (app and appex each carry their own). Compile-time id is only a fallback.
4. **Release asset instead of Actions artifact.** Artifacts need a GitHub login and come zipped.
   Every push to `main` moves the `latest` tag and attaches `CarLyrics.ipa` to a prerelease, so the
   phone opens one plain URL into SideStore.
5. **Shared state is one JSON file** (`now.json`) in the group container, not `UserDefaults`.
   Position is stored as `(position, positionDate)` rather than an anchor so a paused state stays
   correct without the app re-writing it. Schema: `Core/Sources/Core/SharedState.swift`.
6. **Timeline building lives in `Core` and is unit-tested on the runner.** The widget maps frames to
   entries and renders; nothing else. Same will apply to the LRC parser and position estimator.
7. **In-app log ring buffer + `log.txt` in Documents.** No console over the air; `idevicesyslog`
   needs USB and a libimobiledevice install on Windows. Files app is enough.
8. **Swift 5 language mode for now.** Every compile error costs a CI round trip; strict concurrency
   goes on once the pipeline is proven.
9. **Phases 0, 0.5 and 1 collapsed into one build.** The extension is the blocking risk, so it is in
   the first IPA. The debug screen writes a synthetic 60s song and reloads the widget, which is the
   whole pipeline minus a music source.
10. **Alpha-filter re-anchoring deferred to Tier C.** Apple Music and Spotify report exact local
    positions; for them "re-sample on state change, hard-reset on seek" is enough.
11. **Lyrics chain starts as local override + LRCLIB.** NetEase, QQ and color-lyrics come later
    only if coverage in practice demands them.

## Milestones

| Phase | Scope | Status |
|---|---|---|
| 0–1 | Repo, CI, app + widget, App Group plumbing, debug screen | CI green, IPA published; awaiting device test |
| 0.75 | Widget visible in CarPlay stack on real hardware. **Stop if this fails.** | |
| 2 | Tier A: `MPMusicPlayerController` → live state in debug screen + widget | |
| 3 | LRCLIB resolver with duration match, LRC parser, in-app karaoke view | |
| 4 | Position handling: seek detection, route latency constant | |
| 5 | Widget reload debounce, pause/resume policy, entry cap validation | |
| 6 | Per-track offset store, one-tap calibration, ±100ms nudges | |
| 7 | Tier B: Spotify App Remote | |
| 8 | Prefetch: library walk, lazy cache, Files import | |
| 9 | Extra lyric sources | |
| 10 | PC pipeline: Demucs + forced alignment → `.lrc` | |
| 11 | Tier C: ShazamKit custom catalog | |

## Open risks (beyond the original register)

- ~~`macos-26` runner / Xcode 26~~: verified, runner ships Xcode 26.6.
- WidgetKit may coalesce entries spaced under a few seconds; Phase 0.75 test uses 5s lines.
- Free-tier "10 App IDs per 7 days": app + appex = 2. Keep bundle ids stable.
