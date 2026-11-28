This thread holds the result of the review-loop run `{{runId}}`. The run has ended: {{outcome}}.

Its work is on the branch `{{branch}}`, in this thread's worktree `{{worktree}}`, which started from `{{base}}`; its
HEAD is `{{head}}`. Nothing is pushed or merged.

## The task

{{task}}

## The last report and review

{{last}}

## Your part

Reply with a short summary for the owner: what was done, what the last review still asks for, and what you would do
next. Change nothing until the owner asks.

The owner may ask you to push the branch and open a pull request, or to talk the work over. For more rounds of the
review loop, use the skill `review-loop` to start a run with `"continue": "{{runId}}"`, this thread as `"thread"`,
and the owner's new instructions, if any, as `"task"`: it goes on in this worktree with this run's history.
