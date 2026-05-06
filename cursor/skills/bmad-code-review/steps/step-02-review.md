---
failed_layers: '' # set at runtime: comma-separated list of layers that failed or returned empty
deep_review: '' # set at runtime: true if user requested adversarial Blind Hunter pass
---

# Step 2: Review

## RULES

- YOU MUST ALWAYS SPEAK OUTPUT in your Agent communication style with the config `{communication_language}`
- Edge Case Hunter is the default reviewer (diff + project read access).
- Acceptance Auditor runs when a spec is available (diff + spec + context docs).
- Blind Hunter is **opt-in only** — runs when the user explicitly asks for an adversarial / blind / deep review.

## INSTRUCTIONS

1. **Detect `{deep_review}` intent.** Scan the user's original review request (and any clarifications given before this step) for keywords: `deep review`, `blind`, `adversarial`, `thorough review`, `paranoid`. If any match, set `{deep_review}` = `true`. Otherwise set `{deep_review}` = `false`.

2. If `{review_mode}` = `"no-spec"`, note to the user: "Acceptance Auditor skipped — no spec file provided."

3. If `{deep_review}` = `false`, note to the user: "Blind Hunter skipped — invoke with 'deep review' / 'blind' / 'adversarial' to enable the diff-only adversarial pass."

4. Launch parallel subagents without conversation context. If subagents are not available, generate prompt files in `{implementation_artifacts}` — one per reviewer role below — and HALT. Ask the user to run each in a separate session (ideally a different LLM) and paste back the findings. When findings are pasted, resume from this point and proceed to step 3.

   - **Edge Case Hunter** (default) — receives `{diff_output}` and read access to the project. Invoke via the `bmad-review-edge-case-hunter` skill.

   - **Acceptance Auditor** (only if `{review_mode}` = `"full"`) — receives `{diff_output}`, the content of the file at `{spec_file}`, and any loaded context docs. Its prompt:
     > You are an Acceptance Auditor. Review this diff against the spec and context docs. Check for: violations of acceptance criteria, deviations from spec intent, missing implementation of specified behavior, contradictions between spec constraints and actual code. Output findings as a Markdown list. Each finding: one-line title, which AC/constraint it violates, and evidence from the diff.

   - **Blind Hunter** (only if `{deep_review}` = `true`) — receives `{diff_output}` only. No spec, no context docs, no project access. Invoke via the `bmad-review-adversarial-general` skill.

5. **Subagent failure handling**: If any subagent fails, times out, or returns empty results, append the layer name to `{failed_layers}` (comma-separated) and proceed with findings from the remaining layers.

6. Collect all findings from the completed layers.


## NEXT

Read fully and follow `./step-03-triage.md`
