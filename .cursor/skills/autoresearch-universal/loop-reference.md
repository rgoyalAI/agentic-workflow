# Phase 5 — Autoresearch Loop (Detailed Cycle Steps)

This is the reference for the complete cycle executed in Phase 5 of the autoresearch-universal skill.
Run this loop repeatedly without stopping or asking for permission.

---

## One Cycle

### 1. Load state from disk

Read `.autoresearch/state.json`, `.autoresearch/prompt.txt`, and the last 5 lines of `.autoresearch/results.jsonl`. Do this every cycle — never skip.

### 2. Sample items

Build the batch from two pools:

- **Validation set** (fixed): always include the items from `state.json → validation_items`. Before using each item, verify the file still exists. If a validation item was deleted or renamed, flag it to the user and pick a replacement.
- **Rotating sample**: select additional items to reach batch size N. Use coverage-first selection:
  1. Read `sampled_items` from `state.json` — this tracks all items previously sampled.
  2. Prefer items NOT in `sampled_items`. Scan the repo for eligible items the prompt hasn't been tested against yet.
  3. Only re-sample previously tested items after all eligible items have been covered at least once.
  4. Before using any rotating item, verify the file still exists. Skip deleted/renamed files silently.
  5. Append the newly selected items to `sampled_items` in `state.json`.

What constitutes an "item" depends on the target:

- For test quality: functions/methods from the codebase
- For docstrings: undocumented or poorly documented functions
- For error handling: error-prone code paths
- For docs SEO: documentation pages
- For SQL patterns: queries
- For accessibility: components

### 3. Generate outputs

Apply the current prompt to each sampled item. The output is whatever the prompt produces — test cases, documentation, refactored code, rewritten copy, etc.

### 4. Evaluate

**Eval isolation rule**: when evaluating `llm-judge` criteria, present ONLY the raw output and the criterion text to yourself. Do NOT consider the prompt that produced the output. Evaluate as if you are seeing this output for the first time with no knowledge of what it was supposed to do. This prevents author-intent bias.

For each output, evaluate against every binary criterion:

- **`llm-judge` criteria**: present only the output + criterion. Determine pass/fail. Be strict. If it is not clearly passing, it fails.
- **`command` criteria**: run the specified shell command. Exit code 0 = pass, non-zero = fail. On failure, retry once. If it passes on retry, record pass but flag `"flaky": true`.

Record pass (true) or fail (false) for each criterion on each item.

**Adversarial re-eval** (every cycle): after initial evaluation, pick 2 outputs that passed all `llm-judge` criteria and re-evaluate them with deliberately skeptical prompting: "Looking at ONLY this output with no other context — would a hostile reviewer agree this passes [criterion]?" If any flip to fail, update the scores. Apply this consistently every cycle (not intermittently) so it does not create artificial oscillation between cycles.

### 5. Score

Compute:
- Per-criterion totals (how many of N items passed each criterion)
- **Validation score** (score on just the fixed validation items — this is the apples-to-apples comparison)
- Total score (sum of all passes across all criteria, max = N x M)
- Collect failure reasons (brief description of why each failure occurred)

**Track item-level failures**: for each item that fails a criterion, increment its failure count in `state.json → item_failures` (keyed by `"item_path:criterion_name"`). If any item+criterion pair has failed 5+ times across runs, flag it in the log: "Item [path] has failed [criterion] in [N] consecutive runs — this may be an item-level issue rather than a prompt problem." Do not count flagged item+criterion failures toward the prompt's score.

### 6. Compare and keep/discard

Use the **validation score** as the primary comparison metric (not the total score, which includes rotating items that vary in difficulty).

```
IF validation_score > best_validation_score:
    AND (validation_score - best_validation_score) >= confidence_margin:
        best_score = total_score
        best_validation_score = validation_score
        Copy current prompt.txt → best_prompt.txt
        Status: KEEP
        plateau_counter = 0
ELSE:
    Copy best_prompt.txt → prompt.txt  (revert to best)
    Status: DISCARD
    plateau_counter += 1
```

