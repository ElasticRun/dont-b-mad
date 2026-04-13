#!/usr/bin/env bash
#
# AI Adoption Dashboard (Pulse)
# Reads git commit trailers and prints adoption rates.
# Run from project root: bash .cursor/skills/bmad-ai-tracking/adoption-dashboard.sh
#
# Optional: pass a story prefix to filter (e.g. "1-" for epic 1)
#   bash adoption-dashboard.sh 1-
#
# Two trailer schemes:
#   Development commits: AI-Code, AI-Test, AI-Story, AI-Review, AI-Deploy
#   Planning commits:    AI-Artifact, AI-Author, AI-Review

FILTER="${1:-}"

# Development counters
DEV_TOTAL=0
AI_STORY=0
AI_CODE=0
AI_TEST=0
AI_REVIEW_DEV=0
AI_DEPLOY_AUTO=0
AI_DEPLOY_TOTAL=0
FULL_PIPELINE=0

# Planning counters
PLAN_TOTAL=0
AI_AUTHORED=0
AI_REVIEW_PLAN=0

# Parse commits using commit-boundary delimiter
while IFS= read -r line; do
  if [ "$line" = "---COMMIT---" ]; then
    if [ -n "$_artifact" ]; then
      # This is a planning commit
      if [ -n "$FILTER" ] && [[ "$_storyref" != ${FILTER}* ]]; then
        _artifact="" ; _author="" ; _review="" ; _storyref=""
        continue
      fi
      PLAN_TOTAL=$((PLAN_TOTAL + 1))
      [ "$_author" != "manual" ] && [ -n "$_author" ] && AI_AUTHORED=$((AI_AUTHORED + 1))
      [ "$_review" != "manual" ] && [ "$_review" != "pending" ] && [ -n "$_review" ] && AI_REVIEW_PLAN=$((AI_REVIEW_PLAN + 1))
    elif [ -n "$_code" ]; then
      # This is a development commit
      if [ -n "$FILTER" ] && [[ "$_storyref" != ${FILTER}* ]]; then
        _story="" ; _code="" ; _test="" ; _review="" ; _deploy="" ; _storyref=""
        continue
      fi
      DEV_TOTAL=$((DEV_TOTAL + 1))
      [ "$_story" != "manual" ] && AI_STORY=$((AI_STORY + 1))
      [ "$_code" != "manual" ] && AI_CODE=$((AI_CODE + 1))
      [ "$_test" != "manual" ] && AI_TEST=$((AI_TEST + 1))
      [ "$_review" != "manual" ] && [ "$_review" != "pending" ] && AI_REVIEW_DEV=$((AI_REVIEW_DEV + 1))
      if [ -n "$_deploy" ] && [ "$_deploy" != "pending" ]; then
        AI_DEPLOY_TOTAL=$((AI_DEPLOY_TOTAL + 1))
        [ "$_deploy" = "auto" ] && AI_DEPLOY_AUTO=$((AI_DEPLOY_AUTO + 1))
      fi
      if [ "$_story" != "manual" ] && [ "$_code" != "manual" ] && [ "$_test" != "manual" ] && \
         [ "$_review" != "manual" ] && [ "$_review" != "pending" ] && [ "$_deploy" = "auto" ]; then
        FULL_PIPELINE=$((FULL_PIPELINE + 1))
      fi
    fi
    _story="" ; _code="" ; _test="" ; _review="" ; _deploy="" ; _storyref="" ; _artifact="" ; _author=""
    continue
  fi

  key="${line%%:*}"
  val="$(echo "${line#*: }" | xargs)"
  case "$key" in
    AI-Story)    _story="$val" ;;
    AI-Code)     _code="$val" ;;
    AI-Test)     _test="$val" ;;
    AI-Review)   _review="$val" ;;
    AI-Deploy)   _deploy="$val" ;;
    Story-Ref)   _storyref="$val" ;;
    AI-Artifact) _artifact="$val" ;;
    AI-Author)   _author="$val" ;;
  esac
done < <(git log --format='---COMMIT---%n%(trailers:key=AI-Story)%(trailers:key=AI-Code)%(trailers:key=AI-Test)%(trailers:key=AI-Review)%(trailers:key=AI-Deploy)%(trailers:key=Story-Ref)%(trailers:key=AI-Artifact)%(trailers:key=AI-Author)')

