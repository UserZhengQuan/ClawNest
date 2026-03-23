# Product Positioning

## Reference

As of March 23, 2026, ClawNest is informed by two public projects:

- [openclaw-control-center](https://github.com/TianyiDataScience/openclaw-control-center)
- [nexu](https://github.com/nexu-io/nexu)

They are useful because together they prove there is real demand for:

- better OpenClaw observability
- human-readable health status
- one place to inspect issues without living in Terminal
- a pure GUI setup path
- a desktop distribution model people can actually install and try

Their public positioning also highlights product choices worth preserving in spirit:

- local-first operation
- safety-first defaults, including read-only posture unless mutation is intentional
- double-click install instead of environment-first setup
- user-facing polish around packaging and onboarding

## Where ClawNest diverges

ClawNest is not trying to become a browser dashboard for maintainers, and it is not trying to replicate nexu's broader Electron plus controller plus web stack either.

It is a native macOS companion for ordinary operators who mostly need four things:

1. know whether OpenClaw is healthy
2. recover quickly when it is not
3. understand what failed in plain language
4. avoid touching Terminal unless the app itself cannot proceed

That pushes the product toward a much narrower surface:

- menu bar status
- one main health overview
- one diagnostics view
- one embedded dashboard shell for compatibility
- a short list of native repair actions

## Product rules

When making future feature decisions, prefer the option that reduces operator burden.

Good additions:

- setup checks
- permissions guidance
- launchd visibility
- reconnect history
- token/auth mismatch hints
- native summaries of the most common blocked states

Bad additions:

- generic admin dashboards
- large multi-page information architecture
- direct exposure of internal OpenClaw objects unless they are needed for recovery
- features that assume the user already understands sessions, relays, memory stores, or file layouts
- architecture sprawl before the user experience proves it is necessary

## UX test

Every new screen should pass this test:

"If the dashboard is disconnected and the user has zero Terminal context, can they still tell what broke and what to do next?"

If the answer is no, the feature is not aligned with ClawNest.
