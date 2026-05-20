---
name: visual-in-the-loop
description: >-
  Generate a single diagram (Nano Banana Pro / Gemini 3 Pro Image) of whatever
  you are about to ask the user to review or decide, and show it BEFORE you
  ask. USE PROACTIVELY whenever you are about to call AskUserQuestion,
  ExitPlanMode, or otherwise request a human decision on a multi-step plan, an
  ambiguous spec, an architecture choice, a UI mockup, or a set of options.
  Pipe the ACTUAL text of the plan or question into the skill verbatim — do
  not rewrite, summarize, split, or art-direct it; the model turns the real
  text into one diagram. Call this FIRST, then present the question. Humans
  review decisions far faster with a picture — do not just describe a diagram
  in text and skip this skill.
allowed-tools: Bash
license: MIT
---

# visual-in-the-loop

When you are about to pull the user's attention to make a decision, give them
a **picture** of it first. A single 1-page diagram cuts review time massively
compared to a wall of text.

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

One step. Pipe the **actual text** of what you are about to ask the user to
review or decide into `run.sh` via stdin. For a multi-line plan, use a
heredoc:

```bash
cat <<'EOF' | bash "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" --trigger plan
<the full plan text, exactly as you would present it to the user>
EOF
```

For a short question:

```bash
echo "<the question and all of its options>" \
  | bash "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh" --trigger clarify
```

**Pipe the real text, verbatim — this is the one thing that matters.** For
`ExitPlanMode`, that is the full plan you are about to present. For
`AskUserQuestion`, that is the question together with all of its options. Do
**NOT** rewrite it, summarize it, split it into pieces, or describe scenes /
art-direct the image. The skill wraps your text in a single one-line
instruction and the model turns the *actual content* into one diagram. If you
paraphrase the plan into your own words, the model draws your paraphrase, not
the plan — the result is markedly worse.

The skill produces exactly **one image**.

**Trigger flag.** `--trigger <type>` lets the user scope when the skill fires
(optional, fail-safe if omitted):

- `--trigger plan` — before `ExitPlanMode`
- `--trigger clarify` — before `AskUserQuestion`
- `--trigger decision` — any other significant decision moment

`${CLAUDE_PLUGIN_ROOT}` is set by Claude Code to this skill's root directory.
For a directly-installed skill, substitute the absolute path to this skill dir.

The script is **synchronous**. It returns only after the image has been
rendered to the user's environment. Only then should you call
`AskUserQuestion` / `ExitPlanMode` and pull the user's attention.

## What happens

1. `generate.mjs` reads the plan text from stdin, wraps it with the one-line
   instruction in `references/prompt-template.md`, and calls the configured
   provider once. The PNG is saved to `$TMPDIR/visual-in-the-loop/<ts>.png`.
2. `show.sh` detects the environment and uses ONE of:
   - **tmux + chafa**: a side pane, real graphics (chafa auto-detects the
     terminal's protocol — Kitty graphics, sixel, etc.), sized to fit the
     pane. Enter closes. Re-renders on resize.
   - **VS Code / Cursor / Windsurf**: a temp markdown tab with the image.
   - **macOS**: `open` (Preview).
   - **Linux desktop**: `xdg-open`.
3. `run.sh` prints `[visual-in-the-loop] rendered: <path>` to stdout.

## Failure mode

If the skill returns non-zero or the visual cannot be generated (no API key,
network error, model returns no image, no display path available, etc.),
**proceed with the question anyway without the visual**. The skill is a UX
enhancement — it must not block the conversation.

`run.sh` is designed to always exit 0 unless there is an unexpected bash
error, so failures normally surface as a stderr WARN line and a missing image
rather than a thrown error.

## Setup

- Node.js 18+ (uses the built-in `fetch`). No `npm install` required.
- Set the API key for whichever provider you use (see Configuration below).
- Optional, picked up automatically if present:
  - `tmux` + `chafa` — enables the in-terminal side-pane preview
  - `code` CLI — enables the VS Code markdown preview path

## Configuration

All configuration is through environment variables. Set them in your shell or
in `~/.claude/settings.json` under the `env` key.

| Env var | Values | Default | Notes |
|---|---|---|---|
| `VITL_ENABLED` | `1` / `0` (also `true`/`false`/`yes`/`no`/`on`/`off`, case-insensitive) | unset (= enabled) | Master switch. Only disables on `0`/`false`/`no`/`off`; any other value (including unset) is enabled. |
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

- **Do NOT** rewrite, summarize, split, or art-direct the plan before piping
  it in. Pipe the real text verbatim — the model needs the actual plan, not
  your paraphrase of it. This is the single most common way to make the
  output bad.
- **Do NOT** fall back to a Mermaid / ASCII / textual description of the
  diagram. The whole point is the model's open-ended image generation.
- **Do NOT** call `AskUserQuestion` or `ExitPlanMode` first and then run this
  skill. The order is: **generate visual → then ask**.
- **Do NOT** run this skill in the background and let the question display
  immediately. Run it synchronously.
- **Do NOT** add caching, thresholds, or "should I generate?" logic in front
  of the skill. Keep this path simple.

## Tuning

If diagrams come out off-target, edit `references/prompt-template.md` — that
one-line instruction is the only knob. Do not pile on heuristics in
`generate.mjs`, and do not pre-process the plan text upstream.
