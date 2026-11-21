# Widgets Pro

A native macOS menu bar app and desktop widget that show CPU and memory usage, written in Swift.

- **Menu bar icon** with the current CPU %. Click it to see:
  - CPU and memory bars plus a chart of the last 2 minutes
  - **Top apps**: CPU usage per app, sub-processes included
  - **Process tree**: parent → child processes, with CPU and memory for each branch
- **Desktop / Notification Center widget** (small and medium) showing CPU and memory

Requires macOS 14+. No Xcode needed: the Command Line Tools are enough.

## Build and run

```sh
./build.sh            # ad-hoc signed, build/release/WidgetsPro.app
open build/release/WidgetsPro.app
```

For the widget to show up in the widget gallery, sign with your own Apple Development identity and copy the app to `/Applications`:

```sh
SIGN_ID="Apple Development: Your Name (XXXXXXXXXX)" TEAM_ID=YOURTEAMID ./build.sh
cp -R build/release/WidgetsPro.app /Applications/ && open /Applications/WidgetsPro.app
```

Then right-click the desktop → **Edit Widgets** → **Widgets Pro**.

## Layout

| path | what |
|---|---|
| `Shared/SystemStats.swift` | system CPU and memory (Mach host APIs, works inside the sandbox) |
| `Shared/ProcessTree.swift` | per-process CPU and memory via libproc, parent/child tree |
| `App/` | menu bar app (SwiftUI `MenuBarExtra`, Swift Charts) |
| `Widget/` | WidgetKit extension |
| `build.sh` | builds and signs the app and the `.appex` with `swiftc` + `codesign` |

## Contributing

PRs go to the `development` branch. See [CONTRIBUTING.md](CONTRIBUTING.md). Commits need a DCO sign-off (`git commit -s`).

## License

[MIT](LICENSE)
