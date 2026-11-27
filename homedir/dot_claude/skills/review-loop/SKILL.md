---
name: review-loop
description: Use when the user asks to run, start or send a task to the review loop - the T3 workflow that takes a task through rounds of a coder, the project's full CI and a reviewer until a review passes.
---

# review-loop

The workflow `review-loop` (`~/.t3/workflows/review-loop.mjs`) takes one task through rounds of a coder, the
project's full CI and a reviewer, on a branch and a worktree of its own, until a review gives the pass score. It
asks the owner only what no agent can settle. You start the run; you do not do the task.

## Start a run

1. **The project** is the root checkout of the repository, as T3 has it registered: the first line of
   `git worktree list`, not a worktree you may be in.
2. **The CI.** The workflow runs the script named `ci` of `t3.json` at the project's root. When it has none, ask
   the user for the command of the full CI and offer to add it:
   `{"scripts": [{"name": "ci", "command": "<command>"}]}`. A command given for this run only goes in the input
   as `"ci"`.
3. **The task** is everything a coder with no access to this conversation needs: the goal, the decisions already
   made, what is out of scope, how "done" is checked. Write it to a file and show it to the user before you start,
   unless they gave the text themselves.
4. Start it. The key is unique per run:

   ```sh
   t3 workflow start review-loop --key "<slug>-$(date +%Y%m%d-%H%M)" \
     --input "$(jq -n --arg project "<project root>" --rawfile task <task file> '{$project, $task}')"
   ```

5. Give the user the run id. The run and its questions are on the Workflows page of T3 ("Needs you");
   `t3 workflow show <run>` prints its steps. Do not wait for the run.

## The input

| Field | Default | What |
|---|---|---|
| `project` | | the absolute path of the project's root |
| `task` | | the task, whole |
| `ci` | the `ci` script of `t3.json` | the full CI, run in the worktree |
| `base` | `HEAD` of the project's checkout | the ref the run's branch starts from |
| `passScore` | `9` | the review score, of 10, that ends the loop |
| `rounds` | `10` | the rounds after which the run stops |
| `coder`, `reviewer` | Claude Opus on `claude-coder`, GPT Sol on `codex-coder` | `{"instanceId", "model", "options"}` of a T3 provider instance |

## The end

A run that passes returns the branch (`review-loop/<id>`), the worktree, the commit and the score. Nothing is
pushed or merged: that is the user's next step. A run stopped after its last round, or by the owner, keeps its
branch.
