# smartalec

Agent skills for [Claude Code](https://claude.com/claude-code).

## Skills

| Skill | Use it to |
|---|---|
| [`running-milestone-loops`](skills/running-milestone-loops/SKILL.md) | Drive a milestone, epic or ticket set to done over hours or days while you're away. A design doc and your tracker (e.g. Linear) are the sources of truth. Each unit is implemented, reviewed by three independent read-only reviewers (conformance, breaker and tests), fixed and given a PR description. Anything that leaves your branches (pushes, merges, tracker writes, chat messages) is governed by a permissions table you approve. The loop keeps its state in files, so it survives context compactions, scheduled wakeups and hand-offs to another machine. |
| [`collaborative-design-review`](skills/collaborative-design-review/SKILL.md) | Review a design spec, ADR or RFC adversarially, then talk it through with the author or another agent in a feedback file beside the spec. The review checks that cited sources are the newest revision, recomputes every number, checks code claims against the default branch, and looks for sampling artifacts, missing success criteria and unbounded migrations. Each entry in the file carries its writer's UUID and the hash of the spec version it read, and findings keep stable numbers. A background helper waits for a reply and reads it only once it has finished being written. Each "fixed" claim is checked against the changed spec before it is marked resolved. |
| [`mirroring-claude-over-ssh`](skills/mirroring-claude-over-ssh/SKILL.md) | Put your Claude Code setup on a remote Linux machine you reach over ssh (a cloud VM, a devbox, a lab server). One script checks the host, installs Claude Code, `gh` and the `gh stack` extension, copies your CLAUDE.md, AGENTS.md, skills and settings, and installs your plugins, private marketplaces included. It never copies credentials. You get a copy-paste for the logins you do yourself (Claude, `gh`, Slack), and steps for getting other MCP sign-ins through a tunnel when their callback lands on a dead `localhost` page. |

## Install

Copy or symlink a skill into your personal skills directory:

```bash
git clone https://github.com/agutmanstein-scale/smartalec.git
mkdir -p ~/.claude/skills
ln -s "$PWD/smartalec/skills/running-milestone-loops" ~/.claude/skills/running-milestone-loops
```

Swap in `mirroring-claude-over-ssh` or `collaborative-design-review` for that skill. Claude Code picks it up in the next session. To mirror your setup, ask it to set up Claude on a host, e.g. `put my Claude setup on my-vm`. To review a spec, ask for one and say where replies should go, e.g. `review docs/specs/cache-design.md adversarially, put it in a feedback file and wait for a response`. To start a loop, ask it to loop on a milestone, e.g. `/loop drive milestone M4 to done`. The skill sets up the loop directory, asks you once about the permissions it can't infer, and then works through the queue.

## Requirements

`mirroring-claude-over-ssh` needs key-based ssh to a Linux host (x86_64 or aarch64) with `bash`, `curl`, `tar` and `python3`, and git 2.36 or newer for `gh stack`. No sudo.

`running-milestone-loops` stacks PRs with `gh stack` (`gh extension install github/gh-stack`, git 2.36 or newer) and runs each unit through `unit-pipeline.js` with Claude Code's Workflow tool, which orchestrates multiple subagents. Workflows can spawn many agents; each unit uses 5 to 8.

`collaborative-design-review` needs `bash`, `cksum` and `uuidgen`. Its tests run with `uv run --python 3.11 --with pytest pytest skills/collaborative-design-review/tests`.

## License

[MIT](LICENSE)
