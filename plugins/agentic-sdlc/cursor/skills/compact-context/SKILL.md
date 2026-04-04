---
name: compact-context
description: Summarizes earlier phase outputs into a condensed "state of play" before passing to later phases. Reduces full implementation diffs (50K+ tokens) to structured summaries (5K tokens) for downstream agents like documentation and quality gate.
---

## Purpose

Context compaction for the SDLC workflow to prevent context window overflow. Downstream phases (documentation, quality gate, and similar) receive a bounded, structured summary instead of raw large artifacts.

## Algorithm

1. Read the source artifact (e.g., implementation-log.md, review findings, test results).
2. Extract key sections: Execution Summary, File Manifest, Key Decisions, findings summary.
3. Compress to target token budget (configurable, default 5000 tokens).
4. Preserve: all file paths, all finding IDs (CODE-x, ARCH-x, SEC-x), all pass/fail verdicts.
5. Remove: full code snippets, verbose reasoning, repeated context.
6. Write compacted output to `./context/{story-id}/compacted/{source-name}-summary.md`.

## Input

- Source file path
- Target token budget (optional; default 5000 tokens)

## Output

- Compacted summary file path under `./context/{story-id}/compacted/`

## Safety

Never discard finding IDs or pass/fail verdicts during compaction.
