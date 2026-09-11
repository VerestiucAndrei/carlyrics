# CarLyrics

Time-synced lyrics as an iOS 26 widget on the CarPlay screen. Personal project; runs fully on the
phone, built on GitHub Actions, signed on-device with SideStore. See [PLAN.md](PLAN.md).

## Layout

- `project.yml` — XcodeGen spec (app + widget extension)
- `App/` — host app: detection, lyrics, debug screen. All writes to the App Group happen here.
- `Widget/` — WidgetKit extension: reads `now.json`, renders. Nothing else.
- `Core/` — pure-Swift package shared by both; `swift test` runs on the macOS runner.

## Install

1. Push to `main`; the workflow attaches `CarLyrics.ipa` to the `latest` prerelease.
2. Open the release asset URL in Safari on the iPhone and hand it to SideStore.
3. Add the "Lyrics" widget to the home screen, then to the CarPlay stack in
   Settings → General → CarPlay → *car* → Widgets.
