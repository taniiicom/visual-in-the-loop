# Create New Branch

Create and checkout a new branch.

## Instructions

1. Get the branch name from the argument: `$ARGUMENTS`
2. If no branch name is provided, ask the user for one
3. Create and checkout the branch:
   ```bash
   git checkout -b <branch-name>
   ```
4. Report the status after creating the branch

## Verification

After creating the branch, run `git branch` to confirm the new branch is checked out.
