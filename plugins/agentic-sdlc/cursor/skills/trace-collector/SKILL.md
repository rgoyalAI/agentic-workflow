---
name: trace-collector
description: Captures agent execution traces for observability and cost tracking. Invoked by the orchestrator after each agent completes. Writes structured trace lines to traces.jsonl and monitors session spending against the configured cap.
---

## Purpose

Agent observability and cost monitoring. Each agent completion yields a structured trace aligned with the agent trace envelope schema, plus session-level spend tracking against configured caps.

## Algorithm

1. Receive agent output, status, timing, and token usage.
2. Generate `trace_id` (UUID), attach `correlation_id` from orchestrator.
3. Write one JSON line to `./context/{story-id}/traces.jsonl`.
4. Update cumulative token spend in `./context/sdlc-session.json`.
5. Check against session spending cap: warn at 80%, pause at 100%.
6. Return trace summary (`trace_id`, `cumulative_tokens`, `budget_remaining_pct`).

## Input

- Agent name, `story_id`, status, duration, `token_usage`, `artifacts_produced`

## Output

- `trace_id`, `cumulative_tokens`, `budget_status` (`ok` / `warn` / `exceeded`)

## Safety

Never fail silently; if trace write fails, log error but don't block pipeline.
