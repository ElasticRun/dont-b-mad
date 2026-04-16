#!/usr/bin/env bash
#
# Pulse — AI Adoption Dashboard
# Reads AI-Phase / AI-Tool / Story-Ref trailers from git history
# and shows adoption rates grouped by phase.
#
# Usage:
#   bash adoption-dashboard.sh              # all commits
#   bash adoption-dashboard.sh "1-*"        # filter by Story-Ref pattern

set -euo pipefail

FILTER="${1:-}"

DELIM="---COMMIT---"

RAW=$(git log --all --format="%H${DELIM}%(trailers:key=AI-Phase,valueonly)${DELIM}%(trailers:key=AI-Tool,valueonly)${DELIM}%(trailers:key=Story-Ref,valueonly)" 2>/dev/null || true)

if [ -z "$RAW" ]; then
  echo "No git history found."
  exit 1
fi

declare -A phase_total
declare -A phase_ai
total_tracked=0

while IFS= read -r line; do
  [ -z "$line" ] && continue

  hash=$(echo "$line" | awk -F"$DELIM" '{print $1}')
  phase=$(echo "$line" | awk -F"$DELIM" '{print $2}' | xargs 2>/dev/null || true)
  tool=$(echo "$line" | awk -F"$DELIM" '{print $3}' | xargs 2>/dev/null || true)
  ref=$(echo "$line" | awk -F"$DELIM" '{print $4}' | xargs 2>/dev/null || true)

  # Skip commits without AI-Phase trailer
  [ -z "$phase" ] && continue

  # Apply Story-Ref filter if specified
  if [ -n "$FILTER" ]; then
    case "$ref" in
      $FILTER) ;; # matches
      *) continue ;;
    esac
  fi

  total_tracked=$((total_tracked + 1))
  phase_total[$phase]=$(( ${phase_total[$phase]:-0} + 1 ))

  if [ "$tool" != "manual" ] && [ -n "$tool" ]; then
    phase_ai[$phase]=$(( ${phase_ai[$phase]:-0} + 1 ))
  fi

done <<< "$RAW"

if [ "$total_tracked" -eq 0 ]; then
  echo "No commits with AI trailers found."
  [ -n "$FILTER" ] && echo "  (filter: Story-Ref = $FILTER)"
  exit 0
fi

# Phase display order and targets
declare -a PLANNING_PHASES=("prd" "architecture" "ux-design" "epics" "sprint-plan" "story")
declare -a DEV_PHASES=("code" "test" "review" "deploy")

declare -A TARGETS=(
  ["prd"]="90" ["architecture"]="90" ["ux-design"]="90" ["epics"]="90"
  ["sprint-plan"]="90" ["story"]="90"
  ["code"]="80" ["test"]="85" ["review"]="95" ["deploy"]="80"
)

pct() {
  local ai=${1:-0}
  local tot=${2:-0}
  if [ "$tot" -eq 0 ]; then echo "—"; else echo "$(( ai * 100 / tot ))%"; fi
}

echo ""
echo "======================================"
echo "  Pulse — AI Adoption Dashboard"
echo "======================================"
[ -n "$FILTER" ] && echo "  Filter: Story-Ref = $FILTER"
echo ""

# Planning phases
planning_count=0
has_planning=false
for p in "${PLANNING_PHASES[@]}"; do
  if [ "${phase_total[$p]:-0}" -gt 0 ]; then
    has_planning=true
    planning_count=$((planning_count + ${phase_total[$p]}))
  fi
done

if $has_planning; then
  echo "  PLANNING ($planning_count commits)"
  echo "  --------------------------------"
  for p in "${PLANNING_PHASES[@]}"; do
    tot=${phase_total[$p]:-0}
    [ "$tot" -eq 0 ] && continue
    ai=${phase_ai[$p]:-0}
    rate=$(pct "$ai" "$tot")
    target=${TARGETS[$p]:-"—"}
    printf "  %-20s %5s  (target: %s%%)  [%d/%d]\n" "$p" "$rate" "$target" "$ai" "$tot"
  done
  echo ""
fi

# Development phases
dev_count=0
has_dev=false
for p in "${DEV_PHASES[@]}"; do
  if [ "${phase_total[$p]:-0}" -gt 0 ]; then
    has_dev=true
    dev_count=$((dev_count + ${phase_total[$p]}))
  fi
done

if $has_dev; then
  echo "  DEVELOPMENT ($dev_count commits)"
  echo "  --------------------------------"
  for p in "${DEV_PHASES[@]}"; do
    tot=${phase_total[$p]:-0}
    [ "$tot" -eq 0 ] && continue
    ai=${phase_ai[$p]:-0}
    rate=$(pct "$ai" "$tot")
    target=${TARGETS[$p]:-"—"}
    printf "  %-20s %5s  (target: %s%%)  [%d/%d]\n" "$p" "$rate" "$target" "$ai" "$tot"
  done
  echo ""
fi

echo "  TOTAL: $total_tracked tracked commits"
echo "======================================"
echo ""
