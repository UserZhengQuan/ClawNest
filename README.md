# ClawNest

ClawNest is a recovery-first macOS desktop client for OpenClaw.

It is built around two specific operator problems:

1. OpenClaw is too easy to knock into a bad local state, so users end up babysitting the terminal.
2. When the dashboard disconnects, diagnosis is opaque and recovery is too manual.

## Product direction

ClawNest treats the existing OpenClaw CLI and Gateway as the runtime, then adds a native control layer on top:

- Menu bar presence for instant status and recovery actions
- A health loop backed by `openclaw health --json`
- Observe-only monitoring by default, with opt-in auto-restart if the user wants managed recovery
- One-click OpenClaw installation that uses the official installer, writes an isolated instance layout, and reserves a unique gateway port
- One-click repair actions for install, restart, and `doctor --repair`
- In-app diagnostics with recent command history and the latest OpenClaw log tail
- An embedded dashboard surface, so the web UI is no longer the only place you can understand failures

This is intentionally different from a thin browser wrapper. The native app owns the operational experience.

## Reference study

We are using [openclaw-control-center](https://github.com/TianyiDataScience/openclaw-control-center) and [nexu](https://github.com/nexu-io/nexu) as product references, not as implementation templates.

What we want to borrow:

- clear health and operator summaries instead of raw backend noise
- safe recovery defaults and explicit repair actions
- one local place to answer: "Is OpenClaw okay right now?"
- true desktop distribution with graphical setup instead of "read docs, export vars, and pray"
- a product standard where double-click install is considered the baseline, not a stretch goal

What we explicitly do not want to copy:

- a browser-first architecture
- a maintainer-heavy control surface with too many sections for ordinary users
- file-editing and system-management concepts shown before the user even regains a healthy session
- a large Electron/controller/web stack unless a native implementation clearly cannot cover the use case

The detailed product position is documented in [docs/ProductPositioning.md](docs/ProductPositioning.md).

## Current MVP

- SwiftUI macOS app entry point
- Menu bar quick actions
- Health probe interpreter with loose JSON parsing
- Gateway supervisor actor
- UserDefaults-backed runtime configuration
- One-click OpenClaw installer with directory selection and port-conflict checks
- Embedded WebKit dashboard shell
- Diagnostics and latest-log panels
- Unit tests for health interpretation

## Run locally

```bash
swift run ClawNest
```

Or open the package in Xcode and run the `ClawNest` executable target.

## Build an app bundle

```bash
./scripts/package_clawnest.sh
```

That script builds a release binary, wraps it in `dist/ClawNest.app`, applies ad-hoc signing for local use, and writes `dist/ClawNest.zip` for easy sharing.
It also syncs both files to `~/Downloads` so the latest test build is easy to find.

## License

ClawNest is released under the MIT License. See [LICENSE](LICENSE).

## Default assumptions

- OpenClaw CLI is available on `PATH` as `openclaw`
- Local dashboard runs on `http://127.0.0.1:18789/`
- LaunchAgent label is `ai.openclaw.gateway`
- Logs are written under `/tmp/openclaw`

All of those can be changed from the Diagnostics tab inside the app.

## Third-party reference and license note

We currently reference [openclaw-control-center](https://github.com/TianyiDataScience/openclaw-control-center) and [nexu](https://github.com/nexu-io/nexu) as product inspiration only.

As of March 23, 2026, both GitHub repositories are marked as MIT-licensed. If ClawNest only borrows ideas and does not copy code, assets, or substantial text from those projects, MIT normally does not require us to ship their license text inside this repo. If we later copy any code or bundled assets from either repo, we should preserve the relevant MIT copyright notice and license text for the copied material.

See [docs/ThirdPartyReferences.md](docs/ThirdPartyReferences.md).

## Next milestones

- Replace the embedded dashboard for the top 20% of workflows with native views
- Add onboarding for CLI installation and first-run checks
- Sync dashboard auth/token state so reconnects are seamless
- Add structured crash reporting and launch history
