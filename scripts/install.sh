#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<EOF
dont-b-mad installer

Usage:
  bash install.sh [workspace-path]                  Install everything (workspace mode)
  bash install.sh [workspace-path] --skills-only    Skills + workspace files (no git required)
  bash install.sh [workspace-path] --hooks-only     Git hooks only (requires repos)
  bash install.sh [workspace-path] --force          Overwrite existing workspace.yaml
  bash install.sh [workspace-path] --dev-link       Symlink skills (in-place editing)
  bash install.sh --global                          Publish skills only (no workspace files)
  bash install.sh --global --dev-link               Same, but symlink to this repo (live edits)

Skills (Claude + Cursor) always install to ~/.claude/skills and ~/.cursor/skills
so a single user-level copy serves every workspace. Workspace mode additionally
writes rules, _bmad/workspace.yaml, _bmad/_config/team.yaml, and the adoption
dashboard at the workspace root, plus prepare-commit-msg into each child repo.

Skills are symlinked (not copied) when running from inside the source repo or
when --dev-link is passed; this lets edits to claude/skills/ flow live.
EOF
  exit 0
}

MODE="all"  # all | skills | hooks | global
TARGET=""
FORCE=false
DEV_LINK=false
for arg in "$@"; do
  case "$arg" in
    --help|-h)     usage ;;
    --skills-only) MODE="skills" ;;
    --hooks-only)  MODE="hooks" ;;
    --global)      MODE="global" ;;
    --dev-link)    DEV_LINK=true ;;
    --force)       FORCE=true ;;
    *)             TARGET="$arg" ;;
  esac
done
TARGET="${TARGET:-.}"
TARGET="$(cd "$TARGET" && pwd)"

# IN_REPO: running from inside the source repo. Defaults to symlinks so devs
# editing claude/skills/ see changes immediately in ~/.claude/skills.
IN_REPO=false
if [ "$TARGET" = "$REPO_ROOT" ]; then
  IN_REPO=true
fi

LINK_MODE=false
if $IN_REPO || $DEV_LINK; then
  LINK_MODE=true
fi

echo "dont-b-mad installer"
if [ "$MODE" = "global" ]; then
  echo "Mode:    global ($($LINK_MODE && echo "symlink to repo" || echo "copy to home"))"
else
  echo "Workspace: $TARGET"
  echo "Skills:    ~/.claude/skills, ~/.cursor/skills ($($LINK_MODE && echo "symlinks" || echo "copies"))"
fi
echo ""

claude_count=0
cursor_count=0
hook_repos=0
project_count=0
dashboard_installed=false

