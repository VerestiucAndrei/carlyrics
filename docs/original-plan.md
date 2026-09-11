# CarPlay Synced Lyrics — Fully Local, Zero-Cost Build Plan

**Goal:** an iOS widget rendering time-synced lyrics on the CarPlay screen, covering as many music sources as possible, with better catalog coverage and better sync accuracy than Dynamic Lyrics.

**Hard constraints:**
- Everything runs on the iPhone. No server, no network dependency at drive time.
- No Mac.
- Free — no Apple Developer Program, no paid APIs, no hosting.
- Personal use only. No App Store, no App Review, no lyrics licensing.

All three are satisfiable. Total recurring cost: **€0**.

---

## 0. Corrections to earlier assumptions

Two things I had wrong in previous drafts, both verified against Apple's own docs:

**App Groups is available on the free tier.** Apple's Supported Capabilities (iOS) table lists capabilities across three membership levels — ADP (paid), ADEP (enterprise), and "Apple Developer" (free Apple Account holders who've agreed to the Developer Agreement, at no cost, who can't distribute apps). **App groups** and **Background modes** are both checked in all three columns. Push notifications, Associated domains, and Sign in with Apple are not.

**ShazamKit is usable free, via custom catalogs.** The ShazamKit App Service you enable on an App ID in the portal is specifically for checking signatures against the *Shazam music catalog*. A **custom catalog** is different: you supply your own reference signatures, and all matching is performed locally on the device. No portal access, no paid membership, no network.

That second point is what makes universal source coverage possible on a free account.

---

## 1. What you can and cannot detect

| Source | Mechanism | Offline | Free | Position accuracy |
|---|---|---|---|---|
| **Apple Music** | `MPMusicPlayerController.systemMusicPlayer` | ✅ | ✅ | Exact (`currentPlaybackTime`) |
| **Spotify** | App Remote SDK (local IPC) | ✅ | ✅ | Exact (`playbackPosition`) |
| **YouTube Music, Tidal, Deezer, SoundCloud, local players, Bluetooth** | ShazamKit custom catalog | ✅ | ✅ | Good (`predictedCurrentMatchOffset`) |
| Anything, via system now-playing | `MediaRemote` — **unavailable** | — | — | — |

**On MediaRemote:** it's the obvious answer and it's closed. The `com.apple.mediaremote.*` entitlements can't be added to a free provisioning profile — attempting it produces `Provisioning profile "iOS Team Provisioning Profile" doesn't include the com.apple.mediaremote.set-playback-state entitlement`. Apple also added entitlement verification to `mediaremoted` in recent OS versions, denying clients without it. The known bypasses (Perl adapter shims, daemon injection) are all macOS-only. Don't plan around it.

### Tier C is the interesting one

ShazamKit custom catalogs give you a universal, offline, free detector — with one real cost: **you must supply reference audio** for each track you want recognised. Signatures are one-way derivations of the audio; you can't synthesise them from metadata.

This means Tier C covers what you've indexed, not the whole world. In practice that's fine, because:

- Apple Music and Spotify are covered by Tiers A and B with no audio needed.
- Tier C is for repeat listening on other platforms — exactly the tracks worth indexing.
- **The same audio feeds your LRC generation pipeline** (§5.1). One input, two outputs: a Shazam signature and an aligned `.lrc`. You were going to need the audio anyway.

Catalogs are built once and written to disk as `.shazamcatalog`, then loaded at runtime.

**Optional refinement:** custom catalogs support time-restricted media items — metadata attached to specific time ranges in the reference recording. You can embed the lyric lines directly in the catalog at their timecodes, making the catalog itself the lyrics database. Elegant, but it couples two concerns; start with `matchOffset` plus a separate LRC file and only merge them if the separation annoys you.

---

## 2. Build toolchain — no Mac, still free

### Primary: GitHub Actions macOS runners

**Standard GitHub-hosted runners are free and unmetered on public repositories, with no minute cap, on every plan** — including macOS. The 2,000-minute allowance and the 10× macOS multiplier apply only to private repos.

So: make the repo public, and you get free real Xcode on real Apple hardware, indefinitely.

```yaml
# .github/workflows/build.yml
on: [push, workflow_dispatch]
jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: |
          xcodebuild -scheme CarLyrics -sdk iphoneos \
            -configuration Release -derivedDataPath build \
            CODE_SIGNING_ALLOWED=NO
      - run: |
          mkdir -p Payload
          cp -r build/Build/Products/Release-iphoneos/CarLyrics.app Payload/
          zip -r CarLyrics.ipa Payload
      - uses: actions/upload-artifact@v4
        with: { name: ipa, path: CarLyrics.ipa }
