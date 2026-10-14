# smartalec

Agent skills for [Claude Code](https://claude.com/claude-code).

## Skills

| Skill | Use it to |
|---|---|
| [`running-milestone-loops`](skills/running-milestone-loops/SKILL.md) | Drive a milestone, epic or ticket set to done over hours or days while you're away. A design doc and your tracker (e.g. Linear) are the sources of truth. Each unit is implemented, reviewed by three independent read-only reviewers (conformance, breaker and tests), fixed and given a PR description. Anything that leaves your branches (pushes, merges, tracker writes, chat messages) is governed by a permissions table you approve. The loop keeps its state in files, so it survives context compactions, scheduled wakeups and hand-offs to another machine. |

## Install

Copy or symlink a skill into your personal skills directory:

```bash
git clone https://github.com/agutmanstein-scale/smartalec.git
mkdir -p ~/.claude/skills
ln -s "$PWD/smartalec/skills/running-milestone-loops" ~/.claude/skills/running-milestone-loops
```

Claude Code picks it up in the next session. To start a loop, ask it to loop on a milestone, e.g. `/loop drive milestone M4 to done`. The skill sets up the loop directory, asks you once about the permissions it can't infer, and then works through the queue.

## Requirements

`running-milestone-loops` runs each unit through `unit-pipeline.js` with Claude Code's Workflow tool, which orchestrates multiple subagents. Workflows can spawn many agents; each unit uses 5 to 8.

## License

[MIT](LICENSE)
