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

# gh and its stack extension. `gh extension install` needs a login the box doesn't have yet, so the release
# binaries go where gh looks for them. Neither needs sudo.
latest() { curl -fsSLI --retry 3 -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed 's|.*/||'; }
case $(uname -m) in x86_64) arch=amd64 ;; aarch64) arch=arm64 ;; esac
if ! command -v gh >/dev/null; then
  v=$(latest cli/cli); v=${v#v}
  d=$(mktemp -d)
  curl -fsSL --retry 3 "https://github.com/cli/cli/releases/download/v$v/gh_${v}_linux_$arch.tar.gz" | tar xz -C "$d"
  install -m 755 "$d/gh_${v}_linux_$arch/bin/gh" ~/.local/bin/gh
fi
ext=${XDG_DATA_HOME:-$HOME/.local/share}/gh/extensions/gh-stack
if [ ! -x "$ext/gh-stack" ]; then
  tag=$(latest github/gh-stack)
  mkdir -p "$ext"
  curl -fsSL --retry 3 -o "$ext/gh-stack" "https://github.com/github/gh-stack/releases/download/$tag/linux-$arch"
  chmod 755 "$ext/gh-stack"
  printf 'owner: github\nname: gh-stack\nhost: github.com\ntag: %s\nispinned: false\npath: %s\n' "$tag" "$ext/gh-stack" > "$ext/manifest.yml"
fi

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
gv=$(git --version 2>/dev/null | awk '{print $3}')
if [ -n "$gv" ] && [ "$(printf '%s\n2.36\n' "$gv" | sort -V | head -1)" = 2.36 ]; then gs="$(GH_STACK_NO_UPDATE_NOTIFIER=1 gh stack --version 2>&1 | head -1) (git $gv)"
else gs="gh stack installed but git is ${gv:-missing}, it needs 2.36+ (user step)"; fi
echo "$gs"
echo "skills: $(ls ~/.claude/skills | grep -vc '\.zip$'), plugins enabled: $(claude plugin list 2>/dev/null | grep -ci enabled)"
gh auth status >/dev/null 2>&1 && echo "gh: logged in" || echo "gh: NOT logged in (user step)"
rm -rf "$B"
