# Worktrees and branches

Each Claude session works in its own git worktree, so one ticket's branch lives in one folder.
Use this when a command fails because you're in the wrong folder or branch.

## Find a ticket's branch

```bash
git worktree list                   # every worktree, with the branch it has checked out
git branch --list 'c1-*'            # every ticket branch
```

A branch can be checked out in only one worktree. If `git switch <branch>` says it's already
checked out, go to the folder `git worktree list` shows for it. Don't force the switch.

## Check you're in the right place

```bash
git branch --show-current           # the ticket's branch, such as c1-09-replay-a-real-game-on-the-fake-pan
git log --oneline -1                # the commit you expect
```

## Get a copy of a branch in your current folder

Fetch it from the bot remote and make a local branch from it:

```bash
git fetch bot <branch>
git switch -c <local-name> FETCH_HEAD
```

Push from a worktree with `git push bot <branch>`, never `origin` (CLAUDE.md, "Claude's GitHub
identity").
