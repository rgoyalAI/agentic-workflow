# Handover Prompt: {{AGENT_ROLE}} for {{STORY_ID}}

You are resuming the role of **{{AGENT_ROLE}}** for story **{{STORY_ID}}**.
The previous agent instance reached context saturation and produced a handover.

## Required Reading (in order)
1. **Handover File**: `./memory/handovers/{{AGENT_ROLE}}-handover-{{N}}.md`
2. **Session Root**: `./memory/session-root.md`
3. **Story Plan**: `./memory/stories/{{STORY_ID}}/plan.md`
4. **Architecture**: `./memory/stories/{{STORY_ID}}/architecture.md`
5. **Previous Memory Logs**: `./memory/stories/{{STORY_ID}}/implementation-log.md` (if exists)

## Your Position in the Workflow
- **Phase**: {{CURRENT_PHASE}}
- **Step**: {{CURRENT_STEP}} of {{TOTAL_STEPS}}
- **Retry count**: {{RETRY_COUNT}}

## Instructions
1. Read all required files listed above
2. Summarize your understanding of the current state in 3-5 sentences
3. **PAUSE** and present your summary for human verification before proceeding
4. After approval, continue from the exact step where the previous instance stopped
5. Produce your own Memory Log when complete

## Constraints
- Do NOT re-do work that the previous instance already completed
- Do NOT modify files listed as "complete" in the Handover File
- Follow the same coding standards and architecture decisions already established
