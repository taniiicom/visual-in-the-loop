Plan: visual-in-the-loop skill

When a coding agent (Claude Code, Codex, spec-kit, ...) is about to ask the
user to review a plan or decide on something, this skill makes the agent
generate a single 1-page visual first — so the user reviews the picture
instead of a wall of text.

Flow:
1. The agent builds a plan in plan mode or clarify mode.
2. Just before calling AskUserQuestion or ExitPlanMode, the agent pipes the
   plan text into this skill via stdin.
3. The skill sends the text to Nano Banana Pro (Gemini 3 Pro Image) and
   receives a PNG.
4. The skill detects the user's environment and renders the image:
   - tmux + chafa → split-pane preview
   - VS Code / Cursor / Windsurf → markdown tab with the image
   - macOS → open (Preview.app)
   - Linux → xdg-open
5. Only after the image is on screen does the agent finally show the
   question to the user.
6. The user looks at the picture and answers.

Key idea: the agent never sees the image. It is a side channel from the
generative model straight to the human's eyes. The agent only confirms that
rendering happened, then proceeds with the question.
