#!/usr/bin/env bash
# Verifies that install.sh copies the post-skill hook to ~/.claude/hooks/aieye-live/
# and registers the Stop hook entry in ~/.claude/settings.json.
#
# Safety: HOME is redirected to a tmpdir so the user's real ~/.claude is never touched.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTALL="$REPO_ROOT/scripts/install.sh"
. "$SCRIPT_DIR/../lib/assert.sh"

run_install() {
  bash "$INSTALL" "$@" >/dev/null 2>&1
}

test_post_skill_hook_files_installed() {
  local ws fake_home
  ws=$(mktempdir)
  fake_home=$(mktempdir)
  HOME="$fake_home" run_install --skills-only "$ws"

  local hook_dir="$fake_home/.claude/hooks/aieye-live"
  assert_dir        "hook dir created"           "$hook_dir"
  assert_file       "package.json present"       "$hook_dir/package.json"
  assert_file       "dispatch.js present"        "$hook_dir/lib/dispatch.js"
  assert_file       "aieye-live-hook present"    "$hook_dir/bin/aieye-live-hook"
  assert_executable "aieye-live-hook executable" "$hook_dir/bin/aieye-live-hook"

  rm -rf "$ws" "$fake_home"
}

test_post_skill_hook_registered_in_settings() {
  local ws fake_home
  ws=$(mktempdir)
  fake_home=$(mktempdir)
  mkdir -p "$fake_home/.claude"
  HOME="$fake_home" run_install --skills-only "$ws"

  if ! command -v python3 >/dev/null 2>&1; then
    _pass "python3 not available — skipping settings.json check"
    rm -rf "$ws" "$fake_home"
    return 0
  fi

  local settings="$fake_home/.claude/settings.json"
  assert_file "settings.json created" "$settings"

  local content; content=$(cat "$settings")
  assert_contains "Stop hook entry present"     "$content" "aieye-live-hook"
  assert_contains "Stop key in hooks"           "$content" '"Stop"'

  rm -rf "$ws" "$fake_home"
}

test_post_skill_hook_registration_is_idempotent() {
  local ws fake_home
  ws=$(mktempdir)
  fake_home=$(mktempdir)
  mkdir -p "$fake_home/.claude"
  HOME="$fake_home" run_install --skills-only "$ws"
  HOME="$fake_home" run_install --skills-only "$ws"

  if ! command -v python3 >/dev/null 2>&1; then
    _pass "python3 not available — skipping idempotency check"
    rm -rf "$ws" "$fake_home"
    return 0
  fi

  local settings="$fake_home/.claude/settings.json"
  local hook_count
  hook_count=$(grep -c "aieye-live-hook" "$settings" || true)
  if [ "$hook_count" -eq 1 ]; then
    _pass "Stop hook registered exactly once after two installs"
  else
    _fail "Stop hook registered exactly once" "found $hook_count occurrences in settings.json"
  fi

  rm -rf "$ws" "$fake_home"
}

test_post_skill_hook_merges_with_existing_settings() {
  local ws fake_home
  ws=$(mktempdir)
  fake_home=$(mktempdir)
  mkdir -p "$fake_home/.claude"
  printf '{"model":"opus","permissions":{"defaultMode":"auto"}}\n' \
    > "$fake_home/.claude/settings.json"

  HOME="$fake_home" run_install --skills-only "$ws"

  if ! command -v python3 >/dev/null 2>&1; then
    _pass "python3 not available — skipping merge check"
    rm -rf "$ws" "$fake_home"
    return 0
  fi

  local content; content=$(cat "$fake_home/.claude/settings.json")
  assert_contains "existing model key preserved" "$content" '"model"'
  assert_contains "hook entry added alongside"   "$content" "aieye-live-hook"

  rm -rf "$ws" "$fake_home"
}

run_test test_post_skill_hook_files_installed
run_test test_post_skill_hook_registered_in_settings
run_test test_post_skill_hook_registration_is_idempotent
run_test test_post_skill_hook_merges_with_existing_settings
finish
