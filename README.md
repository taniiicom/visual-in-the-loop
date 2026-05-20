# Visual-in-the-Loop Skills

> Hand humans a picture — not a wall of text — when an agent asks for a decision.

A Claude Code [Agent Skill][skills]. Plan agents (plan mode, Codex, spec-kit)
produce plans that are slow to review as text. This skill makes the agent
generate a single **1-page diagram** of the plan with [Nano Banana Pro /
Gemini 3 Pro Image][nano] — and show it to you — right before it calls
`ExitPlanMode`, `AskUserQuestion`, or any other "please review and decide"
moment.

[skills]: https://code.claude.com/docs/en/skills
[nano]: https://deepmind.google/models/gemini-image/pro/

## Installation

### With the [`skills` CLI][skills-cli] (recommended)

```bash
npx skills add taniiicom/visual-in-the-loop
```

It installs into `~/.claude/skills/visual-in-the-loop/`; Claude Code picks it
up on its next session.

### Manual (clone + symlink)

```bash
git clone https://github.com/taniiicom/visual-in-the-loop.git
ln -s "$(pwd)/visual-in-the-loop/skills/visual-in-the-loop" \
      ~/.claude/skills/visual-in-the-loop
```

[skills-cli]: https://github.com/vercel-labs/skills

## Setup

**1. A Gemini API key** _(required)_. Get one from [Google AI Studio][aistudio]
and export it — either name works:

```bash
export GEMINI_API_KEY=...   # or GOOGLE_API_KEY
```

