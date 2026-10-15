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
  command -v gh >/dev/null || echo "NOTE: no gh on the host; the GitHub login step needs it"
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
for f in CLAUDE.md RTK.md settings.local.json skills; do [ -e "$C/$f" ] && present+=("$f"); done
(cd "$C" && COPYFILE_DISABLE=1 tar --exclude=.DS_Store -czf "$b/claude.tgz" "${present[@]}")
[ -f "$HOME/AGENTS.md" ] && cp "$HOME/AGENTS.md" "$b/AGENTS.md"
cp "$C/settings.json" "$b/settings.mac.json"

# The box clones claude-plugins-official itself; every other marketplace (private ones included) is copied from the
# local checkout, and is registered under the name its marketplace.json declares, which can differ from the local key.
python3 - "$C/plugins" "$b" <<'EOF'
import json, os, subprocess, sys
plugins, b = sys.argv[1], sys.argv[2]
known = json.load(open(os.path.join(plugins, "known_marketplaces.json")))
renames = {}
for key, m in known.items():
    if key == "claude-plugins-official":
        continue
    loc = m.get("installLocation") or os.path.join(plugins, "marketplaces", key)
    name = json.load(open(os.path.join(loc, ".claude-plugin", "marketplace.json"))).get("name", key)
    renames[key] = name
    subprocess.run(["tar", "--exclude=.git", "--exclude=.DS_Store", "-czf",
                    os.path.join(b, "marketplaces", f"{key}.tgz"), "-C", os.path.dirname(loc), os.path.basename(loc)],
                   check=True, env={**os.environ, "COPYFILE_DISABLE": "1"})
json.dump(renames, open(os.path.join(b, "renames.json"), "w"))
ids = json.load(open(os.path.join(plugins, "installed_plugins.json")))["plugins"]
with open(os.path.join(b, "plugins.txt"), "w") as fh:
    for pid in sorted(ids):
        name, _, market = pid.rpartition("@")
        fh.write(f"{name}@{renames.get(market, market)}\n")
EOF
cp "$here/remote-setup.sh" "$b/remote-setup.sh"

ssh -o BatchMode=yes "$host" 'rm -rf /tmp/claude-mirror' 2>&1 | quiet
scp -q -r -o BatchMode=yes "$b" "$host:/tmp/" 2>&1 | quiet
ssh -o BatchMode=yes "$host" 'bash /tmp/claude-mirror/remote-setup.sh' 2>&1 | quiet
