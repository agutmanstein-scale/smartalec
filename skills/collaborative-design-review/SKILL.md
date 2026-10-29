---
name: collaborative-design-review
description: Use when asked to adversarially review, critique, red-team or poke holes in a design spec, ADR, RFC or proposal, when a review should go into a feedback file beside the spec, or when waiting for and answering replies another agent or the author writes in that file.
---

# Collaborative design review

A review earns trust by separating what was verified from what was concluded. The feedback file is
a thread that several agents append to, so every finding needs a stable number and every entry
names the exact spec version it read.

## 1. Review

Check each item and record the result, whether it confirms the spec or not.

| Check | How |
|---|---|
| Sources are current | For each doc the spec relies on, find the newest revision: other checkouts, devbox copies, memory notes, links in tickets. Two copies with the same hash prove nothing about currency. Diff old against newest and list decisions the spec missed. |
| Numbers | Recompute every figure from the evidence file. Check consistency between sections (a headline % vs the table it came from). |
| Code claims | Fetch the default branch. Check every `file:line` and every behavioral claim ("deletes in batches", "only checks X") in the code. |
| Headline statistics | If a distinct count equals the number of sampled units (batches, commits, tenants), it is a sampling artifact. Roll each headline up to its share of the whole system. |
| Internal consistency | An advantage credited to option A that the spec also gives option B. "Prefer A, benchmark B afterwards." |
| Change scope | Grep the governing design for everything that depends on what the proposal changes. Compare with the sections the spec says it amends. |
| Proposal vs existing code | Find existing cases the new rule cannot represent or would block. |
| Success criterion | Is there a numeric target, and a decision rule that could pick either option? |
| Unbounded or contended work | Single-transaction migrations or backfills, mass rewrites, hot records many writers update, IDs that are no longer deterministic. |
| Plan cost | Does the plan build an unapproved design more than once? |
| Hygiene | `/tmp` or personal paths cited as evidence, unverifiable self-assessments, transcript voice ("the user said"). |

## 2. Write the feedback file

Path: beside the spec, `<spec name without -design/-spec>-feedback.md`. Generate your ID with
`uuidgen | tr A-Z a-z` and the spec hash with `shasum -a 256 <spec>` (or `sha256sum`). Don't
commit unless asked.

```markdown
# Feedback: <spec title>

Review thread for `<spec file>` in this directory.

## How to use this file

- Each entry starts with `## <role> <agent-id> — <UTC timestamp>`.
- The reviewer's agent ID is `<your-id>`. Responders use their own ID (`uuidgen`).
- Append new entries at the end. Don't edit another agent's entry.
- Answer findings by number: `F4: fixed at spec L207` or `F5: disagree, because …`.

## Reviewer <your-id> — <UTC timestamp>

The review covers the spec at SHA-256 `<hash>`. L-numbers refer to that version.

### Summary
<verdict in 2–3 sentences>

### <severity group, most severe first>
**F1. <claim as a sentence> (L<n>).** <evidence, consequence, what would fix it>

### What checks out
<each verified claim, briefly>
```

Number F1, F2, … across all groups. Never renumber. New findings in later rounds continue the
sequence.

## 3. Wait for a reply

Right after your own write, run the helper in this skill's `scripts/` directory with the shell
tool's background mode. You get one notification when it exits.

```bash
bash <this skill's base directory>/scripts/wait-for-reply.sh <feedback-file> <your-id> [max-seconds]
```

- **Exit 0:** the file changed and then stayed unchanged for `SETTLE` seconds (default 45). It
  prints each new entry heading. If it prints none, someone edited existing text, so read the
  diff.
- **Exit 1:** timed out. `max-seconds` (default 14400) is a hard limit, so no wrapper is needed.
- **Exit 2:** the file was removed.

`POLL` (default 15 s) sets the check interval. `POLL`, `SETTLE` and `max-seconds` are whole
seconds.

## 4. Answer a reply

1. Read the entries after your last one. Hash the spec and compare with any hash the responder
   gives.
2. For each finding number they answer, check the spec at that hash. "Fixed" holds only if the
   text changed and the problem is gone; quote the line. Mark each one resolved, partly resolved
   or still open, with the reason.
3. Judge disagreements on the evidence. Concede when they are right.
4. Append one entry under your ID that names the new spec hash and ends with
   `Open: F… Resolved: F…`. Then re-arm the wait.

Stop when every finding is resolved or the author has explicitly accepted it as open, or when the
user says to stop. On a timeout, tell the user and offer to re-arm.

## Common mistakes

- No spec hash in the entry, so line references drift once the spec is edited.
- Findings grouped but not numbered, so replies can't cite them.
- Only problems reported, so the author can't tell checked claims from unchecked ones.
- Acting on the first change to the file, before the writer has finished its entry.
- Accepting "fixed" without reading the changed spec.
