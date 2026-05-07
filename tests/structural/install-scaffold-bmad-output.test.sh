#!/usr/bin/env bash
# Verifies install.sh scaffolds the upstream-aligned BMAD layout in a
# project, matching bmad-code-org/BMAD-METHOD's installer output:
#   _bmad/{bmm,cis,core}/config.yaml + scripts/ + custom/
#   _bmad-output/{planning,implementation}-artifacts/
#   docs/

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
. "$SCRIPT_DIR/../lib/assert.sh"
CURRENT_FILE="$(basename "$0")"

INSTALL="$REPO_ROOT/scripts/install.sh"

# ---------------------------------------------------------------------------
# Case A: bare workspace (no git anywhere) — workspace target gets scaffolded
# ---------------------------------------------------------------------------

test_bare_workspace_scaffolds_root() {
  local ws; ws="$(mktemp -d)"
  bash "$INSTALL" "$ws" --skills-only >/dev/null 2>&1 || true

  assert_file "core/config.yaml at workspace root"  "$ws/_bmad/core/config.yaml"
  assert_file "bmm/config.yaml at workspace root"   "$ws/_bmad/bmm/config.yaml"
  assert_file "cis/config.yaml at workspace root"   "$ws/_bmad/cis/config.yaml"
  assert_dir  "_bmad/scripts dir created"            "$ws/_bmad/scripts"
  assert_dir  "_bmad/custom dir created"             "$ws/_bmad/custom"
  assert_dir  "_bmad-output/planning-artifacts"     "$ws/_bmad-output/planning-artifacts"
  assert_dir  "_bmad-output/implementation-artifacts" "$ws/_bmad-output/implementation-artifacts"
  assert_dir  "docs dir created"                    "$ws/docs"

  rm -rf "$ws"
}

# ---------------------------------------------------------------------------
# Case B: workspace with git subdirs — each subdir scaffolded
# ---------------------------------------------------------------------------

test_workspace_with_git_subdirs() {
  local ws; ws="$(mktemp -d)"
  mkdir -p "$ws/proj1" "$ws/proj2" "$ws/not-a-repo"
  git -C "$ws/proj1" init -q
  git -C "$ws/proj2" init -q

  bash "$INSTALL" "$ws" --skills-only >/dev/null 2>&1 || true

  for proj in proj1 proj2; do
    assert_file "$proj has bmm/config.yaml"   "$ws/$proj/_bmad/bmm/config.yaml"
    assert_dir  "$proj has _bmad-output/"     "$ws/$proj/_bmad-output/planning-artifacts"
    assert_dir  "$proj has docs/"             "$ws/$proj/docs"
  done

  if [ ! -d "$ws/not-a-repo/_bmad" ]; then
    _pass "non-git subdir is not scaffolded"
  else
    _fail "non-git subdir is not scaffolded" "_bmad/ should not be created in non-git dir"
  fi

  rm -rf "$ws"
}

# ---------------------------------------------------------------------------
# Case C: re-run is idempotent (existing config preserved)
# ---------------------------------------------------------------------------

test_rerun_preserves_user_edits() {
  local ws; ws="$(mktemp -d)"
  mkdir -p "$ws/proj"
  git -C "$ws/proj" init -q

  bash "$INSTALL" "$ws" --skills-only >/dev/null 2>&1 || true
  printf '\n# user edit\nplanning_artifacts: my-custom-path\n' >> "$ws/proj/_bmad/bmm/config.yaml"
  local sentinel; sentinel=$(grep "user edit" "$ws/proj/_bmad/bmm/config.yaml" || true)

  bash "$INSTALL" "$ws" --skills-only >/dev/null 2>&1 || true

  if grep -q "user edit" "$ws/proj/_bmad/bmm/config.yaml"; then
    _pass "user edits to bmm/config.yaml survive re-run"
  else
    _fail "user edits to bmm/config.yaml survive re-run" "sentinel comment was overwritten"
  fi

  rm -rf "$ws"
}

# ---------------------------------------------------------------------------
# Case D: bmm/config.yaml content matches upstream defaults
# ---------------------------------------------------------------------------

test_bmm_config_content_matches_upstream() {
  local ws; ws="$(mktemp -d)"
  mkdir -p "$ws/myproj"
  git -C "$ws/myproj" init -q

  bash "$INSTALL" "$ws" --skills-only >/dev/null 2>&1 || true
  local content
  content=$(cat "$ws/myproj/_bmad/bmm/config.yaml")

  assert_contains "bmm has user_skill_level"        "$content" "user_skill_level: intermediate"
  assert_contains "bmm has upstream output_folder"  "$content" "_bmad-output"
  assert_contains "bmm planning_artifacts upstream" "$content" "_bmad-output/planning-artifacts"
  assert_contains "bmm impl_artifacts upstream"     "$content" "_bmad-output/implementation-artifacts"
  assert_contains "bmm project_knowledge upstream"  "$content" "{project-root}/docs"
  assert_contains "bmm has Core Configuration"      "$content" "Core Configuration Values"
  assert_contains "project_name auto-substituted"   "$content" "project_name: 'myproj'"
  assert_contains "no template placeholder left"    "$content" "myproj"

  rm -rf "$ws"
}

run_test test_bare_workspace_scaffolds_root
run_test test_workspace_with_git_subdirs
run_test test_rerun_preserves_user_edits
run_test test_bmm_config_content_matches_upstream
finish
