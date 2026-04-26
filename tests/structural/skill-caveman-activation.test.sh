#!/usr/bin/env bash
# SDLC skills must activate caveman mode at the start of their workflow.
# Long workflows (PRD, architecture, story, dev-story, etc.) generate a lot
# of output, so they're configured to invoke `dontbmad-caveman` first to
# keep things terse without sacrificing technical substance.
#
# This test pins that contract: every SDLC skill's workflow.md mentions
# `dontbmad-caveman`, and the directive exists in both claude/ and cursor/
# trees (mirror parity).

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/../lib/assert.sh"

# SDLC skills that produce long-running output and should run in caveman.
# Matches the set used by tests/structural/skill-ai-phase.test.sh.
SDLC_SKILLS=(
  bmad-create-prd
  bmad-edit-prd
  bmad-create-architecture
  bmad-create-ux-design
  bmad-create-epics-and-stories
  bmad-sprint-planning
  bmad-create-story
  bmad-dev-story
  bmad-quick-dev
  bmad-qa-generate-e2e-tests
  bmad-code-review
)

test_each_sdlc_workflow_invokes_caveman() {
  local skill tree wf
  for tree in claude/skills cursor/skills; do
    for skill in "${SDLC_SKILLS[@]}"; do
      wf="$REPO_ROOT/$tree/$skill/workflow.md"
      if [ ! -f "$wf" ]; then
        _fail "$tree/$skill/workflow.md exists" "missing $wf"
        continue
      fi
      if grep -q 'dontbmad-caveman' "$wf"; then
        _pass "$tree/$skill: workflow invokes dontbmad-caveman"
      else
        _fail "$tree/$skill: workflow invokes dontbmad-caveman" \
              "no 'dontbmad-caveman' reference found in $wf"
      fi
    done
  done
}

# The directive should sit near the top of the workflow (within the first
# ~10 lines) so caveman activates before any heavy work begins.
# Per-skill intensity. dev-story and code-review produce the heaviest
# output (full code + tests; structured triage of every finding) so they
# run at `ultra`. Everything else stays at `lite` to keep nuance.
declare -a INTENSITY_MAP=(
  "bmad-create-prd|lite"
  "bmad-edit-prd|lite"
  "bmad-create-architecture|lite"
  "bmad-create-ux-design|lite"
  "bmad-create-epics-and-stories|lite"
  "bmad-sprint-planning|lite"
  "bmad-create-story|lite"
  "bmad-dev-story|ultra"
  "bmad-quick-dev|lite"
  "bmad-qa-generate-e2e-tests|lite"
  "bmad-code-review|ultra"
)

test_intensity_per_skill() {
  local entry skill expected tree wf
  for entry in "${INTENSITY_MAP[@]}"; do
    skill="${entry%%|*}"
    expected="${entry##*|}"
    for tree in claude/skills cursor/skills; do
      wf="$REPO_ROOT/$tree/$skill/workflow.md"
      [ -f "$wf" ] || continue
      if grep -q "($expected intensity)" "$wf"; then
        _pass "$tree/$skill: caveman intensity = $expected"
      else
        local actual; actual=$(grep -oE '\(([a-z]+) intensity\)' "$wf" | head -1)
        _fail "$tree/$skill: caveman intensity = $expected" "found ${actual:-no intensity}"
      fi
    done
  done
}

test_caveman_directive_appears_near_top() {
  local skill tree wf line
  for tree in claude/skills cursor/skills; do
    for skill in "${SDLC_SKILLS[@]}"; do
      wf="$REPO_ROOT/$tree/$skill/workflow.md"
      [ -f "$wf" ] || continue
      line=$(grep -n 'dontbmad-caveman' "$wf" | head -1 | cut -d: -f1)
      if [ -n "$line" ] && [ "$line" -le 12 ]; then
        _pass "$tree/$skill: caveman directive on line $line (early)"
      else
        _fail "$tree/$skill: caveman directive on early line (<=12)" \
              "found on line ${line:-not found}"
      fi
    done
  done
}

run_test test_each_sdlc_workflow_invokes_caveman
run_test test_intensity_per_skill
run_test test_caveman_directive_appears_near_top
finish