```

Build unsigned. Signing happens on the phone.

### Signing: SideStore

SideStore re-signs the `.ipa` with your free Apple ID's development certificate, on-device, and refreshes over the network without a computer. That turns the 7-day personal-team expiry from a dealbreaker into a background chore.

Push → wait ~5 min → download artifact on the iPhone → open in SideStore. No cable, no Mac, no desk.

### Secondary: xtool, for fast local iteration

[`xtool`](https://github.com/xtool-org/xtool) builds SwiftPM packages into iOS apps and signs and installs them from Linux/WSL, using Swift/Clang, LLD, `zsign` and `libimobiledevice`. It supports app extensions including widgets — declare the extension as a `.library` product in `Package.swift`, register it in `xtool.yml`, give it an `Info.plist`.

Worth having for tight loops, but it needs the iOS SDK extracted from an `Xcode.xip`, whose EULA authorises use only on Apple hardware running macOS. CI sidesteps that entirely, which is why CI is primary.

### Debugging

| Need | Tool |
|---|---|
| Device console / `os_log` | `idevicesyslog` (libimobiledevice, runs on Linux, over USB) |
| Build errors | Actions logs |
| Widget state inspection | In-app debug screen mirroring the App Group contents |
| Sync validation | In-app karaoke view — if it's in sync and the widget isn't, the bug is in timeline scheduling |

No debugger, no SwiftUI previews. Plan for print-debugging and keep the widget dumb.

### Test hardware — decide before writing code

No Xcode locally means **no CarPlay simulator**. You need physical CarPlay hardware: your car, or a €80–120 aftermarket wireless head unit on your desk. Get the desk unit unless your car is parked outside your window.

Requirement: iPhone on **iOS 26+**. Widgets don't render in CarPlay before that.

---

## 3. Architecture

```
┌────────────────────────────────────────────────────────────┐
│ HOST APP  (background-resident)                             │
│                                                             │
│  DetectionCoordinator                                       │
│    ├─ AppleMusicSource   MPMusicPlayerController            │
│    ├─ SpotifySource      SPTAppRemote                       │
│    └─ ShazamSource       SHSession(catalog: SHCustomCatalog)│
│              │  priority: A > B > C                         │
│              ▼                                              │
│  PositionEstimator   continuous re-anchor + drift filter    │
│              │                                              │
│  LyricsStore  (SQLite + .lrc files, pre-fetched)            │
│  OffsetStore  (per-ISRC / per-track calibration)            │
│  CatalogStore (.shazamcatalog files)                        │
│              │                                              │
│              ▼  writes                                      │
│      ┌─────────────────────────────┐                        │
│      │  App Group container         │                       │
│      │  currentSong.json            │                       │
│      └─────────────────────────────┘                        │
│              │  reads (read-only!)                          │
└──────────────┼──────────────────────────────────────────────┘
               ▼
┌────────────────────────────────────────────────────────────┐
│ WIDGET EXTENSION  (~200 lines)                              │
│   TimelineProvider → one entry per lyric line               │
│   No networking. No parsing. Pure render.                   │
└────────────────────────────────────────────────────────────┘
               │
               ▼
      CarPlay widget stack (iOS 26+)
