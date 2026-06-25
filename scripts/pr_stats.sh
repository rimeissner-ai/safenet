#!/usr/bin/env bash
# PR statistics: time open (in review) and comment counts.
# Usage: ./pr_stats.sh [--owner ORG] [--repo NAME] [--state open|closed|all] [--limit N] [--since YYYY-MM-DD]
# Requires: curl, jq. GITHUB_TOKEN is optional (raises rate limit from 60 to 5000 req/hr).

set -euo pipefail

OWNER="safe-research"
REPO="safenet"
STATE="all"
LIMIT=500
SINCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner) OWNER="$2"; shift 2 ;;
    --repo)  REPO="$2";  shift 2 ;;
    --state) STATE="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "Error: jq is required." >&2; exit 1; }

API="https://api.github.com"
ACCEPT_HEADER="Accept: application/vnd.github+json"

AUTH_ARGS=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  AUTH_ARGS=(-H "Authorization: Bearer $GITHUB_TOKEN")
else
  echo "Note: GITHUB_TOKEN not set — using unauthenticated requests (60 req/hr limit)."
fi

per_page=100
page=1
prs=()

since_epoch=0
if [[ -n "$SINCE" ]]; then
  since_epoch=$(date -u -d "$SINCE" +%s 2>/dev/null || date -u -jf "%Y-%m-%d" "$SINCE" +%s)
  echo "Fetching PRs (state=$STATE, since=$SINCE) from $OWNER/$REPO ..."
else
  echo "Fetching PRs (state=$STATE, limit=$LIMIT) from $OWNER/$REPO ..."
fi

while true; do
  response=$(curl -sf \
    "${AUTH_ARGS[@]}" \
    -H "$ACCEPT_HEADER" \
    "$API/repos/$OWNER/$REPO/pulls?state=$STATE&per_page=$per_page&page=$page&sort=created&direction=desc")

  count=$(echo "$response" | jq 'length')
  [[ "$count" -eq 0 ]] && break

  mapfile -t batch < <(echo "$response" | jq -c '.[]')

  if [[ "$since_epoch" -gt 0 ]]; then
    stop_paging=false
    for item in "${batch[@]}"; do
      item_created=$(echo "$item" | jq -r '.created_at')
      item_epoch=$(date -u -d "$item_created" +%s 2>/dev/null || date -u -jf "%Y-%m-%dT%H:%M:%SZ" "$item_created" +%s)
      if [[ "$item_epoch" -ge "$since_epoch" ]]; then
        prs+=("$item")
      else
        stop_paging=true
      fi
    done
    $stop_paging && break
  else
    prs+=("${batch[@]}")
  fi

  [[ "${#prs[@]}" -ge "$LIMIT" ]] && break
  [[ "$count" -lt "$per_page" ]] && break

  page=$(( page + 1 ))
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
  pr_detail=$(curl -sf "${AUTH_ARGS[@]}" -H "$ACCEPT_HEADER" \
    "$API/repos/$OWNER/$REPO/pulls/$number")
  comments=$(echo "$pr_detail" | jq -r '.comments // 0')
  review_comments=$(echo "$pr_detail" | jq -r '.review_comments // 0')
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
  count_with_duration=$(( count_with_duration + 1 ))

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
