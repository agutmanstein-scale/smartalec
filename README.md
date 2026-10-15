# smartalec

Agent skills for [Claude Code](https://claude.com/claude-code).

## Skills

| Skill | Use it to |
|---|---|
| [`running-milestone-loops`](skills/running-milestone-loops/SKILL.md) | Drive a milestone, epic or ticket set to done over hours or days while you're away. A design doc and your tracker (e.g. Linear) are the sources of truth. Each unit is implemented, reviewed by three independent read-only reviewers (conformance, breaker and tests), fixed and given a PR description. Anything that leaves your branches (pushes, merges, tracker writes, chat messages) is governed by a permissions table you approve. The loop keeps its state in files, so it survives context compactions, scheduled wakeups and hand-offs to another machine. |
| [`mirroring-claude-over-ssh`](skills/mirroring-claude-over-ssh/SKILL.md) | Put your Claude Code setup on a remote Linux machine you reach over ssh (a cloud VM, a devbox, a lab server). One script checks the host, installs Claude Code, copies your CLAUDE.md, AGENTS.md, skills and settings, and installs your plugins, private marketplaces included. It never copies credentials. You get a copy-paste for the logins you do yourself (Claude, `gh`, Slack), and steps for getting other MCP sign-ins through a tunnel when their callback lands on a dead `localhost` page. |

## Install

Copy or symlink a skill into your personal skills directory:

```bash
git clone https://github.com/agutmanstein-scale/smartalec.git
mkdir -p ~/.claude/skills
ln -s "$PWD/smartalec/skills/running-milestone-loops" ~/.claude/skills/running-milestone-loops
```

Swap in `mirroring-claude-over-ssh` for that skill. Claude Code picks it up in the next session. To mirror your setup, ask it to set up Claude on a host, e.g. `put my Claude setup on my-vm`. To start a loop, ask it to loop on a milestone, e.g. `/loop drive milestone M4 to done`. The skill sets up the loop directory, asks you once about the permissions it can't infer, and then works through the queue.

## Requirements

`mirroring-claude-over-ssh` needs key-based ssh to a Linux host (x86_64 or aarch64) with `bash`, `curl`, `tar` and `python3`, and `gh` there for the GitHub login. No sudo.

`running-milestone-loops` runs each unit through `unit-pipeline.js` with Claude Code's Workflow tool, which orchestrates multiple subagents. Workflows can spawn many agents; each unit uses 5 to 8.

## License

[MIT](LICENSE)
