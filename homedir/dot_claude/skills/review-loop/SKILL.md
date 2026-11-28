---
name: review-loop
description: Use when the user asks to run, start or send a task to the review loop - the T3 workflow that takes a task through rounds of a coder, the project's full CI and a reviewer until a review passes - or to give an ended run more rounds.
---

# review-loop

The workflow `review-loop` (`~/.t3/workflows/review-loop.mjs`) takes one task through rounds of a coder, the
project's full CI and a reviewer until a review gives the pass score. It works where this thread works, in its worktree
or else in the project's checkout, on the branch checked out there, and reports to this thread. It asks the owner only
what no agent can settle. You start the run; you do not do the task.

## Where it runs

The run works in the place of the thread it is given and reports to that thread. The user's words choose the thread
and the place; what they leave out takes the default:

| The user asks for | You |
|---|---|
| nothing about where | start the run from this thread, in its place |
| a new worktree for this thread | `t3_worktree_handoff` (only when this thread has none), last in your turn, with a `continuationPrompt` that starts the run |
| a new thread | `t3_thread_launch` with a new worktree: two threads in one tree get in each other's way |
| a new thread in this place | `t3_thread_launch` with `existing_worktree` (this thread's `worktreePath`) or `root`; this thread then leaves the tree alone |

A new worktree whose base the user does not name starts from the branch checked out here: `baseRef` that branch,
`startFromOrigin: false`, a new `branch` named after the task. Its work is meant to merge into the repository's default
branch (`git symbolic-ref --short refs/remotes/origin/HEAD`): say so in the task. Uncommitted edits stay behind: commit
what the task needs first.

A new thread gets in its `message` the order to start the run at once, then the whole task: `Use the skill review-loop
and start a run in this thread with the task below, as it stands; ask nothing.` Its agent passes its own
`$T3CODE_THREAD_ID`, so the run reports there. Give the user the new thread's `link`.

## Start a run

1. **The project** is the root checkout of the repository, as T3 has it registered: the first line of
   `git worktree list`, not a worktree you may be in.
2. **The place.** The run commits on the branch checked out in this thread's worktree, or in the project's checkout
   when this thread has none: `t3_worktree_status` shows which. Say so to the user before you start. The tree must be
   clean: commit or stash first, with the user's consent. Change nothing in that tree while the run works.
3. **The CI.** The workflow runs the script named `ci` of `t3.json` at the project's root. When it has none, ask
   the user for the command of the full CI and offer to add it:
   `{"scripts": [{"name": "ci", "command": "<command>"}]}`. A command given for this run only goes in the input
   as `"ci"`.
4. **The task** is everything a coder with no access to this conversation needs: the goal, the decisions already
   made, what is out of scope, how "done" is checked. Write it to a file. Show it to the user and wait for their
   word only when the conversation has not settled it: not when they gave the text, approved it, or said to start.
5. Start it. The key is unique per run:

   ```sh
   t3 workflow start review-loop --key "<slug>-$(date +%Y%m%d-%H%M)" \
     --input "$(jq -n --arg project "<project root>" --arg thread "$T3CODE_THREAD_ID" --rawfile task <task file> \
       '{$project, $thread, $task}')"
   ```

6. Give the user the run id. The run and its questions are on the Workflows page of T3 ("Needs you");
   `t3 workflow show <run>` prints its steps. Do not wait for the run: it writes to this thread when it ends.

## More rounds

A run is never extended: a new run with `"continue": "<run id>"` goes on from an ended one, with its task, reports,
reviews, the owner's answers and base, and numbers its rounds after them. A `task` given with it is the owner's
follow-up, added to the old task; leave it out for more rounds of the same task. A run older than this (it has no
`task` step in `t3 workflow show`) kept no task: give the whole task. The run refuses to start while the run it
continues has not ended. `t3 workflow list --subject "$T3CODE_THREAD_ID"` lists the runs this thread started.

```sh
t3 workflow start review-loop --key "<slug>-$(date +%Y%m%d-%H%M)" \
  --input "$(jq -n --arg project "<project root>" --arg thread "$T3CODE_THREAD_ID" --arg continue "<run id>" \
    --argjson rounds 5 '{$project, $thread, $continue, $rounds}')"
```

## The input

| Field | Default | What |
|---|---|---|
| `project` | | the absolute path of the project's root |
| `thread` | | the thread the run works for: `$T3CODE_THREAD_ID`; without it, the project's checkout and no report |
| `task` | | the task, whole; with `continue`, the owner's follow-up to it |
| `continue` | | an ended run to go on from |
| `ci` | the `ci` script of `t3.json` | the full CI, run where the run works |
| `base` | `HEAD` at the start, or the base of `continue` | the commit the work is reviewed from |
| `passScore` | `9` | the review score, of 10, that ends the loop |
| `rounds` | `10` | the rounds of this run, after which it stops |
| `coder`, `reviewer`, `summarizer` | Claude Opus on `claude-coder`, GPT Sol and GPT Terra on `codex-coder` | `{"instanceId", "model", "options"}` of a T3 provider instance |

## The end

At every end a summarizer writes one summary of the whole task: what is done, what stays open, what the owner
decided, what comes next. The run sends it to this thread: give it to the user. Nothing is pushed or merged. A
cancelled run sends nothing.
