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

# --- Dependency checks ---
# Gates features that need specific tools; never hard-fails the install.
NODE_OK=false
PYTHON3_OK=false
GIT_OK=false
UVX_OK=false
BASH_OK=false

check_system_deps() {
  echo "Dependencies:"

  if command -v bash >/dev/null 2>&1; then
    echo "  bash:     ok ($(bash --version 2>/dev/null | head -1))"
    BASH_OK=true
  else
    echo "  bash:     NOT FOUND — AIEye Live helper script needs bash (/usr/bin/env bash)"
    echo "            Install via your OS package manager (often preinstalled on Linux/macOS)"
  fi

  if command -v git >/dev/null 2>&1; then
    echo "  git:      ok ($(git --version 2>&1 | head -1))"
    GIT_OK=true
  else
    echo "  git:      NOT FOUND — git hooks will be skipped"
    echo "            Install: https://git-scm.com/downloads"
  fi

  if command -v node >/dev/null 2>&1; then
    local _ver _major
    _ver=$(node --version 2>/dev/null | sed 's/v//')
    _major="${_ver%%.*}"
    if [ "${_major:-0}" -ge 18 ] 2>/dev/null; then
      echo "  node:     ok (v$_ver)"
      NODE_OK=true
    else
      echo "  node:     v$_ver found — needs >= 18 (AIEye Live workflow step requires Node 18+)"
      echo "            Upgrade: https://nodejs.org  or  brew upgrade node  or  nvm install 18"
    fi
  else
    echo "  node:     NOT FOUND — AIEye Live workflow step requires Node >= 18"
    echo "            Install:  https://nodejs.org  or  brew install node  or  nvm install 18"
  fi

  if command -v python3 >/dev/null 2>&1; then
    echo "  python3:  ok ($(python3 --version 2>&1))"
    PYTHON3_OK=true
  else
    echo "  python3:  NOT FOUND — caveman injection will be skipped"
    echo "            Install:  https://python.org  or  brew install python3"
  fi

  if command -v uvx >/dev/null 2>&1; then
    echo "  uvx:      ok"
    UVX_OK=true
  else
    echo "  uvx:      NOT FOUND — graphify will be skipped"
    echo "            Install:  curl -LsSf https://astral.sh/uv/install.sh | sh"
  fi

  echo ""
}

check_system_deps

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

# --- Global caveman: inject terse-mode rules into ~/.claude/CLAUDE.md + ~/.cursor/rules/ ---
# Makes caveman always-on without per-session activation. Safe to run repeatedly;
# uses HTML comment markers to detect and replace an existing block.
inject_global_caveman() {
  local template="$REPO_ROOT/templates/dontbmad-caveman-global.md"
  [ -f "$template" ] || return 0
  if ! $PYTHON3_OK; then
    echo "  Caveman:        skipped (python3 required — see dependency warnings above)"
    return 0
  fi

  local marker="dont-b-mad:caveman"

  # Claude Code: inject/update ~/.claude/CLAUDE.md
  local claude_md="$HOME/.claude/CLAUDE.md"
  python3 - "$claude_md" "$template" "$marker" <<'PYEOF'
import sys, re
target, template, marker = sys.argv[1], sys.argv[2], sys.argv[3]
new_content = open(template).read().strip()
block = f"<!-- {marker} -->\n{new_content}\n<!-- /{marker} -->"
try:
    content = open(target).read()
except FileNotFoundError:
    content = ""
pat = f"<!-- {marker} -->.*?<!-- /{marker} -->"
if re.search(pat, content, flags=re.DOTALL):
    content = re.sub(pat, block, content, flags=re.DOTALL)
else:
    content = content.rstrip('\n') + f"\n\n{block}\n"
open(target, 'w').write(content)
PYEOF
  echo "  Caveman:        ~/.claude/CLAUDE.md"

  # Cursor: write to ~/.cursor/rules/dontbmad-caveman.md (global user rules)
  mkdir -p "$HOME/.cursor/rules"
  cp "$template" "$HOME/.cursor/rules/dontbmad-caveman.md"
  echo "  Caveman:        ~/.cursor/rules/dontbmad-caveman.md"
}

# --- Graphify: install knowledge-graph skill to ~/.claude and ~/.cursor ---
# Runs graphify install for both platforms so the /graphify skill is available
# everywhere without a manual pip/uvx step. Safe to run repeatedly.
graphify_installed=false
install_graphify() {
  if ! $UVX_OK; then
    echo "  Graphify:       skipped (uvx not found — see dependency warnings above)"
    return 0
  fi

  local claude_status cursor_status
  claude_status=$(uvx --from graphifyy graphify install --platform claude 2>&1) && true
  cursor_status=$(uvx --from graphifyy graphify install --platform cursor 2>&1) && true
  echo "  Graphify:       installed (claude + cursor)"
  graphify_installed=true
}

