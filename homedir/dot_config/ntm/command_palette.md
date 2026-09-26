# ntm command palette: `ntm palette` or the `ntm bind` popup key (F6).
#
# Format (ntm LoadPaletteFromMarkdown): `## Category`, then `### key | Label`
# and the prompt text up to the next heading. A line starting with `#` is a
# comment only before the first command; after that it is prompt text, so
# keep every comment in this header. This file replaces ntm's built-in
# entries; a repository adds its own through `[palette] file` in
# `.ntm/config.toml`.
#
# In the palette: type to filter, Enter to select, `e` to edit the prompt
# before sending, F1 for help. Targets: 1 all, 2 Claude (cc), 3 Codex (cod),
# 5 Antigravity (agy), 6 pick panes.
#
# The prompts are the swarm prompts of the Agent Flywheel author
# (agent-swarm-workflow skill, THE_FLYWHEEL_APPROACH §24), adapted to
# br/bv, Agent Mail and the AGENTS.md of `fw:init`. "ultrathink" is the
# keyword Claude Code turns into deeper reasoning for that turn; Codex and
# Antigravity read it as plain text.

## Swarm Loop

### default_new_agent | Marching Orders
First read ALL of the AGENTS.md file and README.md file super carefully and understand ALL of both! Then use your code investigation agent mode to fully understand the code, and technical architecture and purpose of the project. Then register with MCP Agent Mail and introduce yourself to the other agents. Be sure to check your agent mail and to promptly respond if needed to any messages; then proceed meticulously with your next assigned beads, working on the tasks systematically and meticulously and tracking your progress via beads and agent mail messages. Don't get stuck in "communication purgatory" where nothing is getting done; be proactive about starting tasks that need to be done, but inform your fellow agents via messages when you do so and mark beads appropriately. When you're not sure what to do next, use the bv tool mentioned in AGENTS.md to prioritize the best beads to work on next; pick the next one that you can usefully work on and get started. Make sure to acknowledge all communication requests from other agents and that you are aware of all active agents and their names. Use ultrathink.

### next_bead | Next Bead
Reread AGENTS.md so it's still fresh in your mind. Use ultrathink. Use bv with the robot flags (see AGENTS.md for info on this) to find the most impactful bead(s) to work on next and then start on it. Remember to mark the beads appropriately and communicate with your fellow agents. Pick the next bead you can actually do usefully now and start coding on it immediately; communicate what you're working on to your fellow agents and mark beads appropriately as you work. And respond to any agent mail messages you've received.

### reread_agents_md | Reread AGENTS.md
Reread AGENTS.md so it's still fresh in your mind. Use ultrathink.

### check_and_respond_to_mail | Check Agent Mail
Be sure to check your agent mail and to promptly respond if needed to any messages, and also acknowledge any contact requests; make sure you know the names of all active agents using the MCP Agent Mail system.

### analyze_beads_and_allocate | Allocate Beads via bv
Re-read AGENTS.md first. Then, can you try using bv to get some insights on what each agent should most usefully work on? Then share those insights with the other agents via agent mail and strongly suggest in your messages the optimal work for each one and explain how/why you came up with that using bv. Use ultrathink.

### reality_check | Reality Check
Where are we on this project? Do we actually have the thing we are trying to build? If not, what is blocking us? If we intelligently implement all open and in-progress beads, would we close that gap completely? Why or why not?

## Review

### fresh_review | Fresh-Eyes Self-Review
Great, now I want you to carefully read over all of the new code you just wrote and other existing code you just modified with "fresh eyes" looking super carefully for any obvious bugs, errors, problems, issues, confusion, etc. Carefully fix anything you uncover. Use ultrathink.

### check_other_agents_work | Cross-Agent Review
Ok can you now turn your attention to reviewing the code written by your fellow agents and checking for any issues, bugs, errors, problems, inefficiencies, security problems, reliability issues, etc. and carefully diagnose their underlying root causes using first-principle analysis and then fix or revise them if necessary? Don't restrict yourself to the latest commits, cast a wider net and go super deep! Use ultrathink.

