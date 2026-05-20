# Commit Changes

Commit changes using the project's commit message format.

## Instructions

1. Check for changes:
   - Run `git status` to see all changes
   - Run `git diff` to understand the changes

2. Stage appropriate files and create a commit with the format:
   ```
   [add,up,fix]: [short description]
   >>
   [user's prompt]
   ==
   [agent's final response]

   🤖 Generated with [Claude Code](https://claude.ai/code)

   Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
   ```

3. Report the commit status

## Important

- Do NOT push automatically - let the user decide when to push
- If the user provides specific commit context via `$ARGUMENTS`, use that for the commit message
- Always verify with `git status` after committing
