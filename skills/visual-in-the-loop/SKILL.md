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

One step. Pipe the plan / question text into `run.sh` via stdin:

```bash
echo "<plan or question text>" | bash "${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"
```

`${CLAUDE_PLUGIN_ROOT}` is set by Claude Code to this skill's root directory.
For a directly-installed skill, substitute the absolute path to this skill dir.

The script is **synchronous**. It returns only after the image has been
rendered to the user's environment. Only then should you call
`AskUserQuestion` / `ExitPlanMode` and pull the user's attention.

## What happens

1. `generate.mjs` reads the plan text from stdin, sends it to Gemini 3 Pro
   Image, and writes a PNG to `$TMPDIR/visual-in-the-loop/<timestamp>.png`.
2. `show.sh` detects the environment and uses ONE of:
   - **tmux + chafa**: split-pane preview (most embedded feel)
   - **VS Code / Cursor / Windsurf**: open a temp markdown with the image
   - **macOS**: `open` (default image viewer)
   - **Linux desktop**: `xdg-open`
3. `run.sh` prints `[visual-in-the-loop] rendered: <path>` to stdout.

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
- Set `GEMINI_API_KEY` (or `GOOGLE_API_KEY`) in the environment.
- Optional, picked up automatically if present:
  - `tmux` + `chafa` — enables the in-terminal split-pane preview
  - `code` CLI — enables the VS Code markdown preview path

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