# --- Global mode: skills only, no workspace files ---
# Also covers IN_REPO: running from inside the source repo shouldn't drop
# workspace bookkeeping (rules, _bmad, dashboard) into the source tree —
# those artifacts only make sense at a consumer workspace.
if [ "$MODE" = "global" ] || $IN_REPO; then
  publish_skills
  inject_global_caveman
  install_graphify
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
  inject_global_caveman
  install_graphify

  if [ -f "$REPO_ROOT/scripts/adoption-dashboard.sh" ]; then
    mkdir -p "$TARGET/scripts"
    cp "$REPO_ROOT/scripts/adoption-dashboard.sh" "$TARGET/scripts/adoption-dashboard.sh"
    chmod +x "$TARGET/scripts/adoption-dashboard.sh"
    dashboard_installed=true
    echo "  Dashboard:      scripts/adoption-dashboard.sh installed"
  fi

  # --- Rules: workspace-scoped (they teach the agent about THIS workspace) ---
  mkdir -p "$TARGET/.cursor/rules" "$TARGET/.claude/rules"
  for rule_file in bmad-workspace-resolution.md bmad-team-customization.md dontbmad-graph-first.md dontbmad-aieye-live.md; do
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

  # --- Per-project scaffold: ensure _bmad/{bmm,cis,core}/config.yaml exists ---
  # Skill workflows load `{project-root}/_bmad/{bmm,cis,core}/config.yaml` for
  # variables like {planning_artifacts}, {project_name}, {communication_language}.
  # If those files are missing the skills error out or emit unresolved {var}
  # paths. Scaffold defaults so first-time projects work out of the box.
  # Idempotent: never overwrites existing config.yaml unless --force.
  scaffolded_count=0
  scaffold_bmad_for_project() {
    local proj_dir="$1"
    local proj_name; proj_name="$(basename "$proj_dir")"
    [ "$proj_dir" = "$TARGET" ] && proj_name="$(basename "$TARGET")"
    local created_any=false

    # Per-module config.yaml (matches upstream BMAD layout: _bmad/<module>/config.yaml).
    for module in bmm cis core; do
      local tpl="$REPO_ROOT/templates/_bmad/$module/config.yaml"
      [ -f "$tpl" ] || continue
      local dst_dir="$proj_dir/_bmad/$module"
      local dst="$dst_dir/config.yaml"
      if [ ! -f "$dst" ] || $FORCE; then
        mkdir -p "$dst_dir"
        sed "s/{{project_name}}/${proj_name}/g" "$tpl" > "$dst"
        created_any=true
      fi
    done

    # Empty support dirs that upstream creates as part of the bmad shell.
    # Skills don't strictly need them, but matching the layout avoids confusion
    # for anyone moving between fork-installed and upstream-installed projects.
    mkdir -p "$proj_dir/_bmad/scripts" "$proj_dir/_bmad/custom"

    # Output dirs declared by upstream bmm/module.yaml's `directories:` block.
    # Skills like /create-prd write to {planning_artifacts}; pre-creating the
    # path means the first write doesn't fail because the parent doesn't exist.
    mkdir -p \
      "$proj_dir/_bmad-output/planning-artifacts" \
      "$proj_dir/_bmad-output/implementation-artifacts" \
      "$proj_dir/docs"

    if $created_any; then
      scaffolded_count=$((scaffolded_count + 1))
      local rel="${proj_dir#"$TARGET"/}"
      [ "$rel" = "$proj_dir" ] && rel="."
      echo "  Project init:   $rel/_bmad/{bmm,cis,core}/config.yaml + _bmad-output/{planning,implementation}-artifacts/"
    fi
  }

  # Scaffold rules:
  #   1. Workspace target if it is a git repo.
  #   2. Every immediate child dir that is a git repo OR already has _bmad/
  #      (re-running install fills in any module config that's missing).
  #   3. Fallback — if nothing matched (bare workspace, no git anywhere yet),
  #      scaffold the workspace target itself as a single-project setup.
  #      Matches the single-project pattern in templates/bmad-workspace-resolution.md.
  any_scaffold_target_found=false
  if [ -d "$TARGET/.git" ] || [ -f "$TARGET/.git" ]; then
    scaffold_bmad_for_project "$TARGET"
    any_scaffold_target_found=true
  fi
  for dir in "$TARGET"/*/; do
    [ -d "$dir" ] || continue
    proj="${dir%/}"
    if [ -d "$proj/.git" ] || [ -f "$proj/.git" ] || [ -d "$proj/_bmad" ]; then
      scaffold_bmad_for_project "$proj"
      any_scaffold_target_found=true
    fi
  done
  if ! $any_scaffold_target_found; then
    scaffold_bmad_for_project "$TARGET"
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
  if ! $GIT_OK; then
    echo "  Git hooks:      skipped (git not found — see dependency warnings above)"
  elif [ -f "$REPO_ROOT/hooks/prepare-commit-msg" ]; then
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
  echo "Scaffold:  $scaffolded_count project(s) initialized with _bmad/{bmm,cis,core}/config.yaml"
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
if $graphify_installed; then
  echo ""
  echo "Run '/dontbmad-graphify' (or '/graphify .') in your project to build the knowledge graph."
elif ! $UVX_OK; then
  echo ""
  echo "Graphify skipped. Install uv (curl -LsSf https://astral.sh/uv/install.sh | sh) then re-run."
fi
