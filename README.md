# Visual in the Loop

> Hand humans a picture — not a wall of text — when an agent asks for a decision.

Plan agents (Claude Code's plan mode, Codex, spec-kit, and friends) are great at
generating plans, but plans-as-text are slow and painful to review. This skill
makes the agent quietly generate a single **1-page visual** with [Nano Banana
Pro / Gemini 3 Pro Image][nano] **right before** it calls `AskUserQuestion`,
`ExitPlanMode`, or any other "please review and decide" moment — so the human
reviews the picture, then answers.

[nano]: https://deepmind.google/models/gemini-image/pro/

## What's in this repo

A single skill, `visual-in-the-loop`, that you install into Claude Code (or any
agent that reads `~/.claude/skills/`).

```
skills/
└── visual-in-the-loop/
    ├── SKILL.md                  # Agent-facing instructions
    ├── scripts/
    │   ├── generate.mjs          # Plan text → PNG via Gemini API
    │   ├── show.sh               # Render the PNG to the user's environment
    │   └── run.sh                # Glue: generate, then show
    └── references/
        └── prompt-template.md    # Tunable prompt (3 lines)
```

## How it behaves

1. Just before the agent asks you to review a plan, it **picks 1–4 things in
   the plan worth visualizing** (architecture, data flow, UI mockup, phase
   timeline, etc.) and pipes them as a JSON array into the skill.
2. The skill calls Gemini 3 Pro Image once per slide and writes each PNG to
   a temp file.
3. The skill detects your environment and **renders all images into your view**:
   - In a **tmux** session with `chafa` installed → single side pane. One
     slide fits the pane; multiple slides render at full width stacked
     vertically — scroll to see them all. Enter to close. Re-renders on resize.
   - In **VS Code / Cursor / Windsurf** → a markdown tab with every title
     and image embedded.
   - On **macOS** → `open` with all paths (Preview opens them with a sidebar).
   - On **Linux** desktop → `xdg-open` per image.
4. Only **after** the slides are on screen does the agent show the actual
   question. You decide while looking at the pictures.

Trivial plans get a single image (the agent can also pipe plain text and
the skill treats it as one slide).

If anything goes wrong (no API key, network down, no display path), the skill
returns silently and the agent asks the question as usual. It never blocks the
conversation.

## Install

### Using the [`skills` CLI][skills-cli] (recommended)

```bash
npx skills add taniiicom/skills-visual-in-the-loop
```

This drops the skill into `~/.claude/skills/visual-in-the-loop/` and Claude
Code picks it up automatically on its next session.

[skills-cli]: https://github.com/vercel-labs/skills

### Manual (clone + symlink)

```bash
git clone https://github.com/taniiicom/skills-visual-in-the-loop.git
ln -s "$(pwd)/skills-visual-in-the-loop/skills/visual-in-the-loop" \
      ~/.claude/skills/visual-in-the-loop
```

## Setup

### 1. Gemini API key (required)

Get a key from [Google AI Studio](https://aistudio.google.com/apikey) and
export it. Either name works:

```bash
export GEMINI_API_KEY=...        # or GOOGLE_API_KEY
```

Add it to your `~/.zshrc` / `~/.bashrc` so it persists.

### 2. Node.js 18+ (required)

The skill uses the built-in `fetch`. No `npm install`, no `package.json`.

```bash
node --version    # should print v18 or higher
```

### 3. Display dependencies (optional, but recommended)

| You want | Install |
|---|---|
| Split-pane preview while you work in tmux | `brew install chafa` (macOS) / `apt install chafa` (Linux) |
| Markdown preview inside VS Code / Cursor / Windsurf | The `code` CLI (already installed if you use VS Code) |
| OS image viewer fallback | Already present on macOS (`open`) and Linux desktops (`xdg-open`) |

You don't need all of these. The skill falls back through them automatically
and picks the first one that's available in your environment.

## Configuration

All settings are environment variables. Put them in your shell, or in
`~/.claude/settings.json` under the `env` key so they apply to every Claude
Code session:

```jsonc
// ~/.claude/settings.json
{
  "env": {
    "GEMINI_API_KEY": "AIza...",
    "VITL_PROVIDER": "gemini",
    "VITL_MODEL": "gemini-3-pro-image-preview",
    "VITL_DISPLAY": "auto",
    "VITL_TRIGGER": "all"
  }
}
```

For project-only overrides, use the same `env` block in
`<project>/.claude/settings.local.json` (which is gitignored by default).

### All variables

| Variable | Values | Default | Purpose |
|---|---|---|---|
| `VITL_ENABLED` | `1` / `0` (and `true`/`false`/`yes`/`no`/`on`/`off`) | unset = on | Master switch. Only `0`/`false`/`no`/`off` disable; everything else stays on. |
| `VITL_PROVIDER` | `gemini` / `vertexai` / `openai` / `azure` | `gemini` | Which API to call. |
| `VITL_MODEL` | provider-specific id | provider default | E.g. `gemini-2.5-flash-image` for free-tier Gemini. |
| `VITL_DISPLAY` | `auto` / `tmux` / `vscode` / `open` / `none` | `auto` | Force a display path, or `none` to suppress. Unusable choices fall back to `auto`. |
| `VITL_TRIGGER` | comma-separated (`plan,clarify,decision`) or `all` | `all` | Which `--trigger <type>` invocations actually fire generation. |

### Per-provider keys

| `VITL_PROVIDER` | Required env vars | Default `VITL_MODEL` |
|---|---|---|
| `gemini` | `GEMINI_API_KEY` *or* `GOOGLE_API_KEY` | `gemini-3-pro-image-preview` |
| `vertexai` | `VITL_VERTEX_PROJECT` + `VITL_VERTEX_LOCATION` (auth via `gcloud auth application-default login`, see below) | `gemini-3-pro-image-preview` |
| `openai` | `OPENAI_API_KEY` | `gpt-image-1` |
| `azure` | `AZURE_OPENAI_API_KEY` + `AZURE_OPENAI_ENDPOINT` + `AZURE_OPENAI_DEPLOYMENT` (optional `AZURE_OPENAI_API_VERSION`, default `2024-10-21`) | deployment-specific (`VITL_MODEL` is ignored — model is set by the deployment) |

**Vertex AI auth note**: the skill calls
`gcloud auth application-default print-access-token` at runtime to keep itself
zero-dependency. Install the [gcloud CLI][gcloud] and run
`gcloud auth application-default login` once. If gcloud isn't available the
provider returns a clear error and the agent proceeds without a visual.

[gcloud]: https://cloud.google.com/sdk/docs/install

### Fail-safes

The skill is deliberately permissive:

- If the agent forgets to pass `--trigger <type>` while `VITL_TRIGGER` is
  restrictive, the skill **still generates** (never miss a visualization
  because the agent forgot a flag).
- If `VITL_DISPLAY` is set to a path that isn't usable in your environment
  (e.g. `tmux` without `chafa`), the skill warns and falls back to `auto`.
- If `VITL_ENABLED` is set to something that isn't a recognized false value,
  the skill stays enabled.

Goal: nothing the user types into config should silently break the conversation.

## Try it

After installing, smoke-test it with the bundled sample plan — the image you
get back is a visual explanation of what the skill does, so it doubles as a
tutorial:

```bash
cat ~/.claude/skills/visual-in-the-loop/references/sample-plan.md \
  | bash ~/.claude/skills/visual-in-the-loop/scripts/run.sh
```

You should see:

- `[visual-in-the-loop] rendered: /var/folders/.../<timestamp>.png` on stdout
- An image popping up in your image viewer / tmux pane / VS Code, depicting
  the agent → skill → image → user flow

Then start a Claude Code session and ask for a non-trivial plan (e.g.
"Refactor the auth module — make a plan first"). When the agent gets to
`ExitPlanMode` or `AskUserQuestion`, the picture should appear before the
question does.

## Tuning

There is exactly **one knob**: `skills/visual-in-the-loop/references/prompt-template.md`.

It is intentionally 3 lines. If your diagrams come out off-target, edit that
file — do not add heuristics, type detection, or fallbacks in `generate.mjs`.
Trust the model.

## Design notes

A few opinionated choices that may not be obvious from the code:

- **No Mermaid / D2 fallback.** This skill exists *because* Mermaid-like
  diagrams are not the kind of visualization plans need. Don't add a
  "structure-diagrams-via-Mermaid, the-rest-via-Gemini" split — it defeats the
  premise.
- **Synchronous, not background.** Generation takes ~5–15 s. Doing it in the
  background and showing the question immediately means the user is summoned
  to a half-rendered review — exactly the friction this skill exists to
  prevent. Wait for the image, then ask.
- **The agent doesn't see the image, the human does.** The agent only receives
  the PNG path as a confirmation line. The picture is a side-channel to the
  human's eyeballs.
- **MVP is skill-driven, not hook-driven.** A `PreToolUse` hook on
  `AskUserQuestion` / `ExitPlanMode` would be the obvious fit, but as of this
  writing Claude Code hook support for these tools is incomplete
  ([anthropics/claude-code#12031], [#12605]). Instead the SKILL.md description
  nudges the agent to call this skill voluntarily. If you find it under-firing
  in practice, the fix is to make the description even pushier.

[anthropics/claude-code#12031]: https://github.com/anthropics/claude-code/issues/12031
[#12605]: https://github.com/anthropics/claude-code/issues/12605

## Troubleshooting

**The agent doesn't call the skill before asking me.**
The description in `SKILL.md` may need to be more aggressive about when to
trigger. Edit the `description:` field in the frontmatter, restart your
session, and try again.

**`[visual-in-the-loop] no display path available`.**
You're in an environment without any of: `$TMUX`+chafa, VS Code, `open`,
`xdg-open`. Install one. On a remote `ssh` session this is expected — the
skill will quietly exit and the question proceeds normally.

**`API <status>: ...` in stderr.**
Usually a missing or invalid `GEMINI_API_KEY`. The skill exits 1 and the
agent's question proceeds without an image.

**Image is generated but not shown in tmux.**
You need `chafa` (`brew install chafa` / `apt install chafa`). Without it the
skill falls through to `open` / `xdg-open`.

## Roadmap

- `references/hook-example.md` — once Claude Code's `PermissionRequest` /
  `PreToolUse` matchers stabilize for `AskUserQuestion` and `ExitPlanMode`,
  add an optional hook config so the skill fires deterministically rather
  than relying on the agent's judgment.

## License

MIT. See [LICENSE](LICENSE) if present, otherwise this notice is the license.

## Contributing

Issues and PRs welcome. Please keep the skill minimal — if a change adds a
new dependency, an environment variable, a config knob, or a fallback path,
the PR should explain why it can't be solved by editing
`references/prompt-template.md` instead.
