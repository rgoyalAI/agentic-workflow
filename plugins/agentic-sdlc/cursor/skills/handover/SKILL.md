---
name: handover
description: Detects context window saturation and executes the Two-Artifact Handover Protocol. Monitors agent context usage, triggers handover when approaching limits, produces Handover File and Handover Prompt, and coordinates agent role transfer.
---

## Purpose

Preserve continuity when an agent instance can no longer hold the full working context in memory. The orchestrator (or the agent under policy) detects saturation or quality decay, then materializes state into durable artifacts so a fresh instance can resume the same role without redoing completed work. This aligns with an APM-inspired two-artifact pattern: a **Handover File** (facts, warnings, in-progress files) and a **Handover Prompt** (ordered reading list, position in workflow, constraints).

## Detection Algorithm

1. **Context usage**: Track estimated context consumption (tokens or provider-reported usage). If usage exceeds a configurable threshold (for example 75–85% of the effective window for the role), flag `context_saturation`.
2. **Decay signs**: If repeated mistakes appear (contradicting earlier decisions, re-introducing fixed bugs, ignoring stated constraints), or output quality drops versus prior Memory Logs, flag `quality_decay`.
3. **Escalation**: When either flag is true, do not continue deep implementation; initiate handover execution below.

## Handover Execution

1. Instantiate from `./templates/handover-file.md`; fill YAML frontmatter (`agent_role`, `handover_number`, `story_id`, `reason`, `created_at`).
2. Complete all sections: current state, undocumented insights, patterns, user preferences, known issues, files in progress, warnings.
3. Write the file to `./memory/handovers/{{AGENT_ROLE}}-handover-{{N}}.md` (create directory if needed).
4. Instantiate from `./templates/handover-prompt.md`; substitute placeholders and save adjacent to runbooks or pass to the successor session.
5. Update `./memory/session-root.md` or story-level logs to record that handover {{N}} occurred and the successor should start from the Handover Prompt.
6. Successor reads in the order specified in the Handover Prompt, summarizes state, obtains human approval if required, then continues from the recorded step.

## Workload Split

If **more than three** handovers occur for the same `agent_role` and `story_id`, treat this as a structural signal: the role may be too large for one context window. Recommend splitting work (sub-stories, narrower file ownership, or a dedicated “integration” pass) and record the recommendation in the Session Root or story plan.

## Safety

- Never omit “Warnings for Successor” or partially complete files from the Handover File.
- Do not mark work complete in Memory Logs if it was only summarized in the handover; the successor must verify.
- Redact secrets, tokens, and credentials from all handover artifacts.
- The Handover Prompt must forbid redoing work already completed and modifying files listed as complete in the Handover File.
