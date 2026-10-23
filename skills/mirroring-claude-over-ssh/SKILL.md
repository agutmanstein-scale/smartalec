---
name: mirroring-claude-over-ssh
description: Use when Claude Code on a remote Linux machine reachable over ssh (devbox, EC2 or cloud VM, lab server, container with sshd) needs the Mac's setup — skills, CLAUDE.md, plugins, rtk hook, gh login, Slack or other MCP sign-ins — or when an MCP sign-in link from a remote Claude lands on a dead localhost page.
---

# Mirroring Claude over ssh

A remote Claude Code starts with none of the Mac's setup. The mirror copies everything except credentials; the
logins are the user's to do.

## 1. Mirror (from the Mac)

```bash
bash "<dir of this SKILL.md>/scripts/mirror-claude.sh" <ssh-host>   # ~30 s, safe to re-run
```

Run it from wherever this skill is installed (`~/.claude/skills/mirroring-claude-over-ssh` or the plugin cache), not from a
hard-coded path. It checks the host first and stops with what's missing. The host needs Linux on x86_64 or aarch64, `bash`, `curl`,
`tar` and `python3`, and key-based ssh (it runs with `BatchMode`); `git` 2.36 or newer is needed for `gh stack` and
it prints a note if `git` is missing. No sudo.

Then it installs Claude Code, plus the Linux `rtk` into `~/.local/bin` when the settings have an `rtk hook` (a hook
that runs on every Bash call breaks every Bash call without it). It also puts `gh` (if the host has none) and the
`gh stack` extension into `~/.local`, so stacked PRs work as soon as you've logged in to `gh`. It copies CLAUDE.md, RTK.md, AGENTS.md,
settings.local.json and skills (whichever exist), merges settings.json (the Mac's keys win, the host's stay, a
`.pre-mirror` backup is kept), copies every marketplace except `claude-plugins-official` from its local checkout (so
private ones need no GitHub auth on the host) and installs every plugin. A marketplace registers on the host under
the name in its `marketplace.json`, which can differ from the local name it was added under; the script rewrites
plugin ids to match.

Not copied: `.credentials.json`, `~/.claude.json` (MCP servers and OAuth tokens), history, memory (keyed by the
Mac's paths). Both settings files go through a filter that drops `apiKeyHelper` and the other credential helpers and
every `env` entry whose name contains key, token, secret, password, credential or auth, and it prints what it dropped.
The upload lands in a private `mktemp -d` directory on the host, which the setup script removes at the end.

## 2. Logins: the user runs these

Moving tokens is the user's call: piping `gh auth token` to the host, or writing a token export, is blocked by auto
mode as credential leakage. Hand over this copy-paste, with the host filled in (`bash`; use `~/.zshrc` on zsh):

```bash
ssh -t -L 3118:localhost:3118 <ssh-host>
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
grep -q GITHUB_PERSONAL_ACCESS_TOKEN ~/.bashrc || echo 'export GITHUB_PERSONAL_ACCESS_TOKEN="$(gh auth token 2>/dev/null)"' >> ~/.bashrc
source ~/.bashrc
tmux new -s work
claude    # /login, then /mcp → slack → Authenticate; paste any other server's sign-in link to the Mac session
```

The github plugin's MCP reads `GITHUB_PERSONAL_ACCESS_TOKEN` when Claude starts.

## 3. When the user pastes an MCP sign-in link from the host

`/mcp` → Authenticate on the host prints an authorize URL whose callback is `localhost:<port>` in the Mac's browser.

1. Port: `redirect_uri=http%3A%2F%2Flocalhost%3A<port>`. Slack is always 3118; Linear, Notion, Atlassian and the
   rest pick a random one per attempt.
2. Mac side: `lsof -nP -iTCP:<port> -sTCP:LISTEN`. An `ssh` holding it (the login session's `-L 3118`) is the
   tunnel already; a second one fails with "address already in use".
3. Host side: `ssh <ssh-host> "ss -ltn | grep :<port>"` must show `claude` listening. Nothing there means that
   attempt already finished or timed out: ask the user whether it connected, and if not, have them run
   Authenticate again for a fresh link (a new port).
4. No Mac-side listener: run `ssh -N -o ExitOnForwardFailure=yes -L <port>:localhost:<port> <ssh-host>` in the
   background, then have the user approve, or refresh the dead callback page if they already approved.
5. Ask the user whether it connected rather than probing the host, then stop the tunnel.

Fallback without a tunnel: `ssh <ssh-host> "curl '<callback url>'"` with the dead page's full URL (the code is
single-use and expires in minutes).

## Common mistakes

| Mistake | Consequence |
|---|---|
| Installing Claude and stopping | The host has none of the user's skills or plugins |
| Copying settings.json without the Linux rtk | Every Bash call on the host fails in the hook |
| A mirror on a Mac or non-Linux host | The rtk step has no build for it; the host check stops it |

## Hand back

The host, what the mirror printed, and the login copy-paste.
