#!/usr/bin/env bash
# Verifies prepare-commit-msg correctly classifies staged files into AI-Phase
# values. Only the upstream BMAD layout (_bmad-output/...) is recognised; any
# other path falls through to the default "code" tag so artifacts cannot drift
# to ad-hoc locations and silently still appear "tagged correctly".

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/../lib/assert.sh"
CURRENT_FILE="$(basename "$0")"

HOOK="$REPO_ROOT/hooks/prepare-commit-msg"

# Helper: invoke the hook in a sandbox repo with a given staged file list,
# return the resolved AI-Phase trailer value.
run_hook_with_staged() {
  local staged="$1"
  local repo
  repo="$(mktemp -d)"
  (
    cd "$repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "test"
    # Create + stage all listed files (one per line)
    while IFS= read -r path; do
      [ -z "$path" ] && continue
      mkdir -p "$(dirname "$path")"
      printf 'x' > "$path"
      git add -- "$path"
    done <<< "$staged"

    # Write a placeholder commit message file the hook will rewrite.
    local msg_file="$repo/COMMIT_MSG"
    printf 'wip\n' > "$msg_file"

    bash "$HOOK" "$msg_file" message >/dev/null 2>&1

    # Echo just the AI-Phase value
    grep -E '^AI-Phase:' "$msg_file" | head -1 | sed 's/^AI-Phase: *//'
  )
  rm -rf "$repo"
}

# ---------------------------------------------------------------------------
# Upstream-aligned paths (after the structure-alignment commit)
# ---------------------------------------------------------------------------

test_upstream_story_file() {
  local phase
  phase="$(run_hook_with_staged $'_bmad-output/implementation-artifacts/1-2-user-auth.md')"
  assert_contains "story phase tagged for upstream story path" "$phase" "story"
}

test_upstream_prd() {
  local phase
  phase="$(run_hook_with_staged $'_bmad-output/planning-artifacts/prd.md')"
  assert_contains "prd phase tagged for upstream prd path" "$phase" "prd"
}

test_upstream_architecture() {
  local phase
  phase="$(run_hook_with_staged $'_bmad-output/planning-artifacts/architecture.md')"
  assert_contains "architecture phase tagged for upstream arch path" "$phase" "architecture"
}

test_upstream_ux() {
  local phase
  phase="$(run_hook_with_staged $'_bmad-output/planning-artifacts/ux-design-specification.md')"
  assert_contains "ux-design phase tagged for upstream ux path" "$phase" "ux-design"
}

test_upstream_epics() {
  local phase
  phase="$(run_hook_with_staged $'_bmad-output/planning-artifacts/epics.md')"
  assert_contains "epics phase tagged for upstream epics path" "$phase" "epics"
}

test_upstream_review() {
  local phase
  phase="$(run_hook_with_staged $'_bmad-output/implementation-artifacts/reviews/1-2-auth-2026-05-06.md')"
  assert_contains "review phase tagged for upstream review path" "$phase" "review"
}

test_upstream_sprint_status() {
  local phase
  phase="$(run_hook_with_staged $'_bmad-output/implementation-artifacts/sprint-status.yaml')"
  assert_contains "sprint-plan phase tagged for upstream sprint-status path" "$phase" "sprint-plan"
}

# ---------------------------------------------------------------------------
# Legacy / ad-hoc paths must NOT receive a planning/story/review tag.
# They get the default "code" tag instead, which signals to the developer
# (and to the dashboard) that the file is sitting in the wrong place.
# ---------------------------------------------------------------------------

test_legacy_story_path_not_classified() {
  local phase
  phase="$(run_hook_with_staged $'implementation/1-2-user-auth.md')"
  assert_not_contains "legacy story path is NOT tagged story" "$phase" "story"
}

test_legacy_prd_path_not_classified() {
  local phase
  phase="$(run_hook_with_staged $'planning/prd.md')"
  assert_not_contains "legacy prd path is NOT tagged prd" "$phase" "prd"
}

test_legacy_review_path_not_classified() {
  local phase
  phase="$(run_hook_with_staged $'implementation/reviews/1-2-auth-2026-05-06.md')"
  assert_not_contains "legacy review path is NOT tagged review" "$phase" "review"
}

test_adhoc_sprint_status_not_classified() {
  # Bare sprint-status.yaml in repo root: not under the upstream layout,
  # so it must NOT receive the sprint-plan tag.
  local phase
  phase="$(run_hook_with_staged $'sprint-status.yaml')"
  assert_not_contains "ad-hoc sprint-status.yaml is NOT tagged sprint-plan" "$phase" "sprint-plan"
}

# ---------------------------------------------------------------------------
# Multi-file commits — combined phases
# ---------------------------------------------------------------------------

test_combined_story_and_code() {
  local phase
  phase="$(run_hook_with_staged "$(printf '%s\n%s\n' '_bmad-output/implementation-artifacts/1-2-user-auth.md' 'src/auth.ts')")"
  assert_contains "story tag present in combined commit" "$phase" "story"
  assert_contains "code tag present in combined commit" "$phase" "code"
}

# ---------------------------------------------------------------------------
# Hook in sync between hooks/ and dontbmad-ai-tracking/
# ---------------------------------------------------------------------------

test_hook_copies_in_sync() {
  if cmp -s "$HOOK" "$REPO_ROOT/claude/skills/dontbmad-ai-tracking/prepare-commit-msg"; then
    _pass "hook copies are byte-identical"
  else
    _fail "hook copies are byte-identical" "hooks/prepare-commit-msg differs from claude/skills/dontbmad-ai-tracking/prepare-commit-msg"
  fi
  TESTS_TOTAL=$((TESTS_TOTAL + 0))
}

run_test test_upstream_story_file
run_test test_upstream_prd
run_test test_upstream_architecture
run_test test_upstream_ux
run_test test_upstream_epics
run_test test_upstream_review
run_test test_upstream_sprint_status
run_test test_legacy_story_path_not_classified
run_test test_legacy_prd_path_not_classified
run_test test_legacy_review_path_not_classified
run_test test_adhoc_sprint_status_not_classified
run_test test_combined_story_and_code
run_test test_hook_copies_in_sync
finish
