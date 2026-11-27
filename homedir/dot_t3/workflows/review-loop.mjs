// review-loop: one task through rounds of a coder, the project's full CI and a reviewer, until a review passes.
//
//   coder -> full CI -> reviewer -> gate, and again; each round is a new session of each agent.
//
// - The coder runs only the tests of what it changes; the full CI is a step of the workflow, between the sessions.
// - Red CI goes straight back to a coder, CI_RETURNS times in a row at most; then a reviewer looks at it.
// - A question no agent can settle goes to the owner as a T3 question; the answer starts a new coder round.
// - A session gets the task, the last reports and reviews, every answer of the owner and the last notes on the
//   repository (lib/repo-notes.mjs).
// - The work stays on a branch of its own, in a worktree of its own. Nothing is pushed.
//
// The prompts are review-loop/coder.md and review-loop/reviewer.md, read at the start of each run. The agents run
// with the project's runtime mode: one that waits for approvals makes a session wait for the owner.
//
//   t3 workflow start review-loop --key <unique> --input '{"project":"/abs/repo","task":"..."}'
import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import { RepoNotes, RepoNoteSets, recentRepoNotes, saveRepoNotes } from "./lib/repo-notes.mjs";

const { workflow, step, agent, ask, stop, title } = T3;
const S = Schema;

// A provider instance of T3's settings: its plugins, environment and launch arguments are the agent's.
const Model = S.Struct({
  instanceId: S.String,
  model: S.String,
  options: S.optional(S.Array(S.Struct({ id: S.String, value: S.Union([S.String, S.Boolean]) }))),
});
const CODER = { instanceId: "claude-coder", model: "claude-opus-5-5", options: [{ id: "effort", value: "high" }] };
const REVIEWER = { instanceId: "codex-coder", model: "gpt-6.2-sol", options: [{ id: "reasoningEffort", value: "high" }] };

const CODER_TIMEOUT = "2 hours";
const REVIEWER_TIMEOUT = "1 hour";
const CI_TIMEOUT_MS = 60 * 60_000;
// How long a session may stay silent between turns (it waits for its background work) before it is asked for its result.
const QUIET = "30 minutes";
const HISTORY = 4; // the reports and reviews a session gets
const NOTE_SETS = 4; // the sets of repo notes a session gets
const CI_RETURNS = 3; // red CI runs in a row that go back to a coder without a review

const Payload = S.Struct({
  project: S.String, // the absolute path of a repository registered as a T3 project
  task: S.String,
  ci: S.optional(S.String), // the full CI, `sh -c` in the worktree; default: the script named `ci` of the project's t3.json
  base: S.optional(S.String), // the ref the run's branch starts from; default: HEAD of the project's checkout
  passScore: S.optional(S.Number), // default 9
  rounds: S.optional(S.Number), // default 10
  coder: S.optional(Model),
  reviewer: S.optional(Model),
});

const CoderResult = S.Struct({
  status: S.Literals(["done", "partial", "blocked"]),
  report: S.String,
  question: S.optional(S.String),
  notes: RepoNotes,
});
const ReviewResult = S.Struct({
  score: S.Number,
  verdict: S.Literals(["complete", "continue"]),
  review: S.String,
  question: S.optional(S.String),
  notes: RepoNotes,
});
const Tree = S.Struct({ head: S.String, dirty: S.Number });
const Ci = S.Struct({ code: S.Number, tail: S.String, head: S.String, dirty: S.Number });
const Setup = S.Struct({ base: S.String, branch: S.String, worktree: S.String });
const Prompts = S.Struct({ coder: S.String, reviewer: S.String });

// A command in a folder: its exit code and output. It never fails; a command that could not run or ran out of time
// exits 124.
const exec = (file, args, cwd, timeoutMs = 60_000) =>
  Effect.promise(
    () =>
      new Promise((resolve) =>
        execFile(file, args, { cwd, timeout: timeoutMs, maxBuffer: 64 << 20 }, (error, stdout, stderr) =>
          resolve({
            code: error ? (typeof error.code === "number" ? error.code : 124) : 0,
            out: `${stdout}${stderr}` || (error?.message ?? ""),
          }),
        ),
      ),
  );
const git = (cwd, ...args) =>
  Effect.flatMap(exec("git", args, cwd), (r) =>
    r.code === 0 ? Effect.succeed(r.out.trim()) : Effect.fail(new Error(`git ${args.join(" ")}: ${r.out.trim()}`)),
  );
const tree = (cwd) =>
  Effect.gen(function* () {
    const head = yield* git(cwd, "rev-parse", "HEAD");
    const status = yield* git(cwd, "status", "--porcelain");
    return { head, dirty: status ? status.split("\n").length : 0 };
  });