# --- Skill publishing: always to ~/.claude and ~/.cursor ---
# Why user-level: a workspace can hold many repos, but skills are user-scoped
# in Claude Code and Cursor. Installing into each workspace would duplicate
# every skill into both .claude/skills/ and ~/.claude/skills/, doubling the
# token footprint and making it ambiguous which copy runs.
publish_skills() {
  local user_claude_skills="$HOME/.claude/skills"
  local user_claude_commands="$HOME/.claude/commands"
  local user_cursor_skills="$HOME/.cursor/skills"
  mkdir -p "$user_claude_skills" "$user_claude_commands" "$user_cursor_skills"

  publish_one() {
    local src_dir="$1"        # claude/skills or cursor/skills
    local dst_skills="$2"     # ~/.claude/skills or ~/.cursor/skills
    local dst_commands="$3"   # ~/.claude/commands  or "" (cursor has none)
    local label="$4"
    local count=0
    [ -d "$REPO_ROOT/$src_dir" ] || { echo "  $label  (no source dir)"; PUBLISH_LAST_COUNT=0; return 0; }
    for skill_path in "$REPO_ROOT/$src_dir/bmad-"* "$REPO_ROOT/$src_dir/dontbmad-"*; do
      [ -d "$skill_path" ] || continue
      local name; name=$(basename "$skill_path")
      rm -rf "$dst_skills/$name"
      if $LINK_MODE; then
        ln -s "$skill_path" "$dst_skills/$name"
      else
        cp -r "$skill_path" "$dst_skills/"
      fi
      if [ -n "$dst_commands" ]; then
        rm -f "$dst_commands/$name.md"
        ln -s "$dst_skills/$name/SKILL.md" "$dst_commands/$name.md"
      fi
      count=$((count + 1))
    done
    local mode_label; $LINK_MODE && mode_label="symlinks" || mode_label="copies"
    echo "  $label  $count $mode_label -> $dst_skills"
    [ -n "$dst_commands" ] && echo "  $label  $count command symlinks -> $dst_commands"
    PUBLISH_LAST_COUNT=$count
  }

  # Clean stale command symlinks pointing at skills that no longer exist
  for f in "$user_claude_commands"/bmad-*.md "$user_claude_commands"/dontbmad-*.md; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    [ -L "$f" ] && [ ! -e "$f" ] && { rm -f "$f"; echo "  Cleaned broken: $(basename "$f")"; }
  done

  publish_one "claude/skills" "$user_claude_skills" "$user_claude_commands" "Claude:"
  claude_count=$PUBLISH_LAST_COUNT
  publish_one "cursor/skills" "$user_cursor_skills" "" "Cursor:"
  cursor_count=$PUBLISH_LAST_COUNT
}

# --- Claude Code post-skill hook (AIEye live events) ---
# Copies hooks/post-skill/ to ~/.claude/hooks/aieye-live/ and registers the
# Stop hook entry in ~/.claude/settings.json so every BMAD skill can fire
# an AIEye celebration event on completion. Safe to run repeatedly.
post_skill_hook_installed=false
install_post_skill_hook() {
  local src="$REPO_ROOT/hooks/post-skill"
  [ -d "$src" ] || return 0
  local dst="$HOME/.claude/hooks/aieye-live"
  mkdir -p "$dst/bin" "$dst/lib"
  cp "$src/package.json"               "$dst/package.json"
  cp "$src/README.md"                  "$dst/README.md"             2>/dev/null || true
  cp "$src/bin/aieye-live-hook"        "$dst/bin/aieye-live-hook"
  cp "$src/lib/dispatch.js"            "$dst/lib/dispatch.js"
  cp "$src/lib/dispatch.test.js"       "$dst/lib/dispatch.test.js"  2>/dev/null || true
  cp "$src/lib/dispatch.queue.test.js" "$dst/lib/dispatch.queue.test.js" 2>/dev/null || true
  chmod +x "$dst/bin/aieye-live-hook"
  local hook_bin="$dst/bin/aieye-live-hook"
  local settings="$HOME/.claude/settings.json"
  local reg_status
  if command -v python3 >/dev/null 2>&1; then
    reg_status=$(python3 "$REPO_ROOT/scripts/register-post-skill-hook.py" "$settings" "$hook_bin" 2>&1)
  else
    reg_status="installed (python3 not found — add to ~/.claude/settings.json Stop hooks manually)"
  fi
  echo "  Post-skill hook: ~/.claude/hooks/aieye-live  ($reg_status)"
  echo "  To activate:    create ~/.claude/aieye-live.env (see hooks/post-skill/README.md)"
  post_skill_hook_installed=true
}

# --- Global mode: skills only, no workspace files ---
# Also covers IN_REPO: running from inside the source repo shouldn't drop
# workspace bookkeeping (rules, _bmad, dashboard) into the source tree —
# those artifacts only make sense at a consumer workspace.
if [ "$MODE" = "global" ] || $IN_REPO; then
  publish_skills
  install_post_skill_hook
  echo ""
  if $IN_REPO; then
    echo "Source-repo install: skills published as symlinks to $REPO_ROOT."
    echo "Edits to claude/skills/ and cursor/skills/ apply immediately."
  else
    echo "Globally published from $REPO_ROOT to ~/.claude and ~/.cursor."
    $LINK_MODE && echo "Live mode: edits to $REPO_ROOT/{claude,cursor}/skills/ apply immediately."
    $LINK_MODE || echo "Stable mode: re-run with --global to publish updates."
  fi
  exit 0
