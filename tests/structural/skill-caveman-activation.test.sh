#!/usr/bin/env bash
# Caveman mode is now global: the install script injects it into ~/.claude/CLAUDE.md
# and ~/.cursor/rules/dontbmad-caveman.md rather than activating it per-skill.
#
# This test pins that contract:
#   1. templates/dontbmad-caveman-global.md exists with required content
#   2. install.sh references inject_global_caveman
#   3. No SDLC workflow.md files contain an inline caveman directive (they're clean)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/../lib/assert.sh"

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

test_global_template_exists() {
  local tmpl="$REPO_ROOT/templates/dontbmad-caveman-global.md"
  if [ -f "$tmpl" ]; then
    _pass "templates/dontbmad-caveman-global.md exists"
  else
    _fail "templates/dontbmad-caveman-global.md exists" "file missing"
    return
  fi

  for phrase in "NEVER say" "Let me X" "BMAD deliverables" "dontbmad-caveman"; do
    if grep -q "$phrase" "$tmpl"; then
      _pass "global template contains: $phrase"
    else
      _fail "global template contains: $phrase" "phrase not found"
    fi
  done
}

test_install_injects_globally() {
  local install="$REPO_ROOT/scripts/install.sh"
  if grep -q "inject_global_caveman" "$install"; then
    _pass "install.sh defines/calls inject_global_caveman"
  else
    _fail "install.sh defines/calls inject_global_caveman" "function not found"
  fi

  if grep -q "dontbmad-caveman-global.md" "$install"; then
    _pass "install.sh references dontbmad-caveman-global.md template"
  else
    _fail "install.sh references dontbmad-caveman-global.md template" "reference not found"
  fi

  if ! grep -q "dontbmad-caveman-activate.md" "$install"; then
    _pass "install.sh does not copy workspace caveman-activate rule (global only)"
  else
    _fail "install.sh does not copy workspace caveman-activate rule" \
          "dontbmad-caveman-activate.md still referenced — remove from workspace rules list"
  fi
}

test_no_inline_caveman_in_workflows() {
  local skill tree wf
  for tree in claude/skills cursor/skills; do
    for skill in "${SDLC_SKILLS[@]}"; do
      wf="$REPO_ROOT/$tree/$skill/workflow.md"
      [ -f "$wf" ] || continue
      if grep -q '^> \*\*dontbmad-caveman' "$wf"; then
        _fail "$tree/$skill: no inline caveman directive" \
              "inline directive found — caveman is now global, remove it from workflow.md"
      else
        _pass "$tree/$skill: no inline caveman directive"
      fi
    done
  done
}

run_test test_global_template_exists
run_test test_install_injects_globally
run_test test_no_inline_caveman_in_workflows
finish