Add it to `~/.zshrc` / `~/.bashrc`, or to `~/.claude/settings.json` under the
`env` key, so it persists. Other providers (Vertex AI, OpenAI, Azure) are
supported too — see [Configuration](#configuration).

**2. Node.js 18+** _(required)_. The skill uses the built-in `fetch` — no
`npm install`, no `package.json`.

**3. A display tool** _(optional — the skill falls back automatically)_:
`chafa` + `tmux` for an in-terminal preview, the `code` CLI for a VS Code
tab, or just the OS image viewer (`open` / `xdg-open`, always available).

[aistudio]: https://aistudio.google.com/apikey

## How it works

1. Right before asking you to review a plan, the agent pipes the **plan text,
   verbatim** into the skill.
2. The skill calls Gemini once and saves a single PNG — the whole plan
   rendered as one diagram.
3. It renders the image into your view:
   - **tmux** (with `chafa`) → a side pane, real graphics, sized to fit
   - **VS Code / Cursor / Windsurf** → a markdown tab with the image
   - **macOS** → `open` (Preview) · **Linux** → `xdg-open`
4. Only **after** the image is on screen does the agent show the question —
   you decide while looking at the picture.

If anything fails (no key, network down, no display path) the skill exits
quietly and the agent asks as usual. It never blocks the conversation.

## Try it

Smoke-test the install with the bundled sample plan — the image you get back
explains what the skill does, so it doubles as a tutorial:

```bash
cat ~/.claude/skills/visual-in-the-loop/references/sample-plan.md \
  | bash ~/.claude/skills/visual-in-the-loop/scripts/run.sh
```

You should see `[visual-in-the-loop] rendered: …png` on stdout and an image
appear. Then start a Claude Code session and ask for a non-trivial plan —
when the agent reaches `ExitPlanMode` / `AskUserQuestion`, the picture appears
before the question.

## Configuration

All settings are environment variables. Put them in your shell, or in
`~/.claude/settings.json` under the `env` key so they apply to every session:

```jsonc
// ~/.claude/settings.json
{
  "env": {
    "GEMINI_API_KEY": "AIza...",
    "VITL_PROVIDER": "gemini",
    "VITL_ASPECT_RATIO": "2:3",
    "VITL_DISPLAY": "auto",
  },
}
```

| Variable            | Values                                               | Default          | Purpose                                                                                                                |
| ------------------- | ---------------------------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `VITL_ENABLED`      | `1` / `0` (and `true`/`false`/`yes`/`no`/`on`/`off`) | on               | Master switch. Only `0`/`false`/`no`/`off` disable it.                                                                 |
| `VITL_PROVIDER`     | `gemini` / `vertexai` / `openai` / `azure`           | `gemini`         | Which API to call.                                                                                                     |
| `VITL_MODEL`        | provider-specific id                                 | provider default | E.g. `gemini-2.5-flash-image` for free-tier Gemini.                                                                    |
| `VITL_ASPECT_RATIO` | `2:3`, `3:4`, `9:16`, `1:1`, `16:9`, …               | `2:3` (portrait) | Shape of the image. Gemini / Vertex use it directly; OpenAI / Azure map it to the nearest size.                        |
| `VITL_LANG`         | a language name (`Japanese`, `English`, …)           | unset            | Language for the diagram's text. The agent normally sets this per call via `--lang`; the env var is a static fallback. |
| `VITL_DISPLAY`      | `auto` / `tmux` / `vscode` / `open` / `none`         | `auto`           | Force a display path, or `none` to suppress. Unusable choices fall back to `auto`.                                     |
| `VITL_TRIGGER`      | comma-separated (`plan,clarify,decision`) or `all`   | `all`            | Which decision moments fire generation.                                                                                |

### Per-provider keys

| `VITL_PROVIDER` | Required env vars                                                                                                  | Default `VITL_MODEL`         |
| --------------- | ------------------------------------------------------------------------------------------------------------------ | ---------------------------- |
| `gemini`        | `GEMINI_API_KEY` _or_ `GOOGLE_API_KEY`                                                                             | `gemini-3-pro-image-preview` |
| `vertexai`      | `VITL_VERTEX_PROJECT` + `VITL_VERTEX_LOCATION` (auth via `gcloud auth application-default login`)                  | `gemini-3-pro-image-preview` |
| `openai`        | `OPENAI_API_KEY`                                                                                                   | `gpt-image-1`                |
| `azure`         | `AZURE_OPENAI_API_KEY` + `AZURE_OPENAI_ENDPOINT` + `AZURE_OPENAI_DEPLOYMENT` (optional `AZURE_OPENAI_API_VERSION`) | set by the deployment        |

For Vertex AI the skill shells out to `gcloud auth application-default
print-access-token` (no extra dependency); install the [gcloud CLI][gcloud]
and authenticate once.

[gcloud]: https://cloud.google.com/sdk/docs/install

### Fail-safes

Nothing you put in config should silently break the conversation:

- A `--trigger` the agent forgot still generates (never miss a visual).
- A `VITL_DISPLAY` that isn't usable here warns and falls back to `auto`.
- A `VITL_ENABLED` value that isn't a recognized false value stays enabled.

## Tuning

There is exactly **one knob**:
`skills/visual-in-the-loop/references/prompt-template.md`. It is one line. If
diagrams come out off-target, edit that file — don't add heuristics to
`generate.mjs`. Trust the model.

## Troubleshooting

| Symptom                                        | Fix                                                                                            |
| ---------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| The agent doesn't call the skill before asking | Make the `description:` in `SKILL.md` more aggressive, restart the session.                    |
| `no display path available`                    | No `$TMUX`+chafa, VS Code, `open`, or `xdg-open` here. Install one (expected on remote `ssh`). |
| `API <status>: …` in stderr                    | Usually a missing / invalid API key. The agent's question proceeds without an image.           |
| Image generated but not shown in tmux          | Install `chafa` (`brew install chafa`). Without it the skill falls through to `open`.          |

## Design notes

A few opinionated choices that may not be obvious from the code:

- **No Mermaid / D2 fallback.** This skill exists _because_ structure-diagram
  layers are not the visualization plans need. Don't add a split.
- **Synchronous, not background.** Generation takes ~5–15 s. Showing the
  question before the image is ready summons the user to a half-rendered
  review — exactly the friction this skill prevents.
- **The agent doesn't see the image, the human does.** The agent gets only
  the PNG path back; the picture is a side-channel to human eyes.
- **Pipe the plan verbatim.** Don't paraphrase the plan into the skill — the
  diagram is only as good as the text the model receives.

## Roadmap

- `references/hook-example.md` — once Claude Code's `PreToolUse` /
  `PermissionRequest` matchers stabilize for `AskUserQuestion` and
  `ExitPlanMode`, add an optional hook so the skill fires deterministically
  instead of relying on the agent's judgment.

## License

MIT.

## Contributing

Issues and PRs welcome. Please keep the skill minimal — if a change adds a
dependency, an env var, or a fallback path, the PR should explain why editing
`references/prompt-template.md` can't solve it instead.
