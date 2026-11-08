---
name: grilling
description: Interview the user until every design decision is settled. Use when they ask to be grilled or explicitly request an exhaustive decision interview.
---

Start with the plan, decision or idea the user wants to settle. This is an
exhaustive interview; a request for an ordinary critique does not select it.

Interview the user until you reach a shared understanding, mapped as a **design
tree**: every decision branches into the decisions hanging off it.

Work the tree in **rounds**. The **frontier** is every decision whose
prerequisites are settled — the questions you ask _now_ without guessing at
answers you have not heard. Ask a manageable group from the frontier, then wait
for the user's answers. Format each question:

```text
❓ **1** - **<question title>**: <question body, several paragraphs where it
needs them, multiple choices included>

➡️ <your recommended answer>
```

Each round of answers reshapes the tree: settled decisions push the frontier
outward and unblock the questions that depended on them. Recompute the frontier
and ask the next round. A question whose answer depends on another still open
in this round belongs to a _later_ round.

Facts are yours to find, never the user's. Where a frontier question needs a
fact from the environment — the filesystem, a tool, a running service —
inspect it directly, or delegate an independent investigation when that saves
context and delegation is available. A running exploration
is an unsettled prerequisite: only the questions downstream of it wait for that
investigation, so ask the independent questions now. The _decisions_ are the user's:
put each to them and wait.

Done when the frontier is empty: every branch of the design tree visited,
nothing left silently assumed. Do not act until the user confirms the shared
understanding.
