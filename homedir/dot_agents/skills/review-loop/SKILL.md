---
name: review-loop
description: Use when the user asks to run, start or send a task to the review loop - the T3 workflow that takes a task through rounds of a coder, the project's full CI and a reviewer until a review passes - or to give an ended run more rounds.
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
4. Start it. The key is unique per run; `thread` is this thread, which the run tells how it ended:

   ```sh
   t3 workflow start review-loop --key "<slug>-$(date +%Y%m%d-%H%M)" \
     --input "$(jq -n --arg project "<project root>" --rawfile task <task file> --arg thread "$T3CODE_THREAD_ID" \
       '{$project, $task, $thread}')"
   ```

5. Give the user the run id. The run and its questions are on the Workflows page of T3 ("Needs you");
   `t3 workflow show <run>` prints its steps. Do not wait for the run.

## More rounds

A run is never extended: a new run with `"continue": "<run id>"` goes on from an ended one, in its worktree and branch,
with its task, reports, reviews and the owner's answers, and numbers its rounds after them. A `task` given with it is
the owner's follow-up, added to the old task; leave it out for more rounds of the same task. A run older than this
(it has no `task` step in `t3 workflow show`) kept no task: give the whole task. The run refuses to start while the
run it continues has not ended. `project` stays the root checkout.

```sh
t3 workflow start review-loop --key "<slug>-$(date +%Y%m%d-%H%M)" \
  --input "$(jq -n --arg project "<project root>" --arg continue "<run id>" --arg thread "$T3CODE_THREAD_ID" \
    --argjson rounds 5 '{$project, $continue, $thread, $rounds}')"
```

## The input

| Field | Default | What |
|---|---|---|
| `project` | | the absolute path of the project's root |
| `task` | | the task, whole; with `continue`, the owner's follow-up to it |
| `continue` | | an ended run to go on from, in its worktree |
| `thread` | | the thread told how the run ended: `$T3CODE_THREAD_ID` |
| `ci` | the `ci` script of `t3.json` | the full CI, run in the worktree |
| `base` | `HEAD` of the project's checkout | the ref the run's branch starts from |
| `passScore` | `9` | the review score, of 10, that ends the loop |
| `rounds` | `10` | the rounds of this run, after which it stops |
| `coder`, `reviewer` | Claude Opus on `claude-coder`, GPT Sol on `codex-coder` | `{"instanceId", "model", "options"}` of a T3 provider instance |

## The end

Every end opens a thread on the run's worktree, on the project's default model, with the outcome, the task and the
last report and review: there the user reads the diff, talks the work over, opens a pull request or starts more
rounds. `thread` then gets a message with that thread's link: tell the user in a sentence or two. Nothing is pushed or
merged. A run stopped after its last round, or by the owner, keeps its branch; a cancelled run opens no thread and
sends no message.
