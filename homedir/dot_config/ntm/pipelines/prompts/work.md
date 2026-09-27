Work on bead {BEAD_ID}: {TITLE}. It is already claimed for you. A scout has
explored the repository for it; its brief follows and is also a comment on the
bead. Do not re-explore: open the files the brief names to verify what you rely
on, and look further only where the brief proves wrong or incomplete.

Follow AGENTS.md: reserve the files you edit in Agent Mail (thread
{BEAD_ID}), run the checks the brief and AGENTS.md name, close the bead when
they pass, and release your reservations. Then free this pane for the next
bead: `ntm assign "$(tmux display -p -t "$TMUX_PANE" '#S')" --clear {BEAD_ID}`.
