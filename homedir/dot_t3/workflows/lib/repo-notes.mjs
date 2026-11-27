// Repo notes: facts about a repository that an agent had to discover and the next agent would need (its tooling, its
// rules, its traps). An agent returns them as a field of its result; they stay in T3's store, which outlives the
// run, and the next agents on the repository get the most recent sets.
// Files of lib/ are no workflow definitions (T3 loads only the top-level files of ~/.t3/workflows): a workflow
// imports what it uses. T3 reads an imported file once: a change here needs a restart of the server.
const S = Schema;

// The field of an agent's result; the workflow's prompt says what belongs in it.
export const RepoNotes = S.Array(S.String);

const NoteSet = S.Struct({ at: S.String, notes: RepoNotes });
export const RepoNoteSets = S.Array(NoteSet);
const prefix = (project) => `repo-notes/${project}/`;

// Both run inside a step. `source` names who gave the notes, unique per result (run id and step): a step that runs
// twice writes the same key.
export const saveRepoNotes = (project, source, notes) =>
  notes.length === 0
    ? Effect.void
    : T3.store.entry(`${prefix(project)}${source}`, NoteSet).set({ at: new Date().toISOString(), notes });

export const recentRepoNotes = (project, sets) =>
  Effect.map(T3.store.entries(prefix(project), NoteSet), (rows) =>
    rows
      .map((row) => row.value)
      .sort((a, b) => a.at.localeCompare(b.at))
      .slice(-sets),
  );
