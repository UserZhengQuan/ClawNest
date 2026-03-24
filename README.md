# ClawNest

ClawNest is a macOS local OpenClaw workstation for installing the OpenClaw CLI, monitoring runtime health, and repairing a local OpenClaw runtime.

## Product Positioning

ClawNest is a native control surface for one local OpenClaw runtime on the current Mac.
It sits on top of the existing OpenClaw CLI, launchd job, dashboard, and logs, and gives users one place to check status and recover when the runtime is unhealthy.

## Core Capabilities

- Install or verify the OpenClaw CLI
- Check local runtime health with `openclaw health --json`
- Run local recovery actions: start, restart, and `openclaw doctor --repair --non-interactive`
- Open the local dashboard and reveal local OpenClaw logs
- Show status and quick actions from the menu bar

## Not Included in This Version

- Multi-instance OpenClaw management or provisioning
- Remote runtime or remote agent management
- In-app workspace/gateway/launchd onboarding beyond handing off to `openclaw onboard --install-daemon`
- Chat, feed, or placeholder product areas without real backing functionality
- Multi-Claw orchestration or agent-platform behavior

## Current Scope

- One `Claw` workspace for the current local OpenClaw runtime
- One menu bar surface for the same runtime
- Runtime health, diagnostics, dashboard access, local logs, and runtime settings
- Official CLI install/check flow plus explicit handoff to official onboarding

Detailed scope and product rules are documented in [docs/ProductPositioning.md](docs/ProductPositioning.md).

## Run Locally

```bash
swift run ClawNest
```

Or open the package in Xcode and run the `ClawNest` executable target.

## Build an App Bundle

```bash
./scripts/package_clawnest.sh
```

That script builds a release binary, wraps it in `dist/ClawNest.app`, applies ad-hoc signing for local use, and writes `dist/ClawNest.zip` for easy sharing.
It also syncs both files to `~/Downloads` so the latest test build is easy to find.

## License

ClawNest is released under the MIT License. See [LICENSE](LICENSE).

## Default Assumptions

- OpenClaw CLI is available on `PATH` as `openclaw`
- Local dashboard runs on `http://127.0.0.1:18789/`
- LaunchAgent label is `ai.openclaw.gateway`
- Logs are written under `/tmp/openclaw`

All of those can be changed from the local runtime settings inside the app.

## Third-Party Reference and License Note

We currently reference [openclaw-control-center](https://github.com/TianyiDataScience/openclaw-control-center) and [nexu](https://github.com/nexu-io/nexu) as product inspiration only.

As of March 23, 2026, both GitHub repositories are marked as MIT-licensed. If ClawNest only borrows ideas and does not copy code, assets, or substantial text from those projects, MIT normally does not require us to ship their license text inside this repo. If we later copy any code or bundled assets from either repo, we should preserve the relevant MIT copyright notice and license text for the copied material.

See [docs/ThirdPartyReferences.md](docs/ThirdPartyReferences.md).
