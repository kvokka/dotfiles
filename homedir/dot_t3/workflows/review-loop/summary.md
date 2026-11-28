# The summary of a review loop

A review loop has ended: {{outcome}}. It took one task through rounds of a coder, the project's full CI and a
reviewer. Write the summary of the whole task for the owner, who reads it in the thread the run started from. Change
nothing: no file, no commit, no push.

The work is in `{{worktree}}`, on the branch `{{branch}}`, from `{{base}}` to `{{head}}`. When the reports leave
something unclear, read `git log {{base}}..{{head}}` and the diff of that range.

The summary covers the task, not the last round:

- what of the task is done, and where: the main changes, files or commits;
- what is not done or stays open: the mandatory items of the last review, the owner's unanswered questions, known
  limits;
- what the owner decided along the way;
- what you would do next.

Keep it short and plain. Reply with the summary alone: it is passed on as you write it.

## The task

{{task}}

## The owner's answers

{{answers}}

## The rounds, oldest first

{{history}}
