---
name: ad-hoc-delegate
description: Spawns disposable specialist agents for unresolvable blockers within a single phase. Prevents debugging spirals by delegating to a cheap/fast model with isolated context. The ad-hoc agent's context is discarded after returning findings.
---

## Purpose

When the primary agent hits a localized blocker (build error, unclear API, flaky test) after reasonable attempts, delegate to a **short-lived** specialist with **minimal** context. The goal is root-cause analysis and a concrete fix path without expanding the main thread’s context or persisting throwaway reasoning.

## Algorithm

1. **Detect blocker**: After **two failed attempts** at the same issue (or one attempt with high confidence failure), classify the blocker type (e.g., `build`, `test`, `dependency`, `platform`).
2. **Produce delegation prompt**: Fill `./templates/delegation-prompt.md` with `BLOCKER_TYPE`, requesting agent, story, phase, attempt count, problem, repro, tried approaches, files, and expected output.
3. **Spawn ad-hoc agent**: Invoke a fast/cheap model tier with only the delegation prompt and files strictly needed to reproduce (no full repo history unless required).
4. **Collect findings**: Require structured return: root cause, fix or workaround, and file-level change list.
5. **Terminate**: Merge actionable results into the primary agent’s Memory Log or next step; **discard** the ad-hoc session—do not treat it as authoritative project memory.

## Input

- Blocker classification and filled delegation template (from `./templates/delegation-prompt.md`).
- Minimal attachments: logs, stack traces, and the smallest set of file paths to reproduce.

## Output

- Structured findings consumable by the requesting agent: root cause summary, recommended fix, and explicit file edits.
- Optional one-line note in the primary Memory Log under “Key Decisions” citing that ad-hoc delegation was used (without copying disposable chain-of-thought).

## Safety

- **Never persist ad-hoc context** as project truth: no new canonical docs solely from the disposable pass unless reviewed by the primary workflow.
- **Always discard** the ad-hoc agent’s scratch state after handoff; do not append raw ad-hoc transcripts to Session Root.
- Do not paste secrets into delegation prompts; redact tokens and credentials.
- Keep delegation scope narrow; reject scope creep in the ad-hoc response.
