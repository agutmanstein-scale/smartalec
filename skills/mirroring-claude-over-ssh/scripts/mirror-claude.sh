#!/usr/bin/env bash
# Mirror this Mac's Claude Code setup onto a devbox over ssh: instructions, skills, settings (rtk hook),
# marketplaces and plugins. Never copies credentials (.credentials.json, ~/.claude.json, gh tokens).
# usage: bash mirror-claude.sh <ssh host>   (any Linux host reachable with key-based ssh)
set -euo pipefail
host=${1:?usage: mirror-claude.sh <ssh host>}
here=$(cd "$(dirname "$0")" && pwd)
quiet() { grep -v -e 'Ephemeral SSH key' -e 'Pushing SSH public key' || true; }

check=$(ssh -o BatchMode=yes -o ConnectTimeout=20 "$host" 'm=""; [ "$(uname -s)" = Linux ] || m="$m os=$(uname -s)"
  case $(uname -m) in x86_64|aarch64) ;; *) m="$m arch=$(uname -m)" ;; esac
  for c in bash curl tar python3; do command -v $c >/dev/null || m="$m $c"; done
  command -v git >/dev/null || echo "NOTE: no git on the host; gh stack needs git 2.36+"
  echo "MISSING:$m"' 2>&1 | quiet) || true
if ! grep -q '^MISSING:' <<<"$check"; then
  echo "can't reach $host with key-based ssh (BatchMode): $check" >&2; exit 1
fi
grep '^NOTE:' <<<"$check" || true
missing=$(sed -n 's/^MISSING: *//p' <<<"$check")
if [ -n "$missing" ]; then
  echo "$host can't take the mirror; missing or unsupported: $missing (needs Linux x86_64/aarch64 with bash, curl, tar, python3)" >&2
  exit 1
fi
C=$HOME/.claude
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
b=$work/claude-mirror
mkdir -p "$b/marketplaces"

present=()
for f in CLAUDE.md RTK.md skills; do [ -e "$C/$f" ] && present+=("$f"); done
(cd "$C" && COPYFILE_DISABLE=1 tar --exclude=.DS_Store -czf "$b/claude.tgz" "${present[@]}")
[ -f "$HOME/AGENTS.md" ] && cp "$HOME/AGENTS.md" "$b/AGENTS.md"
# Settings go through a filter that drops API keys, tokens and credential helpers.
python3 "$here/scrub_settings.py" "$C/settings.json" "$b/settings.mac.json"
[ -f "$C/settings.local.json" ] && python3 "$here/scrub_settings.py" "$C/settings.local.json" "$b/settings.local.json"

# The box clones claude-plugins-official itself; every other marketplace (private ones included) is copied from the
# local checkout, and is registered under the name its marketplace.json declares, which can differ from the local key.
python3 "$here/bundle_marketplaces.py" "$C/plugins" "$b"
cp "$here/remote-setup.sh" "$here/merge_settings.py" "$b/"

# A private directory on the host, so nobody else can plant files where the setup script runs.
rd=$(ssh -o BatchMode=yes "$host" 'mktemp -d' 2>&1 | quiet | tail -1)
case $rd in /*) ;; *) echo "can't make a private directory on $host: $rd" >&2; exit 1 ;; esac
scp -q -r -o BatchMode=yes "$b/." "$host:$rd/" 2>&1 | quiet
ssh -o BatchMode=yes "$host" "bash '$rd/remote-setup.sh' '$rd'" 2>&1 | quiet