### randomly_inspect_code | Random Code Exploration
I want you to sort of randomly explore the code files in this project, choosing code files to deeply investigate and understand and trace their functionality and execution flows through the related code files which they import or which they are imported by. Once you understand the purpose of the code in the larger context of the workflows, I want you to do a super careful, methodical, and critical check with "fresh eyes" to find any obvious bugs, problems, errors, issues, silly mistakes, etc. and then systematically and meticulously and intelligently correct them. Be sure to comply with ALL rules in AGENTS.md and ensure that any code you write or revise conforms to the best practice guides referenced in the AGENTS.md file. Use ultrathink.

### apply_ubs | Full UBS Sweep
Run `ubs .` on the whole repository (the pre-commit hook scans only the staged files) and investigate and fix literally every single UBS issue once you determine (after reasoned consideration and close inspection) that it's legit. `ubs explain <rule-id>` explains a rule; mark a confirmed false positive with a trailing `ubs:ignore -- <reason>` on the flagged line instead of changing the code.

## Git

### git_commit | Organized Commit and Push
Now, based on your knowledge of the project, commit all changed files now in a series of logically connected groupings with super detailed commit messages for each and then push. Take your time to do it right. Don't edit the code at all. Don't commit obviously ephemeral files. Run `br sync --flush-only` first and commit `.beads/` with the code, with the bead id in each commit message as AGENTS.md describes. If a pre-commit hook fails, report what it found; never bypass it with `--no-verify`. Use ultrathink.

## Planning

### turn_plan_into_beads | Plan to Beads
OK so please take ALL of that and elaborate on it and use it to create a comprehensive and granular set of beads for all this with tasks, subtasks, and dependency structure overlaid, with detailed comments so that the whole thing is totally self-contained and self-documenting (including relevant background, reasoning/justification, considerations, etc.-- anything we'd want our "future self" to know about the goals and intentions and thought process and how it serves the over-arching goals of the project.). The beads should be so detailed that we never need to consult back to the original markdown plan document. Remember to ONLY use the `br` tool to create and modify the beads and add the dependencies.

### improve_beads | Polish Beads
Check over each bead super carefully-- are you sure it makes sense? Is it optimal? Could we change anything to make the system work better for users? If so, revise the beads. It's a lot easier and faster to operate in "plan space" before we start implementing these things! DO NOT OVERSIMPLIFY THINGS! DO NOT LOSE ANY FEATURES OR FUNCTIONALITY! Also make sure that as part of the beads we include comprehensive unit tests and e2e test scripts with great, detailed logging so we can be sure that everything is working perfectly after implementation. Make sure to ONLY use the `br` cli tool for all changes, and you can and should also use the `bv` tool to help diagnose potential problems with the beads.

### create_tests | Test Coverage Beads
Do we have full unit test coverage without using mocks/fake stuff? What about complete e2e integration test scripts with great, detailed logging? If not, then create a comprehensive and granular set of beads for all this with tasks, subtasks, and dependency structure overlaid with detailed comments.

## Ad Hoc

### do_all_of_it | Do All Of It
OK, please do ALL of that now. Track work via br beads (no markdown TODO lists): create/claim/update/close beads as you go so nothing gets lost, and keep communicating via Agent Mail when you start/finish work.

### fix_bug | Fix Bug (press e, add details)
I want you to very carefully diagnose and then fix the root underlying cause of the bugs/errors shown here, but fix them FOR REAL, not a superficial "bandaid" fix! Here are the details:

### revise_readme | Revise README
OK, we have made tons of recent changes that aren't yet reflected in the README file. First, reread AGENTS.md so it's still fresh in your mind. Now, we need to revise the README for these changes (don't write about them as "changes" however, make it read like it was always like that, since we don't have any users yet!). Also, what else can we put in there to make the README longer and more detailed about what we built, why it's useful, how it works, the algorithms/design principles used, etc? This should be incremental NEW content, not replacement for what is there already.
