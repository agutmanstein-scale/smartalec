#!/usr/bin/env bash
# Wait for another agent to change a feedback file, then print the entry headings it added.
#
# Usage: bash wait-for-reply.sh <feedback-file> <my-agent-id> [max-seconds]
#   Run it with the shell tool's background mode, right after your own write, so the
#   baseline is the file as you left it. You are notified once, when it exits.
#   max-seconds (default 14400) is a hard limit: no sleep runs past it.
# Env:   POLL (default 15) seconds between checks; SETTLE (default 45) seconds the file must
#        stay unchanged before it counts, so a half-written entry is never read.
# Exit:  0 changed (prints new headings not tagged with my id), 1 timed out, 2 file removed.
set -u
file=$1 me=$2 max=${3:-14400}
poll=${POLL:-15} settle=${SETTLE:-45}
deadline=$((SECONDS + max))
sum() { cksum < "$file"; }
others() { grep -n '^## ' "$file" | grep -v -- "$me" || true; }
# Sleep for $1 seconds or until the deadline, whichever is sooner. Prints 1 if the deadline cut it short.
nap() {
  local left=$((deadline - SECONDS))
  if [ "$left" -le 0 ]; then echo 1; return; fi
  if [ "$1" -le "$left" ]; then sleep "$1"; echo 0; else sleep "$left"; echo 1; fi
}

[ -f "$file" ] || { echo "MISSING $file"; exit 2; }
base=$(sum) before=$(others | cut -d: -f2-)
while [ "$(nap "$poll")" = 0 ] || [ "$SECONDS" -ge "$deadline" ]; do
  [ -f "$file" ] || { echo "REMOVED $file"; exit 2; }
  cur=$(sum)
  if [ "$cur" = "$base" ]; then
    [ "$SECONDS" -lt "$deadline" ] && continue
    echo "TIMEOUT after ${max}s with no change to $file"; exit 1
  fi
  note=""
  while :; do
    cut_short=$(nap "$settle")
    [ -f "$file" ] || { echo "REMOVED $file"; exit 2; }
    nxt=$(sum)
    if [ "$nxt" = "$cur" ]; then
      [ "$cut_short" = 1 ] && note=" (deadline reached before the file settled)"
      break
    fi
    cur=$nxt
    [ "$SECONDS" -lt "$deadline" ] || { note=" (still being written at the deadline)"; break; }
  done
  echo "CHANGED $file at $(date -u +%Y-%m-%dT%H:%M:%SZ)$note"
  others | while IFS= read -r line; do
    printf '%s\n' "$before" | grep -qxF -- "${line#*:}" || echo "NEW ENTRY L$line"
  done
  exit 0
done
echo "TIMEOUT after ${max}s with no change to $file"
exit 1
