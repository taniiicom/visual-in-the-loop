# Create Pull Request

Create a pull request for the current branch.

## Instructions

1. Check current branch and remote status:
   - `git status`
   - `git log origin/main..HEAD`

2. **Check past merged PRs (REQUIRED)** — before drafting anything, read the 2–3 most recent merged PRs and match their format. Do not invent your own.
   - `gh pr list --state merged --limit 10`
   - `gh pr view <num> --json title,body` on the 2–3 most recent

3. If there are commits ahead of main:
   - Push the branch to remote if not already pushed
   - Read ALL commit messages on the branch to understand the full scope
   - Create a PR using `gh pr create` with format:
     ```
     ## Summary
     <bullet points summarizing all changes>

     ## Test plan
     <testing checklist>

     🤖 Generated with [Claude Code](https://claude.ai/code)
     ```

4. Report the PR URL

## Commands

```bash
# Push and create PR
git push -u origin <branch-name>
gh pr create --title "..." --body "..."
```

## Important

- Read ALL commit messages before writing the PR summary
- If `$ARGUMENTS` contains a PR title or description hint, use it
