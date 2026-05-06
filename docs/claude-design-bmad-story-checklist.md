# Claude Design + BMAD Story Checklist

Use this checklist for each story that originates from Claude Design work.

---

## Before Design

- [ ] PRD section exists for the feature (`create-prd` or updated PRD).
- [ ] Story objective and success metric are clear.
- [ ] Constraints are known (platform, timeline, compliance, accessibility target).

## During Claude Design

- [ ] Start with core layout first, then iterate.
- [ ] Ask for 2-3 variants before choosing a direction.
- [ ] Use chat for structural changes; inline comments for local fixes.
- [ ] Verify mobile/tablet/desktop behavior (as relevant).
- [ ] Validate accessibility expectations explicitly.
- [ ] Confirm use of existing design-system components where possible.
- [ ] Capture edge states: loading, empty, error, permission denied.

## Handoff Artifacts

- [ ] Before design work, create a Claude brief using `docs/bmad-to-claude-design-handoff-template.md`.
- [ ] After design work, convert outputs using `docs/claude-design-to-bmad-uiux-template.md`.
- [ ] Save a feature-specific UX handoff doc with `ux` in filename.
- [ ] Include links to prototype + exports + handoff bundle.
- [ ] Document chosen direction and rejected alternatives.
- [ ] Document interaction rules, copy requirements, and telemetry.

## BMAD Story Creation

- [ ] Run `create-story <epic>-<story>`.
- [ ] Ensure generated story references the UX handoff doc.
- [ ] Confirm acceptance criteria include UX behavior, states, and accessibility.
- [ ] Confirm tasks mention affected components/files.
- [ ] Resolve open UX/product questions before moving to `ready-for-dev`.

## Implementation and Review

- [ ] Implement via `dev-story` or `auto-sprint`.
- [ ] Validate output against UX handoff (not only against code assumptions).
- [ ] Run `code-review` with a different model from implementation.
- [ ] Verify visual, behavior, and accessibility acceptance cues.
- [ ] Confirm regressions for adjacent flows are checked.

## Definition of Done (Design-to-Code)

- [ ] Built UI matches approved flow and states.
- [ ] Existing components were reused unless explicitly approved otherwise.
- [ ] Accessibility target is met and documented.
- [ ] Story ACs pass and tests are green.
- [ ] Story, review notes, and artifacts are linked for traceability.

