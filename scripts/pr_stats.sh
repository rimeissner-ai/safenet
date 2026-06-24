#!/usr/bin/env bash
# PR statistics: time open (in review) and comment counts.
# Usage: ./pr_stats.sh [--state open|closed|all] [--limit N]
# Requires: GITHUB_TOKEN env var, curl, jq

set -euo pipefail

OWNER="rimeissner-ai"
REPO="safenet"
STATE="all"
LIMIT=50

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state) STATE="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "Error: GITHUB_TOKEN is not set." >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "Error: jq is required." >&2; exit 1; }

API="https://api.github.com"
AUTH_HEADER="Authorization: Bearer $GITHUB_TOKEN"
ACCEPT_HEADER="Accept: application/vnd.github+json"

per_page=100
page=1
prs=()

echo "Fetching PRs (state=$STATE, limit=$LIMIT) from $OWNER/$REPO ..."

while true; do
  response=$(curl -sf \
    -H "$AUTH_HEADER" \
    -H "$ACCEPT_HEADER" \
    "$API/repos/$OWNER/$REPO/pulls?state=$STATE&per_page=$per_page&page=$page&sort=created&direction=desc")

  count=$(echo "$response" | jq 'length')
  [[ "$count" -eq 0 ]] && break

  mapfile -t batch < <(echo "$response" | jq -c '.[]')
  prs+=("${batch[@]}")

  [[ "${#prs[@]}" -ge "$LIMIT" ]] && break
  [[ "$count" -lt "$per_page" ]] && break

  ((page++))
done

prs=("${prs[@]:0:$LIMIT}")
total="${#prs[@]}"

if [[ "$total" -eq 0 ]]; then
  echo "No PRs found."
  exit 0
fi

# Column widths
printf "\n%-6s %-10s %-55s %-20s %-20s %-12s %-10s\n" \
  "PR#" "State" "Title" "Opened" "Closed/Now" "Duration" "Comments"
printf '%.0s-' {1..140}; echo

sum_hours=0
sum_comments=0
count_with_duration=0

now_epoch=$(date -u +%s)

for pr in "${prs[@]}"; do
  number=$(echo "$pr" | jq -r '.number')
  title=$(echo "$pr"  | jq -r '.title')
  state=$(echo "$pr"  | jq -r '.state')
  created=$(echo "$pr" | jq -r '.created_at')
  closed=$(echo "$pr"  | jq -r '.closed_at // empty')
  comments=$(echo "$pr" | jq -r '.comments')
  review_comments=$(echo "$pr" | jq -r '.review_comments')
  total_comments=$((comments + review_comments))

  created_epoch=$(date -u -d "$created" +%s 2>/dev/null || date -u -jf "%Y-%m-%dT%H:%M:%SZ" "$created" +%s)

  if [[ -n "$closed" ]]; then
    end_epoch=$(date -u -d "$closed" +%s 2>/dev/null || date -u -jf "%Y-%m-%dT%H:%M:%SZ" "$closed" +%s)
    end_label=$(echo "$closed" | cut -c1-19 | tr 'T' ' ')
  else
    end_epoch=$now_epoch
    end_label="(open now)"
  fi

  diff_secs=$(( end_epoch - created_epoch ))
  diff_hours=$(( diff_secs / 3600 ))
  diff_days=$(( diff_hours / 24 ))
  rem_hours=$(( diff_hours % 24 ))

  if [[ "$diff_days" -gt 0 ]]; then
    duration="${diff_days}d ${rem_hours}h"
  else
    duration="${diff_hours}h"
  fi

  sum_hours=$(( sum_hours + diff_hours ))
  sum_comments=$(( sum_comments + total_comments ))
  ((count_with_duration++))

  # Truncate title
  short_title="${title:0:54}"
  created_label=$(echo "$created" | cut -c1-19 | tr 'T' ' ')

  printf "%-6s %-10s %-55s %-20s %-20s %-12s %-10s\n" \
    "#$number" "$state" "$short_title" "$created_label" "$end_label" "$duration" "$total_comments"
done

printf '%.0s-' {1..140}; echo

avg_hours=$(( sum_hours / count_with_duration ))
avg_days=$(( avg_hours / 24 ))
avg_rem=$(( avg_hours % 24 ))
avg_comments_int=$(( sum_comments / total ))

echo ""
echo "Summary ($total PRs):"
printf "  Average time open : %dd %dh\n" "$avg_days" "$avg_rem"
printf "  Average comments  : %d\n" "$avg_comments_int"
printf "  Total comments    : %d\n" "$sum_comments"
echo ""
