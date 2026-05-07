#!/usr/bin/env bash
# Lint check: skill workflow files must not hardcode the legacy fork paths
# (planning/, implementation/, stories/) for artifacts. Skills should reference
# the upstream-aligned config variables instead — {planning_artifacts},
# {implementation_artifacts}, {project_knowledge} — or absolute upstream paths
# (_bmad-output/...). Catches regressions where someone copies an old example.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/../lib/assert.sh"
CURRENT_FILE="$(basename "$0")"

# Files to scan
SKILL_GLOBS=(
  "$REPO_ROOT/claude/skills"
  "$REPO_ROOT/cursor/skills"
)

# Each rule = three parallel-array entries: pattern, short-name, allow-regex.
# Allow-regex matches files where the pattern is intentionally still present
# (the prepare-commit-msg hook deliberately keeps both old + new patterns
# for backward compatibility).
RULE_NAMES=(
  "literal-stories-path"
  "literal-planning-path"
  "literal-implementation-sprint-status"
  "literal-implementation-story"
  "literal-docs-planning"
  "literal-docs-implementation"
)
RULE_PATTERNS=(
  '(^|[^-a-z])stories/(sprint-status|runs|auto-sprint|<|\{|[0-9]+-[0-9]+)'
  '\bplanning/(prd|architecture|epics|ux-design|ux-design-specification)\.md'
  '\bimplementation/sprint-status\.yaml'
  '\bimplementation/[0-9]+-[0-9]+-[a-z]'
  '\bdocs/planning/(prd|architecture|epics)'
  '\bdocs/implementation/'
)
RULE_ALLOW=(
  '.*dontbmad-ai-tracking/prepare-commit-msg'
  '.*dontbmad-ai-tracking/prepare-commit-msg'
  '.*dontbmad-ai-tracking/prepare-commit-msg'
  '.*dontbmad-ai-tracking/prepare-commit-msg'
  '^$'
  '^$'
)

test_no_legacy_path_literals_in_skills() {
  local i
  for i in "${!RULE_NAMES[@]}"; do
    local name="${RULE_NAMES[$i]}"
    local pat="${RULE_PATTERNS[$i]}"
    local allow="${RULE_ALLOW[$i]}"

    local hits
    hits=$(grep -rEn "$pat" "${SKILL_GLOBS[@]}" \
            --include="workflow.md" --include="SKILL.md" --include="*.md" 2>/dev/null \
            | grep -vE "$allow" || true)

    if [ -n "$hits" ]; then
      _fail "no $name in skill files" "$(printf '%s\n' "$hits" | head -5)"
    else
      _pass "no $name in skill files"
    fi
  done
}

# Sanity: at least the auto-sprint workflow uses {implementation_artifacts}
test_auto_sprint_uses_variable() {
  local count
  count=$(grep -c '{implementation_artifacts}' "$REPO_ROOT/claude/skills/dontbmad-auto-sprint/workflow.md" 2>/dev/null || echo 0)
  if [ "$count" -ge 10 ]; then
    _pass "auto-sprint workflow uses {implementation_artifacts} ($count refs)"
  else
    _fail "auto-sprint workflow uses {implementation_artifacts}" "expected >= 10 refs, found $count"
  fi
}

run_test test_no_legacy_path_literals_in_skills
run_test test_auto_sprint_uses_variable
finish