// The project's own CI: the script named `ci` of its t3.json, which T3 also shows among the project's actions.
// shortcut: t3.json is read as strict JSON, T3 itself accepts comments in it; parse it leniently once a project has them.
const ciOfProject = (project) =>
  Effect.tryPromise({
    try: async () => {
      const scripts = JSON.parse(await readFile(join(project, "t3.json"), "utf8")).scripts ?? [];
      const ci = scripts.find((script) => script.name === "ci");
      if (!ci) throw new Error("its t3.json has no script named ci");
      return ci.command;
    },
    catch: (cause) =>
      new Error(
        `No CI command for ${project} (${cause.message}). Add {"scripts":[{"name":"ci","command":"<the full CI>"}]} ` +
          `to t3.json at the root of the repository, or pass "ci" in the input.`,
      ),
  });

// `{{name}}` of a prompt becomes its value. A value is not read again, so a task may hold braces of its own.
const fill = (prompt, values) =>
  prompt.replace(/\{\{(\w+)\}\}/g, (_, name) => {
    if (!(name in values)) throw new Error(`the prompt names {{${name}}}, which review-loop does not give`);
    return String(values[name]);
  });
const bullets = (lines) => lines.map((line) => `- ${line}`).join("\n");

export default workflow(
  "review-loop",
  { version: 3, payload: Payload, asks: { owner: "Question of a review loop" } },
  (input, run) =>
    Effect.gen(function* () {
      const passScore = input.passScore ?? 9;
      const rounds = input.rounds ?? 10;
      const headline = input.task.trim().split("\n")[0].slice(0, 70);

      const ciCommand = input.ci
        ? { outcome: "done", value: input.ci }
        : yield* step.try("ci-command", { returns: S.String }, ciOfProject(input.project));
      if (ciCommand.outcome === "failed") return yield* stop(ciCommand.reason);
      const ci = ciCommand.value;

      const setup = yield* step(
        "setup",
        { returns: Setup },
        Effect.gen(function* () {
          const id = run.id.slice(0, 8);
          const branch = `review-loop/${id}`;
          const worktree = join(homedir(), ".t3", "worktrees", basename(input.project), `review-loop-${id}`);
          const base = yield* git(input.project, "rev-parse", "--verify", `${input.base ?? "HEAD"}^{commit}`);
          // The step may run twice: a worktree that is there is the one it made.
          const made = yield* exec("git", ["-C", worktree, "rev-parse", "--git-dir"], input.project);
          if (made.code !== 0) yield* git(input.project, "worktree", "add", "-q", "-B", branch, worktree, base);
          return { base, branch, worktree };
        }),
      );
      const prompts = yield* step(
        "prompts",
        { returns: Prompts },
        Effect.promise(async () => ({
          coder: await readFile(new URL("./review-loop/coder.md", import.meta.url), "utf8"),
          reviewer: await readFile(new URL("./review-loop/reviewer.md", import.meta.url), "utf8"),
        })),
      );
      let notes = yield* step("notes", { returns: RepoNoteSets }, recentRepoNotes(input.project, NOTE_SETS));
      // An agent's notes join the store; the step gives back the sets the next session gets.
      const keepNotes = (name, given) =>
        step(
          `notes-${name}`,
          { returns: RepoNoteSets },
          Effect.flatMap(saveRepoNotes(input.project, `${run.id}/${name}`, given), () =>
            recentRepoNotes(input.project, NOTE_SETS),
          ),
        );

      const workspace = { type: "existing_worktree", worktreePath: setup.worktree, branch: setup.branch };
      const session = (start, name, role, model, timeout, returns, brief) =>
        start(name, {
          project: input.project,
          workspace,
          model,
          title: `${headline} · ${role}`,
          timeout,
          quiet: QUIET,
          returns,
          brief,
        });
      const askOwner = (name, who, question) =>
        ask(name, {
          title: `Question of ${who} · ${headline}`, // the question itself is the data, shown whole
          kind: "owner",
          data: { question },
          choices: [
            { value: "answer", description: "Your answer is the reason; a new coder round follows it.", requireReason: true },
            { value: "stop", description: "End the run. The branch keeps the work." },
          ],
        });

      // What the sessions are told. All of it is rebuilt on a replay from the stored results of the steps.
      const history = []; // the reports of the coders and the reviews, oldest first
      const answers = []; // every answer of the owner
      let returned = "(nothing: this is the first round)";
      let redCi = 0; // red CI runs in a row
      let coderFailed = false;
      let lastScore = "none";
      const ciText = (r) =>
        `\`${ci}\` exited ${r.code} at ${r.head}, with ${r.dirty} uncommitted paths. The end of its output:\n${r.tail}`;
      const told = (round) => ({
        task: input.task,
        ci,
        passScore,
        round,
        rounds,
        quiet: QUIET,
        ...setup,
        history: history.slice(-HISTORY).join("\n\n") || "(none yet)",
        answers: answers.join("\n\n") || "(none)",
        notes: bullets(notes.flatMap((set) => set.notes)) || "(none)",
      });
      // An answer of the owner starts a new coder round; `false` when the owner ends the run.
      const answered = (name, round, who, question) =>
        Effect.gen(function* () {
          const answer = yield* askOwner(name, who, question);
          if (Option.isSome(answer) && answer.value.choice === "stop") return false;
          const text = Option.isSome(answer)
            ? answer.value.reason
            : "(the owner left it unanswered: decide it yourself and say what you chose)";
          answers.push(`### Round ${round}, ${who} asked: ${question}\n${text}`);
          returned = `The owner answered a question of ${who} of round ${round}: it is the last of the owner's answers.`;
          redCi = 0;
          return true;
        });

      for (let round = 1; round <= rounds; round++) {
        yield* title(`r${round}/${rounds} ${headline}`);

        // A coder session that dies does not end the run: its work may be in the tree, so the round goes on. The
        // session after a dead one pauses the run when it dies too.
        const coded = yield* session(
          coderFailed ? agent : agent.try,
          `coder-${round}`,
          `coder r${round}`,
          input.coder ?? CODER,
          CODER_TIMEOUT,
          CoderResult,
          fill(prompts.coder, { ...told(round), returned }),
        );
        coderFailed = coded.outcome === "failed";
        if (coderFailed) {
          history.push(`### Round ${round}, coder: the session ended without a report (${coded.reason})`);
        } else {
          const c = coded.value;
          history.push(`### Round ${round}, coder: ${c.status}\n${c.report}`);
          notes = yield* keepNotes(`coder-${round}`, c.notes);
          if (c.question) {
            if (yield* answered(`owner-coder-${round}`, round, "the coder", c.question)) continue;
            return yield* stop(`the owner ended the run; the work is on ${setup.branch} in ${setup.worktree}`);
          }
        }

        const ciRun = yield* step(
          `ci-${round}`,
          { returns: Ci },
          Effect.gen(function* () {
            const r = yield* exec("sh", ["-c", ci], setup.worktree, CI_TIMEOUT_MS);
            return { code: r.code, tail: r.out.slice(r.code === 0 ? -1500 : -6000), ...(yield* tree(setup.worktree)) };
          }),
        );
        if (ciRun.code !== 0 && redCi < CI_RETURNS) {
          redCi++;
          returned = `The full CI is red: return ${redCi} of ${CI_RETURNS} before a reviewer looks at it. ${ciText(ciRun)}`;
          continue;
        }
        redCi = 0;

        const brief = fill(prompts.reviewer, { ...told(round), ciResult: ciText(ciRun) });
        const review = (name, start) =>
          session(start, name, `reviewer r${round}`, input.reviewer ?? REVIEWER, REVIEWER_TIMEOUT, ReviewResult, brief);
        // A review that could not be written is written once more by a new session; a second failure pauses the run.
        let reviewed = yield* review(`reviewer-${round}`, agent.try);
        if (reviewed.outcome === "failed") reviewed = yield* review(`reviewer-${round}-again`, agent);
        const r = reviewed.value;
        lastScore = `${r.score}/10`;
        history.push(`### Round ${round}, review: ${r.score}/10, ${r.verdict}\n${r.review}`);
        notes = yield* keepNotes(`reviewer-${round}`, r.notes);
        if (r.question) {
          if (yield* answered(`owner-reviewer-${round}`, round, "the reviewer", r.question)) continue;
          return yield* stop(`the owner ended the run; the work is on ${setup.branch} in ${setup.worktree}`);
        }

        const now = yield* step(`tree-${round}`, { returns: Tree }, tree(setup.worktree));
        const short = [
          r.score < passScore && `the score ${r.score}/10 is under ${passScore}`,
          r.verdict !== "complete" && `the verdict is \`${r.verdict}\``,
          ciRun.code !== 0 && `the full CI is red`,
          now.head !== ciRun.head && `HEAD moved after the CI ran (${ciRun.head} to ${now.head})`,
          now.dirty > 0 && `${now.dirty} paths are not committed`,
        ].filter(Boolean);
        if (short.length === 0)
          return { branch: setup.branch, worktree: setup.worktree, head: now.head, score: r.score, rounds: round };
        returned =
          `The review of round ${round} sent the work back: ${short.join("; ")}. Its mandatory items come first.` +
          (ciRun.code !== 0 ? `\n${ciText(ciRun)}` : "");
      }
      return yield* stop(
        `not passed in ${rounds} rounds, the last review gave ${lastScore}; the work is on ${setup.branch} in ${setup.worktree}`,
      );
    }),
);
