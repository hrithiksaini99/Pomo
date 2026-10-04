<p align="center"><img src="general/pomodoro/Resources/icon-192.png" width="112" alt="Pomo timer icon"></p>
<h1 align="center">Pomo</h1>
<p align="center">Make room for deep work.</p>
<p align="center">A quiet, free Pomodoro timer for your Mac’s menu bar.</p>
<p align="center"><a href="https://hrithiksaini99.github.io/Pomo/">Live website</a> · <a href="general/website/">Website source</a> · <a href="general/pomodoro/docs/RELEASE.md">Release guide</a> · <a href="LICENSE">MIT license</a></p>

Pomo keeps a countdown and an independent stopwatch close at hand, with a single native menu bar item. Pick a session, find your rhythm, and get back to what matters.

## Features

- Focus presets: **15, 25, 45, and 60 minutes**.
- Short and long breaks: **5 and 15 minutes**.
- Pause, resume, or stop a countdown. Selecting a preset starts it afresh.
- Run a separate stopwatch with start, pause, resume, and reset controls.
- See both timers update live, even with the menu open.
- Finish with a Glass sound and a notification when macOS permits it.
- Count completed focus sessions; breaks do not increase the count.
- Work offline with no account, analytics, or saved session history.

There is no main window or Dock icon. Timers and the session count reset when you quit. Breaks start when you choose them.

## Install the source preview

Requires **macOS 13 Ventura or later** and Apple's Command Line Tools. If needed, install the tools with `xcode-select --install`, then:

```sh
git clone https://github.com/hrithiksaini99/Pomo.git
cd Pomo
./build.sh --install
open ~/Applications/Pomo.app
```

Click the **timer icon in your menu bar** to start a session. Allow notifications if you want completion banners. The Glass sound works independently of notification permission.

The current version is a source preview. Locally built apps are ad hoc signed. Public downloadable installers must pass the Developer ID signing and Apple notarization steps in the [release guide](general/pomodoro/docs/RELEASE.md). Development archives are explicitly labeled and are not presented as stable public installers.

## Development

Pomo has no third-party application dependencies, Xcode project, or Swift package. It compiles three source files directly with `swiftc`.

| Command | Purpose |
| --- | --- |
| `./build.sh` | Build and locally sign `dist/Pomo.app` |
| `./build.sh --universal` | Build for Apple silicon and Intel |
| `./build.sh --install` | Build and install in `~/Applications` |
| `./test.sh` | Run 33 deterministic core checks |
| `./script/build_and_run.sh` | Build and launch |
| `./script/build_and_run.sh --verify` | Build, launch, and verify the process |
| `./script/build_and_run.sh --smoke-test` | Run native menu bar and control checks |
| `./script/build_and_run.sh --logs` | Launch and stream process logs |
| `./script/build_and_run.sh --telemetry` | Launch and stream app event logs |
| `./script/build_and_run.sh --debug` | Launch under LLDB |
| `./script/package_release.sh --universal --development` | Create labeled development ZIP and DMG files with checksums |
| `swift script/generate_icon.swift` | Regenerate the original app icon and brand assets |

The native smoke test starts both timers, checks the real status item and action handlers, resets, and exits. It skips notification authorization. Smoke diagnostics are excluded from production builds signed with a distribution identity.

## Project layout

```text
general/pomodoro/
  Sources/Core.swift          # Foundation-only timing and models
  Sources/AppDelegate.swift   # Native menus, status item, and alerts
  Sources/main.swift          # Accessory application entry point
  Resources/                 # App icon and original brand assets
  Tests/main.swift            # Deterministic clock-based checks
  docs/RELEASE.md             # Signing and distribution instructions
general/website/              # Static marketing page, demo, and local fonts
script/                       # Build, package, validation, and artwork tools
.github/workflows/            # CI, website deployment, and gated releases
VERSION                       # Shared application version
```

## Timing behavior

Elapsed time comes from dates rather than counting refresh ticks. A running timer includes time asleep and alerts once after waking if it has expired. A paused timer excludes that interval. Manual changes to the system clock can affect a running session. Countdown displays round up, stopwatch displays round down, and monospaced digits keep the display stable within each format.

## Website

The marketing page is plain HTML, CSS, and JavaScript, with responsive layouts, keyboard access, reduced motion support, an interactive product preview, and self-hosted Manrope fonts. It has no analytics, cookies, forms, or third-party scripts. The [live website](https://hrithiksaini99.github.io/Pomo/) is deployed by GitHub Pages; the [website source](general/website/) remains available when Pages has not been enabled yet.

```sh
python3 -m http.server 8080 --directory general/website
```

Open `http://localhost:8080` to preview the site. For GitHub hosting, select **Settings → Pages → Build and deployment → Source → GitHub Actions** once, then run **Actions → Website → Run workflow**. The workflow publishes `general/website/` at [hrithiksaini99.github.io/Pomo](https://hrithiksaini99.github.io/Pomo/) and deploys future website changes automatically.

If **Set up Pages** fails with `Get Pages site failed` or `Not Found`, Pages has not been enabled. Enable the GitHub Actions source before rerunning the workflow; committing HTML alone does not activate hosting.

## Troubleshooting

- **Missing icon:** a notch or menu bar manager may hide it. Temporarily hide other items or Command-drag the timer into a visible spot. The smoke report includes its frame and visibility.
- **No notification banner:** check System Settings → Notifications → Pomo and Focus mode.
- **Another Mac:** build from source there, or use a properly signed and notarized public release. Do not disable Gatekeeper.

## License

Copyright © 2026 **Hrithik Saini**. Pomo and its original artwork use the [MIT license](LICENSE). Manrope is distributed under the [SIL Open Font License](general/website/fonts/OFL.txt).