**Confidence margin**: for batches of 5-7 items, require improvement of at least 2 points on the validation set. For batches of 8-10, a margin of 1 is sufficient. This prevents noise from being mistaken for progress.

### 7. Mutate

If score < max_score, mutate the prompt to improve it.

Always mutate FROM the best prompt (`best_prompt.txt`), never from a failed attempt.

**Use one of these structured mutation operators**, rotating through them across cycles:

1. **Add constraint** — for the weakest criterion, add an explicit rule or prohibition addressing the most common failure.
2. **Add negative example** — insert a "DO NOT do X" with a concrete example of a common failure you observed.
3. **Restructure** — reorder the prompt's instructions. Move the most-failed criterion's rules to the top (primacy bias). Group related rules together.
4. **Tighten language** — replace vague words ("try to", "consider", "should") with imperatives ("MUST", "ALWAYS", "NEVER"). Make fuzzy instructions concrete.
5. **Remove bloat** — identify a redundant or low-impact line and delete it. Shorter prompts at equal scores are better.
6. **Add counterexample** — for a frequently failed criterion, add a before/after example showing what passing vs. failing looks like.

Log which operator was used in the JSONL entry. Rotate through operators so each gets tried.

**Soft length guideline**: prefer shorter prompts at equal scores. If the prompt exceeds 500 words, flag it in the log as `"prompt_warning": "length"` but do not hard-block. Some targets legitimately need longer prompts.

Save the mutated prompt to `prompt.txt`.

### 8. Log

Append a JSON line to `.autoresearch/results.jsonl`:

```json
{
  "run": 1,
  "timestamp": "ISO 8601",
  "score": 0,
  "validation_score": 0,
  "max": 0,
  "criteria": {"name1": 0, "name2": 0},
  "status": "keep | discard",
  "mutation_operator": "add_constraint | add_negative_example | restructure | tighten_language | remove_bloat | add_counterexample | plateau_break",
  "prompt_len": 0,
  "prompt_text": "full text of the prompt used this run",
  "failures": ["brief failure 1", "brief failure 2"],
  "items_flagged": ["item:criterion pairs flagged as item-level issues"],
  "flaky_commands": ["commands that passed on retry"]
}
```

Update `state.json` with new `run_number`, `best_score`, `best_validation_score`, `plateau_counter`, `sampled_items`, and `item_failures`.

### 9. Criteria health check (at run 10)

At run 10, re-read `.autoresearch/results.jsonl` from disk and review all criteria across runs 1-10:

- **Too easy**: any criterion at 100% pass rate since run 1 is not discriminating. Flag it to the user: "Criterion X has passed every run — consider replacing it with something harder or dropping it."
- **Too hard**: any criterion that has never exceeded 20% may be unreasonable or outside what prompt engineering can fix. Flag it: "Criterion Y has never cracked 20% — it may need rewording or may require code changes rather than prompt changes."

**Do not pause the loop for flags.** Log them, print them in the report, and keep running. The user will see them when they check in and can adjust criteria at that point. If the user later provides updated criteria, incorporate them into the next cycle.

### 10. Report

Print the cycle summary using the format defined in SKILL.md (Phase 5 → Cycle report format).

### 11. Plateau breaker

If `plateau_counter` reaches 5 (5 consecutive runs with no improvement):

1. Do NOT mutate from the best prompt.
2. Instead, re-read the last 10 entries from `.autoresearch/results.jsonl` and write a completely new prompt from scratch using ONLY:
   - The target description
   - The eval criteria
   - The accumulated failure patterns from those 10 entries
3. Ignore the current best prompt's structure entirely. Fresh start with memory.
4. Log with `"mutation_operator": "plateau_break"`.
5. Reset `plateau_counter` to 0.

This is the equivalent of a restart with memory — same destination, different path.

### 12. Continue

Go back to step 1. Do not stop. Do not ask "should I continue?" The user will interrupt you when they want you to stop.
