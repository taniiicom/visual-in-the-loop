---
name: visual-in-the-loop
description: >-
  Generate a single visual (Nano Banana Pro / Gemini 3 Pro Image) of any plan,
  spec, or design BEFORE asking the user to review or decide. USE PROACTIVELY
  whenever you are about to call AskUserQuestion, ExitPlanMode, or otherwise
  request human review of a multi-step plan, an ambiguous spec, an architecture
  choice, a UI mockup, or any conceptual design. This skill blocks until the
  image is rendered to the user's environment (open / tmux+chafa / VS Code
  markdown). Call this FIRST, then present the question. Humans review plans
  much faster with a visual — do not just describe the diagram in text and skip
  this skill.
allowed-tools: Bash
license: MIT
---

# visual-in-the-loop

When you are about to pull the user's attention to make a decision, give them a
**picture** of the decision first. A single 1-page visual cuts plan-review time
massively compared to reading a wall of text.

## When to use (read this first)

USE this skill PROACTIVELY in every one of these moments:

- Right before calling `AskUserQuestion` to ask the user a non-trivial decision
- Right before calling `ExitPlanMode` to confirm a multi-step plan
- During clarify / spec-kit style questioning when the user is asked to choose
  between approaches, architectures, UIs, or flows
- Any time you would otherwise write "let me describe the diagram in text"

If a question is genuinely trivial (yes/no on a 1-line change, simple typo
fix, etc.) you can skip. Default to **invoking the skill**.

## How to use

**Step 1 — decide what to visualize.** Before running the skill, *pause and
think*: "What 1–4 separate visuals would let the user grasp this plan at a
glance?" A typical plan deserves a small set of slides, e.g.:

- the overall architecture / components
- the data or control flow
- a UI mockup or screen layout
- a phase / step timeline

Pick the ones that actually help. Trivial plans need just one slide. Don't
manufacture slides for the sake of count.

**Step 2 — pass them as a JSON array on stdin.** Each item is
`{title, content}`; `content` is what Gemini will visualize, `title` is
shown to the user above the image (in the markdown / cycle UI).

```bash
cat <<'EOF' | bash "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" --trigger plan
[
  {
    "title": "Architecture",
    "content": "describe the architecture you want pictured..."
  },
  {
    "title": "Data flow",
    "content": "describe the data flow..."
  }
]
EOF
```

`title` is optional. You can also pass an array of plain strings:
`["content 1", "content 2"]`.

**Single-slide / legacy mode.** If you pipe anything that doesn't start with
`[`, the skill treats the whole stdin as one visualization request — useful
for quick or trivial plans.

```bash
echo "<plan or question>" | bash "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" --trigger plan
```

**Trigger flag.** Use `--trigger <type>` so the user can scope when the skill
fires (optional, fail-safe if omitted):

- `--trigger plan` — before `ExitPlanMode`
- `--trigger clarify` — before `AskUserQuestion`
- `--trigger decision` — any other significant decision moment

`${CLAUDE_PLUGIN_ROOT}` is set by Claude Code to this skill's root directory.
For a directly-installed skill, substitute the absolute path to this skill dir.

The script is **synchronous**. It returns only after every image has been
rendered to the user's environment. Only then should you call
`AskUserQuestion` / `ExitPlanMode` and pull the user's attention.

## What happens

1. `generate.mjs` parses stdin (JSON array → multi-slide, anything else →
   single image), then calls the configured provider once per slide. Each
   PNG is saved to `$TMPDIR/visual-in-the-loop/<timestamp>-<n>.png`.
2. `show.sh` detects the environment and uses ONE of:
   - **tmux + chafa**: a single side pane that shows all images; ← / →
     cycles, Enter closes. Re-renders on pane / window resize.
   - **VS Code / Cursor / Windsurf**: a temp markdown with each title and
     image embedded sequentially.
   - **macOS**: `open` with all paths (Preview opens them with a sidebar).
   - **Linux desktop**: `xdg-open` per image.
3. `run.sh` prints `[visual-in-the-loop] rendered N image(s)` to stdout.

## Failure mode

If the skill returns non-zero or the visual cannot be generated (no API key,
network error, model returns no image, no display path available, etc.),
**proceed with the question anyway without the visual**. The skill is a UX
enhancement — it must not block the conversation.

`run.sh` itself is designed to always exit 0 unless there is an unexpected
bash error, so failures will normally surface as a stderr WARN line and a
missing image rather than a thrown error.

## Setup

- Node.js 18+ (uses the built-in `fetch`). No `npm install` required.
- Set the API key for whichever provider you use (see Configuration below).
- Optional, picked up automatically if present:
  - `tmux` + `chafa` — enables the in-terminal split-pane preview
  - `code` CLI — enables the VS Code markdown preview path

## Configuration

All configuration is through environment variables. Set them in your shell or
in `~/.claude/settings.json` under the `env` key.

| Env var | Values | Default | Notes |
|---|---|---|---|
| `VITL_ENABLED` | `1` / `0` (also accepts `true`/`false`/`yes`/`no`/`on`/`off`, case-insensitive) | unset (= enabled) | Master switch. Only disables on `0`/`false`/`no`/`off`; any other value (including unset) is enabled. |
| `VITL_PROVIDER` | `gemini` / `vertexai` / `openai` / `azure` | `gemini` | Which API to call. |
| `VITL_MODEL` | provider-specific model id | provider default | E.g. `gemini-2.5-flash-image` for free-tier on Gemini. |
| `VITL_DISPLAY` | `auto` / `tmux` / `vscode` / `open` / `none` | `auto` | Force a display path, or `none` to suppress display. Unavailable choices fall back to `auto`. |
| `VITL_TRIGGER` | comma-separated list (e.g. `plan,clarify`) or `all` | `all` | Restricts which `--trigger <type>` values actually fire generation. |

### Provider-specific env

| `VITL_PROVIDER` | Required env | Default `VITL_MODEL` |
|---|---|---|
| `gemini` | `GEMINI_API_KEY` or `GOOGLE_API_KEY` | `gemini-3-pro-image-preview` |
| `vertexai` | `VITL_VERTEX_PROJECT` + `VITL_VERTEX_LOCATION` (auth via `gcloud auth application-default login`) | `gemini-3-pro-image-preview` |
| `openai` | `OPENAI_API_KEY` | `gpt-image-1` |
| `azure` | `AZURE_OPENAI_API_KEY` + `AZURE_OPENAI_ENDPOINT` + `AZURE_OPENAI_DEPLOYMENT` (optional `AZURE_OPENAI_API_VERSION`) | deployment-specific (`VITL_MODEL` ignored) |

## Do NOT

- **Do NOT** fall back to a Mermaid / ASCII / textual description of the
  diagram. The whole point is to use Nano Banana Pro's open-ended generation.
- **Do NOT** call `AskUserQuestion` or `ExitPlanMode` first and then run this
  skill. The order is: **generate visual → then ask**. Otherwise the user is
  pulled into the conversation before the visual is ready.
- **Do NOT** run this skill in the background and let the question display
  immediately. Run it synchronously.
- **Do NOT** add caching, thresholds, or "should I generate?" logic in front
  of the skill yet. Trust the model and keep this path simple.

## Tuning

If diagrams come out off-target, edit `references/prompt-template.md` — that
is the only knob. Do not pile on heuristics in `generate.mjs`.
