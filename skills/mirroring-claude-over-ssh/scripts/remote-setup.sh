#!/usr/bin/env bash
# Runs on the devbox from /tmp/claude-mirror (uploaded by mirror-claude.sh). Safe to re-run.
set -euo pipefail
B=/tmp/claude-mirror
export PATH=$HOME/.local/bin:$PATH
mkdir -p ~/.local/bin ~/.claude ~/plugin-marketplaces

# A settings hook that runs `rtk hook claude` on every Bash call needs rtk on the host before the settings land.
needs_rtk=$(grep -q '"rtk hook' "$B/settings.mac.json" && echo yes || echo no)
if [ "$needs_rtk" = yes ] && ! command -v rtk >/dev/null; then
  case $(uname -m) in
    x86_64) asset=rtk-x86_64-unknown-linux-musl.tar.gz ;;
    aarch64) asset=rtk-aarch64-unknown-linux-gnu.tar.gz ;;
    *) echo "no rtk build for $(uname -m)" >&2; exit 1 ;;
  esac
  d=$(mktemp -d)
  curl -fsSL "https://github.com/rtk-ai/rtk/releases/latest/download/$asset" | tar xz -C "$d"
  install -m 755 "$(find "$d" -type f -name rtk | head -1)" ~/.local/bin/rtk
fi
if [ "$needs_rtk" = yes ]; then
  printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | rtk hook claude | grep -q 'rtk git status'
fi

command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash >/dev/null

tar xzf "$B/claude.tgz" -C ~/.claude
[ -f "$B/AGENTS.md" ] && cp "$B/AGENTS.md" ~/AGENTS.md

for t in "$B"/marketplaces/*.tgz; do
  [ -e "$t" ] || continue
  key=$(basename "$t" .tgz)
  rm -rf ~/plugin-marketplaces/"$key"
  tar xzf "$t" -C ~/plugin-marketplaces
  claude plugin marketplace add ~/plugin-marketplaces/"$key" < /dev/null | tail -1
done

while read -r pid; do
  [ -n "$pid" ] && claude plugin install "$pid" --scope user < /dev/null | tail -1
done < "$B/plugins.txt"

# Mac settings win, the box's own keys (e.g. theme) stay, plugin ids follow the marketplace renames.
python3 - "$B/settings.mac.json" "$B/renames.json" <<'EOF'
import json, os, shutil, sys
p = os.path.expanduser("~/.claude/settings.json")
box = json.load(open(p)) if os.path.exists(p) else {}
if os.path.exists(p) and not os.path.exists(p + ".pre-mirror"):
    shutil.copy(p, p + ".pre-mirror")
mac, renames = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
def rename(pid):
    name, _, market = pid.rpartition("@")
    return f"{name}@{renames.get(market, market)}" if name else pid
enabled = {**box.get("enabledPlugins", {}), **{rename(k): v for k, v in mac.get("enabledPlugins", {}).items()}}
json.dump({**box, **mac, "enabledPlugins": enabled}, open(p, "w"), indent=2)
EOF

echo "rtk $(command -v rtk >/dev/null && rtk --version | cut -d' ' -f2 || echo 'not needed'), $(claude --version)"
echo "skills: $(ls ~/.claude/skills | grep -vc '\.zip$'), plugins enabled: $(claude plugin list 2>/dev/null | grep -ci enabled)"
gh auth status >/dev/null 2>&1 && echo "gh: logged in" || echo "gh: NOT logged in (user step)"
rm -rf "$B"
