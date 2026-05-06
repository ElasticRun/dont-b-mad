#!/usr/bin/env bash
# Run scripts/install.sh against synthetic workspaces. Verifies skills-only,
# hooks-only, --global (with HOME redirected), --force, and workspace.yaml
# project discovery.
#
# Safety: every test redirects HOME to a tmp dir so install.sh writes its
# user-level skills (~/.claude/skills, ~/.cursor/skills) into the fake home.
# The user's real ~/.claude and ~/.cursor are never touched.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL="$REPO_ROOT/scripts/install.sh"
. "$SCRIPT_DIR/../lib/assert.sh"

run_install() {
  bash "$INSTALL" "$@" >/dev/null 2>&1
}

test_skills_only_populates_workspace_and_user_home() {
  local ws fake_home
  ws=$(mktempdir)
  fake_home=$(mktempdir)
  HOME="$fake_home" run_install --skills-only "$ws"

  # Skills land at user level, not at workspace root
  assert_dir  "user claude skills dir created"   "$fake_home/.claude/skills"
  assert_dir  "user cursor skills dir created"   "$fake_home/.cursor/skills"
  assert_dir  "user claude commands dir created" "$fake_home/.claude/commands"

  # Workspace MUST NOT contain duplicate skills dirs
  if [ ! -d "$ws/.claude/skills" ]; then
    _pass "no workspace-level .claude/skills (avoids duplication)"
  else
    _fail "no workspace-level .claude/skills" "unexpected dir at $ws/.claude/skills"
  fi
  if [ ! -d "$ws/.cursor/skills" ]; then
    _pass "no workspace-level .cursor/skills (avoids duplication)"
  else
    _fail "no workspace-level .cursor/skills" "unexpected dir at $ws/.cursor/skills"
  fi

  # Workspace files still land at workspace root
  assert_dir  "Claude rules dir created"         "$ws/.claude/rules"
  assert_dir  "Cursor rules dir created"         "$ws/.cursor/rules"
  assert_file "workspace.yaml generated"         "$ws/_bmad/workspace.yaml"
  assert_file "team.yaml seeded"                 "$ws/_bmad/_config/team.yaml"
  assert_file "adoption-dashboard.sh installed"  "$ws/scripts/adoption-dashboard.sh"

  local rule
  for rule in bmad-workspace-resolution.md bmad-team-customization.md \
              dontbmad-graph-first.md dontbmad-aieye-live.md; do
    assert_file ".claude/rules/$rule installed"  "$ws/.claude/rules/$rule"
    assert_file ".cursor/rules/$rule installed"  "$ws/.cursor/rules/$rule"
  done

  # Real repo has 59 skills per side; smoke-check >= 10 made it across.
  local claude_count cursor_count
  claude_count=$(ls -1 "$fake_home/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')
  cursor_count=$(ls -1 "$fake_home/.cursor/skills" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${claude_count:-0}" -ge 10 ] && [ "${cursor_count:-0}" -ge 10 ]; then
    _pass "both user skill trees populated (claude=$claude_count, cursor=$cursor_count)"
  else
    _fail "both user skill trees populated" "got claude=$claude_count cursor=$cursor_count"
  fi

  # Out-of-repo install (TARGET != REPO_ROOT and no --dev-link) should COPY
  local sample; sample=$(ls "$fake_home/.claude/skills" | head -1)
  if [ -n "$sample" ] && [ -d "$fake_home/.claude/skills/$sample" ] && [ ! -L "$fake_home/.claude/skills/$sample" ]; then
    _pass "out-of-repo install copies (not symlinks)"
  else
    _fail "out-of-repo install copies (not symlinks)" "expected real dir at $fake_home/.claude/skills/$sample"
  fi

  # Command symlinks land in ~/.claude/commands and target the user-level skill
  if [ -n "$sample" ] && [ -L "$fake_home/.claude/commands/$sample.md" ]; then
    _pass "command symlink created for $sample"
  else
    _fail "command symlink created" "missing $fake_home/.claude/commands/$sample.md"
  fi

  rm -rf "$ws" "$fake_home"
}

test_skills_install_is_idempotent() {
  local ws fake_home
  ws=$(mktempdir)
  fake_home=$(mktempdir)
  HOME="$fake_home" run_install --skills-only "$ws"
  HOME="$fake_home" run_install --skills-only "$ws"
  assert_dir  "second install still has user claude skills" "$fake_home/.claude/skills"
  assert_file "workspace.yaml not duplicated"               "$ws/_bmad/workspace.yaml"
  rm -rf "$ws" "$fake_home"
}

test_workspace_yaml_discovers_project() {
  local ws fake_home
  ws=$(mktempdir)
  fake_home=$(mktempdir)
  mkdir -p "$ws/proj-alpha/_bmad/bmm"
  HOME="$fake_home" run_install --skills-only "$ws"
  local content; content=$(cat "$ws/_bmad/workspace.yaml")
  assert_contains "discovered project listed"          "$content" "proj-alpha:"
  assert_contains "default_project set when only one"  "$content" "default_project: 'proj-alpha'"
  rm -rf "$ws" "$fake_home"
}

test_force_overwrites_workspace_yaml() {
  local ws fake_home
  ws=$(mktempdir)
  fake_home=$(mktempdir)
  HOME="$fake_home" run_install --skills-only "$ws"
  printf 'sentinel: true\n' > "$ws/_bmad/workspace.yaml"

  # Without --force, should preserve our edits
  HOME="$fake_home" run_install --skills-only "$ws"
  if grep -q '^sentinel: true$' "$ws/_bmad/workspace.yaml"; then
    _pass "no-force preserves user edits"
  else
    _fail "no-force preserves user edits" "sentinel was overwritten"
  fi

  # With --force, should regenerate
  HOME="$fake_home" run_install --skills-only --force "$ws"
  if grep -q '^sentinel: true$' "$ws/_bmad/workspace.yaml"; then
    _fail "--force regenerates workspace.yaml" "sentinel still present"
  else
    _pass "--force regenerates workspace.yaml"
  fi
  rm -rf "$ws" "$fake_home"
}

test_hooks_only_installs_into_repo() {
  local ws fake_home
  ws=$(mktempdir)
  fake_home=$(mktempdir)
  ( cd "$ws" && git init -q sub-repo && cd sub-repo && \
      git config user.email t@t.t && git config user.name t )
  HOME="$fake_home" run_install --hooks-only "$ws"
  assert_file       "hook installed into sub-repo"      "$ws/sub-repo/.git/hooks/prepare-commit-msg"
  assert_executable "hook is executable"                "$ws/sub-repo/.git/hooks/prepare-commit-msg"
  rm -rf "$ws" "$fake_home"
}

test_hooks_only_skips_when_no_repos() {
  local ws fake_home
  ws=$(mktempdir)
  fake_home=$(mktempdir)
  local out; out=$(HOME="$fake_home" bash "$INSTALL" --hooks-only "$ws" 2>&1)
  rm -rf "$ws" "$fake_home"
  assert_contains "warns when no repos found" "$out" "No git repos"
}

test_global_publish_to_isolated_home() {
  local fake_home; fake_home=$(mktempdir)
  HOME="$fake_home" run_install --global

  assert_dir  "global claude skills dir"             "$fake_home/.claude/skills"
  assert_dir  "global cursor skills dir"             "$fake_home/.cursor/skills"
  assert_dir  "global claude commands dir"           "$fake_home/.claude/commands"

  local sample; sample=$(ls "$fake_home/.claude/skills" 2>/dev/null | head -1)
  if [ -n "$sample" ]; then
    _pass "global publish populated skills (sample=$sample)"
    if [ -L "$fake_home/.claude/commands/$sample.md" ]; then
      _pass "command symlink created for $sample"
    else
      _fail "command symlink created" "missing $fake_home/.claude/commands/$sample.md"
    fi
  else
    _fail "global publish populated skills" "no skills in $fake_home/.claude/skills"
  fi

  rm -rf "$fake_home"
}

test_global_dev_link_uses_symlinks() {
  local fake_home; fake_home=$(mktempdir)
  HOME="$fake_home" run_install --global --dev-link

  local sample; sample=$(ls "$fake_home/.claude/skills" 2>/dev/null | head -1)
  if [ -n "$sample" ] && [ -L "$fake_home/.claude/skills/$sample" ]; then
    _pass "--dev-link creates symlink for skill"
    local target; target=$(readlink "$fake_home/.claude/skills/$sample")
    assert_contains "symlink targets repo's claude/skills" "$target" "$REPO_ROOT/claude/skills/$sample"
  else
    _fail "--dev-link creates symlink for skill" "expected symlink at $fake_home/.claude/skills/$sample"
  fi
  rm -rf "$fake_home"
}

test_dep_check_output_printed() {
  local fake_home; fake_home=$(mktempdir)
  local out; out=$(HOME="$fake_home" bash "$INSTALL" --global 2>&1)
  rm -rf "$fake_home"

  assert_contains "dep check prints git status"     "$out" "git:"
  assert_contains "dep check prints node status"    "$out" "node:"
  assert_contains "dep check prints python3 status" "$out" "python3:"
}

test_global_injects_caveman_into_claude_md() {
  local fake_home; fake_home=$(mktempdir)
  HOME="$fake_home" run_install --global
  local target="$fake_home/.claude/CLAUDE.md"

  if [ -f "$target" ] && grep -q "dont-b-mad:caveman" "$target"; then
    _pass "global install injects caveman block into ~/.claude/CLAUDE.md"
  else
    _fail "global install injects caveman block into ~/.claude/CLAUDE.md" \
          "marker not found in $target"
  fi

  if [ -f "$fake_home/.cursor/rules/dontbmad-caveman.md" ]; then
    _pass "global install writes ~/.cursor/rules/dontbmad-caveman.md"
  else
    _fail "global install writes ~/.cursor/rules/dontbmad-caveman.md" "file missing"
  fi

  rm -rf "$fake_home"
}

run_test test_skills_only_populates_workspace_and_user_home
run_test test_skills_install_is_idempotent
run_test test_workspace_yaml_discovers_project
run_test test_force_overwrites_workspace_yaml
run_test test_hooks_only_installs_into_repo
run_test test_hooks_only_skips_when_no_repos
run_test test_global_publish_to_isolated_home
run_test test_global_dev_link_uses_symlinks
run_test test_dep_check_output_printed
run_test test_global_injects_caveman_into_claude_md
finish