# Process last commit
if [ -n "$_artifact" ]; then
  if [ -z "$FILTER" ] || [[ "$_storyref" == ${FILTER}* ]]; then
    PLAN_TOTAL=$((PLAN_TOTAL + 1))
    [ "$_author" != "manual" ] && [ -n "$_author" ] && AI_AUTHORED=$((AI_AUTHORED + 1))
    [ "$_review" != "manual" ] && [ "$_review" != "pending" ] && [ -n "$_review" ] && AI_REVIEW_PLAN=$((AI_REVIEW_PLAN + 1))
  fi
elif [ -n "$_code" ]; then
  if [ -z "$FILTER" ] || [[ "$_storyref" == ${FILTER}* ]]; then
    DEV_TOTAL=$((DEV_TOTAL + 1))
    [ "$_story" != "manual" ] && AI_STORY=$((AI_STORY + 1))
    [ "$_code" != "manual" ] && AI_CODE=$((AI_CODE + 1))
    [ "$_test" != "manual" ] && AI_TEST=$((AI_TEST + 1))
    [ "$_review" != "manual" ] && [ "$_review" != "pending" ] && AI_REVIEW_DEV=$((AI_REVIEW_DEV + 1))
    if [ -n "$_deploy" ] && [ "$_deploy" != "pending" ]; then
      AI_DEPLOY_TOTAL=$((AI_DEPLOY_TOTAL + 1))
      [ "$_deploy" = "auto" ] && AI_DEPLOY_AUTO=$((AI_DEPLOY_AUTO + 1))
    fi
    if [ "$_story" != "manual" ] && [ "$_code" != "manual" ] && [ "$_test" != "manual" ] && \
       [ "$_review" != "manual" ] && [ "$_review" != "pending" ] && [ "$_deploy" = "auto" ]; then
      FULL_PIPELINE=$((FULL_PIPELINE + 1))
    fi
  fi
fi

GRAND_TOTAL=$((DEV_TOTAL + PLAN_TOTAL))

if [ "$GRAND_TOTAL" -eq 0 ]; then
  echo "No commits with AI trailers found."
  [ -n "$FILTER" ] && echo "Filter: Story-Ref starting with '$FILTER'"
  exit 0
fi

pct() {
  if [ "$2" -eq 0 ]; then echo "N/A"; else echo "$(( ($1 * 100) / $2 ))%"; fi
}

echo "======================================"
echo "  Pulse — AI Adoption Dashboard"
echo "======================================"
[ -n "$FILTER" ] && echo "  Filter: Story-Ref = ${FILTER}*"
echo ""

if [ "$PLAN_TOTAL" -gt 0 ]; then
  echo "  PLANNING ($PLAN_TOTAL commits)"
  echo "  --------------------------------"
  printf "  AI Authored:      %4s\n" "$(pct $AI_AUTHORED $PLAN_TOTAL)"
  printf "  AI Reviewed:      %4s\n" "$(pct $AI_REVIEW_PLAN $PLAN_TOTAL)"
  echo ""
fi

if [ "$DEV_TOTAL" -gt 0 ]; then
  echo "  DEVELOPMENT ($DEV_TOTAL commits)"
  echo "  --------------------------------"
  printf "  AI Story Rate:    %4s  (target: 90%%)\n" "$(pct $AI_STORY $DEV_TOTAL)"
  printf "  AI Code Rate:     %4s  (target: 80%%)\n" "$(pct $AI_CODE $DEV_TOTAL)"
  printf "  AI Test Rate:     %4s  (target: 85%%)\n" "$(pct $AI_TEST $DEV_TOTAL)"
  printf "  AI Review Rate:   %4s  (target: 95%%)\n" "$(pct $AI_REVIEW_DEV $DEV_TOTAL)"
  if [ "$AI_DEPLOY_TOTAL" -gt 0 ]; then
    printf "  AI Deploy Rate:   %4s  (target: 80%%)\n" "$(pct $AI_DEPLOY_AUTO $AI_DEPLOY_TOTAL)"
  else
    echo "  AI Deploy Rate:    N/A  (no deploy-tagged commits)"
  fi
  printf "  Full Pipeline:    %4s  (target: 70%%)\n" "$(pct $FULL_PIPELINE $DEV_TOTAL)"
  echo ""
fi

echo "  TOTAL: $GRAND_TOTAL tracked commits"
echo "======================================"
