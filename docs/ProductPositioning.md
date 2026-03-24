# Product Positioning

## One-Line Product Definition

ClawNest is a macOS local OpenClaw workstation for installing the OpenClaw CLI, monitoring runtime health, and repairing a local OpenClaw runtime.

## Core Capabilities

- Install or verify the OpenClaw CLI
- Monitor local runtime health using `openclaw health --json`
- Run repair, start, and restart actions for the local runtime
- Open the local dashboard and reveal local logs
- Provide menu bar status and quick actions for the same runtime

## Explicit Non-Goals

- Becoming an AI agent platform
- Becoming a multi-instance orchestration system
- Managing remote runtimes or remote agents
- Replacing the official `openclaw onboard --install-daemon` onboarding flow
- Introducing placeholder product areas or workflows without real OpenClaw backing functionality

## Intended User

ClawNest is for a macOS user who runs OpenClaw locally and wants a native place to install or verify the CLI, inspect runtime status, and recover without living in Terminal.

## Current Scope of ClawNest

- One local OpenClaw runtime on the current Mac
- One main `Claw` workspace plus a menu bar surface
- Runtime health, diagnostics, dashboard access, local logs, and runtime settings
- Repair-oriented actions grounded in OpenClaw capabilities that exist today
- CLI installation and verification, plus explicit handoff to official onboarding for first-run setup

## Product Rule

Any new UI surface or workflow added to ClawNest must map to a real OpenClaw capability.

Do not introduce placeholder product areas (Chat, Moments, etc.) without real backing functionality.

## Scope Guardrails

- If the underlying OpenClaw capability does not exist, ClawNest should not invent a product shell for it.
- If a workflow is still manual in OpenClaw, ClawNest may guide or hand off to it, but should not claim that the app fully owns it.
- Prefer fewer honest surfaces over broader but misleading information architecture.
