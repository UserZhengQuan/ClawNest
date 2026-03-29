# ClawNest

ClawNest is a minimal macOS menu bar control panel for one local OpenClaw runtime.

It is not an installer, not a multi-instance manager, and not a remote control platform. It is a small native wrapper around the local OpenClaw CLI so you can check status, open chat, and run a few official control actions from the menu bar.

## What It Does

- Shows the current local OpenClaw status in the macOS menu bar
- Displays the default local gateway, root path, config path, and logs path
- Runs a small set of official actions: `Open Chat`, `Refresh`, `Start`, `Restart`, `Stop`, `Repair`
- Shows the most recent command result in a separate output window with command, timestamps, exit code, stdout, and stderr

## Product Boundaries

ClawNest intentionally stays narrow:

- One local OpenClaw runtime on the current Mac
- One menu bar surface
- Default local gateway assumptions
- Official CLI-driven actions only

ClawNest does not try to be:

- An OpenClaw installer or onboarding replacement
- A multi-instance or multi-profile runtime manager
- A remote monitoring or remote operations system
- A custom WebView chat shell
- A generic OpenClaw workstation with broad settings and diagnostics

## Official Commands Used

The current menu actions map to these commands and behaviors:

- `Open Chat` opens `http://127.0.0.1:18789/` with the system browser
- `Refresh` re-reads local status
- `Start` runs `openclaw gateway start`; if the CLI explicitly says the managed service is not loaded yet, ClawNest runs `openclaw gateway install` and retries the official start
- `Restart` runs `openclaw gateway restart`
- `Stop` runs `openclaw gateway stop`
- `Repair` runs `openclaw doctor --fix`

## Default Assumptions

This version is intentionally opinionated and local-first:

- Gateway URL: `http://127.0.0.1:18789/`
- OpenClaw root path: `~/.openclaw`
- Config path: `~/.openclaw/openclaw.json`
- Logs path: `~/.openclaw/logs`
- OpenClaw CLI command: `openclaw`

## Run Locally

```bash
swift run ClawNest
```

Or open the package in Xcode and run the `ClawNest` executable target.

## Build an App Bundle

```bash
./scripts/package_clawnest.sh
```

That script builds a release binary, wraps it in `dist/ClawNest.app`, applies ad-hoc signing for local use, creates `dist/ClawNest.zip`, and syncs both files to `~/Downloads`.

## License

ClawNest is released under the MIT License. See [LICENSE](LICENSE).