fi

# --- Workspace mode (all / skills): publish skills + workspace files ---
if [ "$MODE" = "all" ] || [ "$MODE" = "skills" ]; then
  publish_skills
  install_post_skill_hook

  if [ -f "$REPO_ROOT/scripts/adoption-dashboard.sh" ]; then
    mkdir -p "$TARGET/scripts"
    cp "$REPO_ROOT/scripts/adoption-dashboard.sh" "$TARGET/scripts/adoption-dashboard.sh"
    chmod +x "$TARGET/scripts/adoption-dashboard.sh"
    dashboard_installed=true
    echo "  Dashboard:      scripts/adoption-dashboard.sh installed"
  fi

  # --- Rules: workspace-scoped (they teach the agent about THIS workspace) ---
  mkdir -p "$TARGET/.cursor/rules" "$TARGET/.claude/rules"
  for rule_file in bmad-workspace-resolution.md bmad-team-customization.md dontbmad-graph-first.md dontbmad-caveman-activate.md; do
    if [ -f "$REPO_ROOT/templates/$rule_file" ]; then
      cp "$REPO_ROOT/templates/$rule_file" "$TARGET/.cursor/rules/$rule_file"
      cp "$REPO_ROOT/templates/$rule_file" "$TARGET/.claude/rules/$rule_file"
    fi
  done
  echo "  Rules:          .cursor/rules/ + .claude/rules/"

  # --- Team config: default agent display names ---
  if [ -f "$REPO_ROOT/templates/team.yaml" ]; then
    mkdir -p "$TARGET/_bmad/_config"
    if [ ! -f "$TARGET/_bmad/_config/team.yaml" ] || $FORCE; then
      cp "$REPO_ROOT/templates/team.yaml" "$TARGET/_bmad/_config/team.yaml"
      echo "  Team config:    _bmad/_config/team.yaml"
    else
      echo "  Team config:    _bmad/_config/team.yaml exists, skipped (use --force to overwrite)"
    fi
  fi

  # --- Workspace config: auto-discover projects with _bmad/ ---
  # A project has _bmad/ with at least one module config dir (bmm/, cis/, core/)
  has_bmad_project() {
    local dir="$1"
    [ -d "$dir/_bmad/bmm" ] || [ -d "$dir/_bmad/cis" ] || [ -d "$dir/_bmad/core" ]
  }

  generate_workspace_config() {
    local ws="$1"
    local found_projects=""
    local count=0

    if has_bmad_project "$ws"; then
      found_projects="  .:
    path: .
    description: ''
"
      count=$((count + 1))
    fi

    for dir in "$ws"/*/; do
      [ -d "$dir" ] || continue
      if has_bmad_project "$dir"; then
        local name
        name="$(basename "$dir")"
        found_projects="${found_projects}  ${name}:
    path: ${name}
    description: ''
"
        count=$((count + 1))
      fi
    done

    project_count=$count

    for dir in "$ws"/*/; do
      [ -d "$dir" ] || continue
      local name
      name="$(basename "$dir")"
      if { [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; } && [ ! -d "$dir/_bmad" ]; then
        found_projects="${found_projects}  # ${name}:
  #   path: ${name}
  #   description: ''   # uncomment after running bmad init in this project
"
      fi
    done

    local default=""
    if [ "$count" -eq 1 ]; then
      default=$(echo "$found_projects" | head -1 | sed 's/:.*//' | xargs)
    fi

    cat <<ENDYAML
# BMad Workspace Configuration
#
# Maps project directories so BMAD skills resolve {project-root} to the
# correct project. Auto-generated by install.sh on $(date +%Y-%m-%d).
# Edit freely — the installer will not overwrite unless you pass --force.

default_project: '${default}'

projects:
${found_projects}
ENDYAML
  }

  if [ ! -f "$TARGET/_bmad/workspace.yaml" ] || $FORCE; then
    mkdir -p "$TARGET/_bmad"
    generate_workspace_config "$TARGET" > "$TARGET/_bmad/workspace.yaml"
    echo "  Workspace config: _bmad/workspace.yaml ($project_count project(s) discovered)"
  else
    echo "  Workspace config: _bmad/workspace.yaml exists, skipped (use --force to overwrite)"
  fi
fi

# --- Git hooks: installed per-repo inside the workspace ---
install_hook_to_repo() {
  local repo_dir="$1"
  local git_dir

  if [ -d "$repo_dir/.git" ]; then
    git_dir="$repo_dir/.git"
  elif [ -f "$repo_dir/.git" ]; then
    git_dir=$(git -C "$repo_dir" rev-parse --git-dir 2>/dev/null) || return 0
  else
    return 0
  fi

  mkdir -p "$git_dir/hooks"
  if [ -f "$git_dir/hooks/prepare-commit-msg" ]; then
    cp "$git_dir/hooks/prepare-commit-msg" "$git_dir/hooks/prepare-commit-msg.bak"
    echo "  Git hook:       ${repo_dir#"$TARGET"/} (backed up existing)"
  else
    echo "  Git hook:       ${repo_dir#"$TARGET"/}"
  fi
  cp "$REPO_ROOT/hooks/prepare-commit-msg" "$git_dir/hooks/prepare-commit-msg"
  chmod +x "$git_dir/hooks/prepare-commit-msg"
  hook_repos=$((hook_repos + 1))
}

if [ "$MODE" = "all" ] || [ "$MODE" = "hooks" ]; then
  if [ -f "$REPO_ROOT/hooks/prepare-commit-msg" ]; then
    if [ -d "$TARGET/.git" ] || [ -f "$TARGET/.git" ]; then
      install_hook_to_repo "$TARGET"
    fi

    for dir in "$TARGET"/*/; do
      [ -d "$dir" ] || continue
      if [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; then
        install_hook_to_repo "${dir%/}"
      fi
    done

    if [ "$hook_repos" -eq 0 ] && [ "$MODE" = "hooks" ]; then
      echo "  No git repos found in $TARGET"
      echo "  Hooks are installed per-repo. Make sure repos exist inside the workspace."
    fi
  fi
fi

# --- Summary ---
echo ""
if [ "$MODE" = "all" ] || [ "$MODE" = "skills" ]; then
  echo "Skills:    $cursor_count Cursor, $claude_count Claude (~/.cursor + ~/.claude)"
  echo "Projects:  $project_count discovered in _bmad/workspace.yaml"
fi
if [ "$MODE" = "all" ] || [ "$MODE" = "hooks" ]; then
  echo "Hooks:     $hook_repos repo(s) with prepare-commit-msg installed"
fi
if $dashboard_installed; then
  echo ""
  echo "Run 'bash scripts/adoption-dashboard.sh' to see AI adoption metrics."
  echo "  Use --workspace to aggregate across all repos."
fi
if [ "$project_count" -eq 0 ] && { [ "$MODE" = "all" ] || [ "$MODE" = "skills" ]; }; then
  echo ""
  echo "No projects with _bmad/ found yet. After initializing BMAD in a"
  echo "project, re-run the installer (or edit _bmad/workspace.yaml) to"
  echo "register it."
fi
if [ "$MODE" = "all" ] || [ "$MODE" = "skills" ]; then
  echo ""
  echo "Customize agent names: edit _bmad/_config/team.yaml"
fi
echo ""
echo "Optional: install graphify for codebase knowledge graph"
echo "  pip install graphifyy && graphify cursor install"
echo "  Then run '/graphify .' in Cursor to build the graph."