```

**No CarPlay entitlement needed.** iOS 26 renders ordinary iPhone widgets on the CarPlay screen — five slots per stack, configured in Settings → General → CarPlay → *your car* → Widgets; screens over 11 inches show two or three stacks. This bypasses CarPlay's app-category approval, which has no "lyrics" category and never will.

### Staying alive in the background

`UIBackgroundModes: location` plus `allowsBackgroundLocationUpdates = true`, with `NSLocationAlwaysAndWhenInUseUsageDescription`. Info.plist and a permission prompt — Background modes is free-tier. Navigation apps depend on this path, so it's robust, and you're driving anyway.

Tier C needs `UIBackgroundModes: audio` as well for continuous mic capture. Both can coexist.

*Known issue:* `SHManagedSession` has been reported to stop matching in the background after ~20 seconds on iOS 18+, where the same code worked on iOS 17 (FB15255903, repro at `github.com/tfmart/ShazamKitBackground`). Assume unfixed. Design Tier C to re-arm its session on a timer, and treat it as best-effort rather than load-bearing.

### The one App Group restriction

Widget extensions appear to be **read-only** with respect to the shared container. Writing `UserDefaults(suiteName:)` from a widget extension fails with `setting preferences outside an application's container requires user-preference-write or file-write-data sandbox access`, while reading the same group works — reportedly a deliberate privacy restriction on widget and Live Activity extensions.

Consequence: all writes happen in the host app. Your calibration button (§4.5) lives there, not in an interactive widget. You calibrate while parked anyway.

---

## 4. Sync engine

Your reported symptom — per-song offset, sometimes early, sometimes late — has four causes. Diagnose first: **same offset every play = master mismatch (4.1); different offset each play = anchor error (4.2).**

### 4.1 Master mismatch

Community LRC files are synced against one specific release. Remasters, single edits, clean versions and regional masters have different intro lengths. A file synced against a different master than what's playing gives a fixed, permanent, direction-arbitrary offset.

**Prevent rather than correct:** pass track duration to the lyrics source and reject candidates differing by more than ~2s. LRCLIB supports this directly via its `duration` parameter. This kills most of the problem at fetch time.

Parse and apply the LRC `[offset:±ms]` header **exactly once** — double-applying it in both parser and renderer is a classic consistent-error bug.

### 4.2 Anchor error

The broken pattern computes `t0` once at track change and extrapolates forever. Instead re-sample every 3–5s and filter:

```
t0Est = α · (observedNow − observedPosition) + (1 − α) · t0Est    // α ≈ 0.15
```

Hard-reset on seeks — detect a position jump exceeding elapsed wall-clock time and rebuild rather than filtering through the discontinuity.

Tiers A and B report position locally with near-zero latency, so this term is small for them. It matters most for Tier C, where `predictedCurrentMatchOffset` carries real uncertainty.

### 4.3 Audio path latency

Wireless CarPlay is Wi-Fi with a jitter buffer; A2DP Bluetooth adds roughly 150–250ms. The host app is alive, so read `AVAudioSession.currentRoute` and apply a per-route-type constant automatically. Store separate calibrations for wired CarPlay / wireless CarPlay / Bluetooth / speaker.

### 4.4 WidgetKit scheduling jitter

The system fires timeline entries approximately, not exactly — tens to low hundreds of milliseconds, worse under thermal pressure. Irreducible. Schedule entries ~150ms early.

### 4.5 One-tap calibration

The feature that actually fixes your library, and an afternoon's work:

- Large **sync** button in the host app. Tap it the instant the displayed line is actually sung.
- Compute `delta = truePosition − displayedLineTimestamp`, persist keyed by ISRC (or by track ID for Tier C).
- Every future play of that song is permanently correct.

Add ±100ms nudges. This is precisely what Dynamic Lyrics lacks.

---

## 5. Lyrics — coverage

Roughly 30% of catalog tracks lack time-codes in any commercial database, and coverage collapses for non-Anglophone, older, and independent releases. A single upstream is why Dynamic Lyrics misses so much of your library. Build a chain, cache everything locally, and generate the rest yourself.

| Order | Source | Notes |
|---|---|---|
| 1 | **Local override** — your own `.lrc` files | Always wins. Hand-fixed and generated files land here. |
| 2 | **LRCLIB** (`api.lrclib.net`) | Open, no key. `/api/get?artist_name=&track_name=&album_name=&duration=` — duration param is your master-mismatch defence. |
| 3 | **NetEase Cloud Music** | Deep synced-LRC coverage, strong outside Western catalog. Unofficial. |
| 4 | **QQ Music** | Different coverage again. |
| 5 | **Spotify color-lyrics** (`spclient.wg.spotify.com/color-lyrics/v2/track/{id}`) | Musixmatch-sourced, well synced, needs a user token. Undocumented, breaks periodically. |

