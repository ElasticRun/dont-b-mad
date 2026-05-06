---
stepsCompleted: []
inputDocuments: []
---

# Claude Design -> BMAD UI/UX Handoff Template

Use this template to convert Claude Design output into BMAD UX specification format.

Recommended save location in project artifacts:
- `{planning_artifacts}/ux-design-specification.md` (or a feature-specific `*ux*.md` file)

---

## 1) Source Capture

- Claude Design project link:
- Shared review link:
- Export artifacts location:
- Related BMAD story key(s):
- Related PRD/architecture sections:

## 2) Discovery Summary (BMAD step: discovery)

- User segments addressed:
- Primary and secondary use cases:
- Main usability challenges discovered:
- Context assumptions:

## 3) Core Experience (BMAD step: core experience)

- Experience north star:
- Primary user tasks:
- Success criteria for user interaction:
- Information hierarchy principles:

## 4) Emotional Response Goals (BMAD step: emotional response)

- Target emotions:
- Moments that build trust/confidence:
- Friction-reduction choices:
- Error-recovery experience goals:

## 5) Design Inspirations and References (BMAD step: inspiration)

- Internal references:
- External references:
- Patterns adopted:
- Patterns explicitly avoided:

## 6) Design System Mapping (BMAD step: design system)

| Need | Existing component/token | New element? | Notes |
|---|---|---|---|
| ... | ... | yes/no | ... |

- Typography scale decisions:
- Color and semantic token usage:
- Spacing/rhythm system:

## 7) Experience Definition (BMAD step: defining experience)

- Navigation model:
- Page/screen hierarchy:
- Entry and exit points:
- Permission/role differences:

## 8) Visual Foundation (BMAD step: visual foundation)

- Layout grid strategy:
- Density strategy:
- Visual hierarchy strategy:
- Iconography/illustration guidance:

## 9) Design Directions and Final Choice (BMAD step: design directions)

| Direction | Summary | Pros | Cons | Decision |
|---|---|---|---|---|
| A | ... | ... | ... | keep/reject |
| B | ... | ... | ... | keep/reject |
| C | ... | ... | ... | keep/reject |

- Final direction selected:
- Rationale:

## 10) User Journeys (BMAD step: user journeys)

### Journey 1: [name]
- Trigger:
- Steps:
  1. ...
  2. ...
  3. ...
- Success outcome:
- Edge cases:
- Failure states:

## 11) Component Strategy (BMAD step: component strategy)

- Reusable components:
- Variant strategy:
- Composition rules:
- Interaction contracts (hover/focus/disabled/loading):

## 12) UX Patterns and Interaction Rules (BMAD step: UX patterns)

- Form patterns:
- Table/list patterns:
- Search/filter/sort patterns:
- Confirmation/destructive action patterns:
- Notification/feedback patterns:

## 13) Responsive and Accessibility Spec (BMAD step: responsive/accessibility)

- Breakpoints and adaptations:
- Mobile interaction notes:
- Keyboard navigation map:
- Focus management:
- ARIA/screen reader behavior:
- Contrast and readability checks:

## 14) Screen/State Inventory for Implementation

| Screen | Default | Loading | Empty | Error | Permissions |
|---|---|---|---|---|---|
| ... | yes/no | yes/no | yes/no | yes/no | ... |

## 15) AC Traceability to BMAD Stories

| Story/AC | Design evidence (where visible) | Notes for implementation |
|---|---|---|
| 1-2 / AC-1 | ... | ... |
| 1-2 / AC-2 | ... | ... |

## 16) Build Handoff Notes for `create-story` / `dev-story`

- Files/components likely impacted:
- Data contracts assumed:
- Test scenarios implied by UX:
- Risks and mitigations:
- Open questions:

## 17) Ready-for-Dev Checklist

- [ ] Flows are complete and unambiguous
- [ ] States (default/loading/empty/error) are fully covered
- [ ] Accessibility and responsiveness are explicit
- [ ] Component reuse/new build decisions are explicit
- [ ] Story AC traceability is complete

# Claude Design -> BMAD UI/UX Handoff Template

Use this when bringing approved Claude Design output back into BMAD's UX/UI artifact format.

Suggested file name in planning artifacts:
- `{planning_artifacts}/ux-{feature-slug}.md`

---

## 1) Handoff Metadata

- Feature name:
- Epic/story reference:
- Author:
- Date:
- Status: draft | approved | ready-for-dev

## 2) Claude Design References

- Claude Design project URL:
- Shared review URL:
- Export artifacts (zip/html/pdf/pptx):
- Claude Code handoff bundle path:
- Version/tag reviewed:

## 3) Final Direction Summary

- Chosen concept:
- Why selected:
- Tradeoffs accepted:
- Rejected alternatives and reasons:

## 4) User Journey and Flows

### Flow: [name]
- Trigger:
- Happy path:
  1. ...
  2. ...
- Edge path(s):
  - ...
- Failure path(s):
  - ...
- Exit condition:

## 5) Screen-State Matrix

| Screen / View | Default | Loading | Empty | Error | Permission | Notes |
|---|---|---|---|---|---|---|
| ... | yes/no | yes/no | yes/no | yes/no | yes/no | ... |

## 6) UI Component Specification

| UI part | Component to use | Variant | New component? | Notes |
|---|---|---|---|---|
| Primary action | `Button/Primary` | default | no | ... |
| Filter controls | `Select` / `Chips` | compact | no | ... |
| Timeline | n/a | n/a | yes | ... |

## 7) Interaction and Logic Rules

- Input validation:
- Field defaults:
- Sorting/filtering:
- Pagination/scrolling:
- Confirmation/destructive actions:
- Keyboard behavior:

## 8) Content Specification

- Headline/title copy:
- Primary CTA labels:
- Empty state copy:
- Error message format:
- Helper/tool-tip copy:

## 9) Accessibility and Responsive Requirements

- Accessibility target (for example, WCAG 2.1 AA):
- Focus order and focus visibility:
- Keyboard navigation paths:
- Contrast requirements:
- Screen reader labels/announcements:
- Breakpoints:
- Touch target minimum:

## 10) Engineering Handoff Cues

- Likely files/components impacted:
- Backend/API dependencies:
- Data assumptions:
- Performance expectations:
- Telemetry events and payload fields:
- Test scenarios required:

## 11) Acceptance Criteria Mapping

| Story AC | Design evidence | Implementation note |
|---|---|---|
| AC-1 | [link/section] | ... |
| AC-2 | [link/section] | ... |
| AC-3 | [link/section] | ... |

## 12) Ready-for-Dev Gate

- [ ] Flows finalized
- [ ] States finalized
- [ ] Component mapping finalized
- [ ] Accessibility requirements explicit
- [ ] AC-to-design mapping complete
- [ ] Open questions resolved or tracked

