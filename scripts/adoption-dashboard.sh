#!/usr/bin/env bash
#
# Pulse — AI Adoption Dashboard
# Reads AI-Phase / AI-Tool / Story-Ref trailers from git history
# and shows adoption rates grouped by phase.
#
# Usage:
#   bash adoption-dashboard.sh                          # current repo
#   bash adoption-dashboard.sh "1-*"                    # filter by Story-Ref
#   bash adoption-dashboard.sh --workspace [path]       # all repos in workspace
#   bash adoption-dashboard.sh --workspace [path] "1-*" # workspace + filter
#   bash adoption-dashboard.sh --repo /path/to/repo     # specific repo
#
# Portable: works on any bash (3.2+) and any POSIX awk. No associative
# arrays in bash — aggregation is delegated to awk, which also fixes a
# subtle parsing bug: git's %(trailers:valueonly) puts each trailer on
# its own line, so per-line shell parsing never saw AI-Tool / Story-Ref.

set -euo pipefail

WORKSPACE_MODE=false
WORKSPACE_PATH=""
REPO_PATH=""
FILTER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --workspace)
      WORKSPACE_MODE=true
      if [ "${2:-}" != "" ] && [ "${2#-}" = "${2:-}" ]; then
        WORKSPACE_PATH="$2"; shift
      fi
      ;;
    --repo)
      REPO_PATH="${2:-.}"; shift
      ;;
    --help|-h)
      sed -n '2,12p' "$0" | sed 's/^# *//;s/^#$//'
      exit 0
      ;;
    *)
      FILTER="$1"
      ;;
  esac
  shift
done

F_SEP="---F---"
E_SEP="---END---"
FMT="%H${F_SEP}%(trailers:key=AI-Phase,valueonly)${F_SEP}%(trailers:key=AI-Tool,valueonly)${F_SEP}%(trailers:key=Story-Ref,valueonly)${E_SEP}"

RAW=""
REPOS_SCANNED=0

collect_from_repo() {
  local repo_dir="$1"
  local out
  out=$(git -C "$repo_dir" log --all --format="$FMT" 2>/dev/null || true)
  if [ -n "$out" ]; then
    RAW="${RAW}${out}"
    REPOS_SCANNED=$((REPOS_SCANNED + 1))
  fi
}

# Discover every git repo under $1 at any depth. Skips common noise dirs
# for speed, and drops nested repos (submodules, vendored checkouts) so
# their commits aren't double-counted against the outer project.
discover_repos() {
  local root="$1"
  find "$root" \
    \( -type d \( \
         -name node_modules -o -name vendor -o -name .venv -o \
         -name venv -o -name __pycache__ -o -name build -o \
         -name dist -o -name target -o -name .next -o \
         -name .turbo -o -name .cache \
      \) -prune \) -o \
    \( -name .git -print -prune \) 2>/dev/null \
  | awk '
      {
        slash = 0
        for (i = length($0); i > 0; i--) {
          if (substr($0, i, 1) == "/") { slash = i; break }
        }
        parent = (slash > 1) ? substr($0, 1, slash - 1) : "."
        if (!seen[parent]++) print parent
      }
    ' \
  | sort \
  | awk '
      {
        keep = 1
        for (i = 1; i <= n; i++) {
          if (index($0 "/", kept[i] "/") == 1 && $0 != kept[i]) {
            keep = 0; break
          }
        }
        if (keep) { n++; kept[n] = $0; print $0 }
      }
    '
}

if $WORKSPACE_MODE; then
  ws="${WORKSPACE_PATH:-.}"
  ws="$(cd "$ws" && pwd)"

  repos=$(discover_repos "$ws")
  if [ -z "$repos" ]; then
    echo "No git repositories found under: $ws" >&2
  else
    while IFS= read -r repo; do
      [ -n "$repo" ] || continue
      collect_from_repo "$repo"
    done <<< "$repos"
  fi
elif [ -n "$REPO_PATH" ]; then
  collect_from_repo "$(cd "$REPO_PATH" && pwd)"
else
  collect_from_repo "."
fi

WS_LABEL=""
if $WORKSPACE_MODE; then
  WS_LABEL="$REPOS_SCANNED"
fi

printf '%s' "$RAW" | awk \
  -v filter="$FILTER" \
  -v ws_label="$WS_LABEL" '
BEGIN {
  RS  = "---END---"
  FS  = "---F---"
  total = 0
}
function trim(s) {
  gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
  return s
}
function glob_match(s, g,    re) {
  re = g
  gsub(/[.+^$(){}|\\]/, "\\\\&", re)
  gsub(/\*/, ".*", re)
  gsub(/\?/, ".", re)
  return s ~ ("^" re "$")
}
{
  if (NF < 4) next
  phase_raw = trim($2)
  tool      = trim($3)
  ref       = trim($4)
  if (phase_raw == "") next
  if (filter != "" && !glob_match(ref, filter)) next

  total++   # count unique commits, not phase-instances

  n = split(phase_raw, phases, ",")
  for (i = 1; i <= n; i++) {
    p = trim(phases[i])
    if (p == "") continue
    phase_total[p]++
    if (tool != "" && tool != "manual") phase_ai[p]++
  }
}
function render(title, arr, n,    sum, has, i, p, tot, ai, rate, t) {
  sum = 0; has = 0
  for (i = 1; i <= n; i++) {
    if ((arr[i] in phase_total) && phase_total[arr[i]] > 0) {
      has = 1
      sum += phase_total[arr[i]]
    }
  }
  if (!has) return
  printf "  %s (%d commits)\n", title, sum
  print  "  --------------------------------"
  for (i = 1; i <= n; i++) {
    p = arr[i]
    tot = (p in phase_total) ? phase_total[p] : 0
    if (tot == 0) continue
    ai = (p in phase_ai) ? phase_ai[p] : 0
    rate = sprintf("%d%%", int(ai * 100 / tot))
    t = (p in tgt) ? (tgt[p] "%") : "—"
    printf "  %-20s %5s  (target: %s)  [%d/%d]\n", p, rate, t, ai, tot
  }
  print ""
}
END {
  if (total == 0) {
    print "No commits with AI trailers found."
    if (filter   != "") print "  (filter: Story-Ref = " filter ")"
    if (ws_label != "") print "  (scanned " ws_label " repo(s) in workspace)"
    exit 0
  }

  n_plan = split("prd architecture ux-design epics sprint-plan story", plan, " ")
  n_dev  = split("code test review deploy",                              dev,  " ")

  tgt["prd"]           = 90
  tgt["architecture"]  = 90
  tgt["ux-design"]     = 90
  tgt["epics"]         = 90
  tgt["sprint-plan"]   = 90
  tgt["story"]         = 90
  tgt["code"]          = 80
  tgt["test"]          = 85
  tgt["review"]        = 95
  tgt["deploy"]        = 80

  print ""
  print "======================================"
  print "  Pulse — AI Adoption Dashboard"
  print "======================================"
  if (filter   != "") print "  Filter: Story-Ref = " filter
  if (ws_label != "") print "  Repos scanned: " ws_label
  print ""

  render("PLANNING",    plan, n_plan)
  render("DEVELOPMENT", dev,  n_dev)

  printf "  TOTAL: %d tracked commits\n", total
  print "======================================"
  print ""
}
'