The Python package `syncedlyrics` aggregates several of these — good reference for the matching heuristics.

**Matching key:** ISRC first (Spotify's `external_ids.isrc`); otherwise normalised artist + title + duration. `MPMediaItem` gives you artist, title, album and duration locally with no token.

### Prefetch strategy — the offline requirement

Network is for *filling the cache*, never for playback. Three fill paths:

1. **Lazy:** cache every track you play. First play of a new song needs connectivity; every play after is local.
2. **Bulk:** when on Wi-Fi, walk your Spotify saved tracks / playlists (Web API) or your Apple Music library (`MPMediaQuery`, no token needed) and resolve LRC for everything.
3. **Sideload:** import `.lrc` files from the Files app via `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`.

Sizing: ~3KB per song × 5,000 tracks ≈ 15MB. Storage is a non-issue.

### 5.1 Generating LRC for the tail

For songs nothing has, run this on your PC once per track. Output goes into the override folder — and the same audio input produces the Shazam signature for Tier C.

```
audio file
  ├─► SHSignatureGenerator ──────────► .shazamcatalog entry   [Tier C detection]
  │
  └─► Demucs (htdemucs)              # isolate vocal stem
        └─► WhisperX align, or torchaudio MMS_FA / CTC forced aligner
              (align against the known lyric text; do not transcribe)
                └─► word-level timestamps
                      └─► .lrc  (line-level, or enhanced/A2 word-level)
```

Forced alignment against known text is dramatically better than free transcription — you're solving for timing only, not timing *and* content. Near-perfect on clean vocals; degrades on heavy layering, ad-libs and dense harmony. Use transcription only when no lyric text exists at all, and hand-correct.

Signature generation is an iOS/macOS API, so run it either in an in-app "index this file" screen or as a step on your free macOS runner. Requires Python 3.11+ with `demucs`, `whisperx`, `syncedlyrics`; GPU strongly preferred.

---

## 6. Widget layer

WidgetKit is **not** a live view. A frequently viewed widget gets roughly **40–70 refreshes per day**, about one reload every 15–60 minutes. You cannot reload per lyric line.

### 6.1 Pre-computed timelines

Multiple `TimelineEntry` objects are not "updates" — an update is when the system asks for a *new* timeline. Push the whole song in one:

```swift
func timeline(for config: Configuration, in context: Context) async -> Timeline<LyricEntry> {
    guard let s = SharedStore.load() else {          // App Group read, no networking
        return Timeline(entries: [.idle], policy: .never)
    }

    let t0 = s.anchorDate
             + s.trackOffset          // §4.5 calibration
             + s.routeLatency         // §4.3, resolved by the app
             - Config.schedulingBias  // §4.4, ~0.15s

    let entries = s.lines.enumerated().map { i, line in
        LyricEntry(date: t0 + line.t,
                   current: line.text,
                   next: s.lines[safe: i + 1]?.text)
    }
    return Timeline(entries: entries, policy: .after(t0 + s.duration))
}
```

Typical song = 30–80 lines, comfortably within limits; timelines beyond roughly 400 entries have been observed to stop updating entirely. **One song = one budget hit, not fifty.**

### 6.2 Budget management

Because the host app is alive, it calls `WidgetCenter.shared.reloadTimelines(ofKind:)` directly on state changes — no push needed, and skips update instantly.

| Event | Action |
|---|---|
| Track change | Rebuild full timeline |
| Seek | Rebuild from new anchor |
| Pause | Single frozen entry, `.never` |
| Resume | Rebuild with fresh anchor |
| Offset nudge | Rebuild |

Aggressive skipping burns the allowance. Debounce reloads at ~300ms and skip rebuilds where the delta is under ~200ms.

### 6.3 Extension discipline

Tight memory ceiling, short execution window, read-only container. The extension reads one JSON file and renders. Everything else — resolution, correction, sorting — happens in the app.

---

## 7. Rendering

- **Current line large, next line dimmed. Nothing else.** Car widgets have to survive a glance at speed.
- Respect CarPlay's day/night ambient mode.
- No animation. Timeline entries are discrete snapshots with no interpolation; animation will look wrong.
- No timecodes available → static lyrics, no highlight. A wrong highlight is worse than none.
- Show the active source (A/B/C) subtly. When sync is off you want to know which detector produced it.

---

## 8. Milestones

Ordered so blocking unknowns resolve first and cheapest.

| Phase | Scope | Est. |
|---|---|---|
| 0 | Secondary Apple ID · public repo · Actions workflow · SideStore · hello-world `.ipa` installed | 1 day |
| 0.5 | **Hello-world widget on the iPhone home screen** — proves the extension pipeline end to end | 0.5 day |
| 0.75 | **Same widget in the CarPlay stack** on real hardware. Stop here if it fails. | 0.5 day |
| 1 | App Group plumbing + in-app debug screen showing shared state | 0.5 day |
| 2 | Tier A: Apple Music detection → live `{track, position}` in the debug screen | 1–2 days |
| 3 | LRCLIB resolver with duration matching + LRC parser + in-app karaoke view | 2 days |
| 4 | `PositionEstimator` with continuous re-anchoring; validate drift against the karaoke view | 1 day |
| 5 | Widget: pre-computed timeline + app-triggered reloads | 2–3 days |
| 6 | Per-track offset store + one-tap calibration | 1–2 days |
| 7 | Tier B: Spotify App Remote + reconnection handling | 3–4 days |
| 8 | Prefetch: bulk library walk + lazy caching + Files import | 2 days |
| 9 | Multi-source chain (NetEase, QQ, color-lyrics) | 2–3 days |
| 10 | PC pipeline: Demucs + forced alignment → `.lrc` | 3–5 days |
| 11 | Tier C: custom catalog build + `SHSession` matching + background re-arming | 1 week |

**Phases 0–6 (~10 days) already beat Dynamic Lyrics on Apple Music**, because calibration fixes sync permanently and duration matching fixes a chunk of coverage. Phase 7 adds Spotify. Phases 10–11 are what nothing else on the App Store does.

Start with Apple Music, not Spotify: `MPMusicPlayerController` has no SDK dependency, no OAuth, no reconnection logic, and gives an exact local position. It's the cleanest way to validate the whole pipeline before adding Spotify's complexity.

---

## 9. Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| Widget extension won't build/sign under free tier + SideStore | **Blocking** | Phase 0.5, day one |
| CarPlay stack won't render your widget | **Blocking** | Phase 0.75. No simulator exists — real hardware only. |
| Free-team 3-app limit (app + extension = 2 slots) | Medium | Clear other sideloaded apps |
| `SHManagedSession` background cutoff | Medium | Re-arm on timer; Tier C is best-effort |
| Apple ID flagged by sideloading tooling | Medium | Secondary Apple ID from day one |
| Tier C needs reference audio you may not have | Medium | Accept partial coverage; it shares input with §5.1 |
| Widget extension read-only container | Low | All writes in host app (already designed for) |
| Unofficial lyrics endpoints break | Low | Chain degrades rather than fails |

---

## 10. Cost ledger

| Item | Cost |
|---|---|
| GitHub Actions macOS runners (public repo) | €0 |
| Apple ID / free provisioning | €0 |
| SideStore | €0 |
| LRCLIB, NetEase, QQ | €0 |
| ShazamKit custom catalogs | €0 |
| Demucs / WhisperX (local) | €0 |
| Spotify App Remote | €0 (Premium needed for playback control, which you have) |
| **Recurring total** | **€0** |
| CarPlay head unit for desk testing | €80–120 one-off, optional if you test in the car |

The €99 Developer Program would buy you: 1-year signing instead of 7-day, push-triggered reloads, unlimited app slots, and access to the full Shazam music catalog (removing Tier C's reference-audio requirement). None are load-bearing. Revisit only if weekly re-signing becomes tedious or Tier C's coverage limit frustrates you.

---

## 11. Personal-use footnote

Unofficial endpoints and locally cached lyrics are a terms-of-service question between you and the service at single-user scale, not a copyright-enforcement one — a different exposure profile from a shipped app. Two consequences:

- **Keep the repo public but the app private.** Public repo is what makes CI free; publishing builds is what would create liability. Don't distribute `.ipa`s, and keep any API tokens out of the repo (use Actions secrets).
- Rate-limit your own fetchers. Unofficial endpoints survive because they're used gently.
