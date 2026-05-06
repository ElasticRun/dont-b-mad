# BMAD -> Claude Design Handoff

## 1) Handoff Metadata
- Feature:
- Epic / Story:
- Prepared by:
- Date:
- Linked BMAD artifacts:
  - PRD:
  - Architecture:
  - Epics/Stories:
  - Existing UX doc (if any):

## 2) Product Intent (from BMAD)
- Problem statement:
- Target user(s):
- Primary job-to-be-done:
- Desired user outcome:
- Business outcome:

## 3) Scope for This Design Pass
- In scope:
  - ...
- Out of scope:
  - ...
- Non-goals:
  - ...

## 4) Functional Requirements to Visualize
- FR-1:
- FR-2:
- FR-3:

## 5) Key User Flows to Design
| Flow | Trigger | Happy path outcome | Edge/failure states required |
|---|---|---|---|
| ... | ... | ... | ... |

## 6) Architecture and Data Constraints
- API/data dependencies:
- State and loading constraints:
- Error handling constraints:
- Performance constraints:
- Platform constraints:

## 7) Design System and UI Constraints
- Existing design system tokens/components to reuse:
- Components that already exist in codebase:
- Components that may be net-new:
- Brand constraints:

## 8) Accessibility and Responsiveness Requirements
- Accessibility target:
- Keyboard expectations:
- Screen reader expectations:
- Contrast and typography constraints:
- Breakpoints required:

## 9) Acceptance Criteria to Preserve
- AC-1:
- AC-2:
- AC-3:

## 10) Review Expectations
- Ask Claude Design for 2-3 layout alternatives first.
- Include default, loading, empty, and error states.
- Explain tradeoffs for chosen direction.
- Flag requirement/constraint conflicts.

## 11) Prompt for Claude Design
```text
Design a production-realistic prototype for this feature.

Context:
- Product: [name]
- Users: [persona]
- Goal: [job to be done]
- Scope: [in-scope list]
- Non-goals: [non-goals]

Requirements to satisfy:
[paste FRs and ACs]

Flows to include:
[paste key flows and outcomes]

Constraints:
- Architecture/data: [constraints]
- Existing components to reuse: [list]
- Accessibility: [target and requirements]
- Responsiveness: [breakpoints/devices]

Output requested:
1) 2-3 distinct layout directions
2) recommended direction with tradeoffs
3) full flow coverage with default/loading/empty/error states
4) component mapping to existing design system
5) implementation notes and risks
```

