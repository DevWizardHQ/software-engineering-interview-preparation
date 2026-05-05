# Git Interview Questions

A practical, teaching-style Q&A guide for Git. Each question gives a plain-language explanation followed by real command sequences a beginner can follow along with.

---

## Table of Contents

1. Fundamentals
2. Working Directory, Staging, Commits
3. Branches, Merge, Rebase
4. Resetting, Reverting, Recovery
5. Stash, Cherry-pick, Reflog
6. Tags and Releases
7. Remotes, Push, Pull
8. Workflows and Code Review
9. Hooks, Submodules, LFS
10. Worktrees, Bisect, Blame
11. Configuration, Aliases, Performance
12. Common Scenarios

---

## 1. Fundamentals

## Q1. What is Git?

**Answer:**

Git is a distributed version control system. It tracks every change you make to a set of files, lets you create branches to work on multiple things in parallel, and lets you collaborate with others. "Distributed" means every clone is a full copy of the project history — you can commit, branch, and view history without a network.

```bash
git --version
# git version 2.43.0
```

## Q2. What is the difference between a centralized and a distributed VCS?

**Answer:**

In a centralized system (SVN, CVS), there is one server that holds the history. To commit, you must talk to it. If the server is down or unreachable, you cannot work.

In a distributed system (Git, Mercurial), every clone holds the full history. You can commit, look at history, and create branches offline. Pushing and pulling syncs your clone with a remote.

## Q3. What is Git's three-tree model?

**Answer:**

Git tracks files across three "trees":

| Tree              | Description                                                  |
| ----------------- | ------------------------------------------------------------ |
| Working directory | Your actual files on disk that you edit                      |
| Index (staging)   | A snapshot of what will go into the next commit              |
| HEAD              | The latest commit on the current branch                      |

A typical workflow moves changes between them:

```bash
# 1. Edit a file
echo "hello" > note.txt

# 2. Stage it (working dir -> index)
git add note.txt

# 3. Commit it (index -> HEAD)
git commit -m "add note"

# Inspect the trees
git status                  # working dir vs index vs HEAD
git diff                    # working dir vs index
git diff --cached           # index vs HEAD
```

## Q4. What are the Git internal object types?

**Answer:**

Git stores everything as one of four object types in `.git/objects/`:

| Object | Purpose                                                            |
| ------ | ------------------------------------------------------------------ |
| blob   | The contents of a file (no name, no permissions)                   |
| tree   | A directory: a list of blobs and other trees with names and modes  |
| commit | A pointer to a tree, plus parent commit(s), author, message        |
| tag    | A named pointer to a commit (annotated tags only)                  |

Every object is identified by a SHA-1 hash of its content.

```bash
git cat-file -t HEAD             # type: commit
git cat-file -p HEAD             # show the commit's content
git cat-file -p HEAD^{tree}      # show the root tree
```

## Q5. What does a commit contain?

**Answer:**

A commit object contains:

1. A reference to the root tree (a snapshot of the entire project at that point).
2. Parent commit references (one for normal commits, two for merges, zero for the initial commit).
3. Author and committer (name, email, timestamp).
4. The commit message.

```bash
git show --no-patch HEAD
# commit abc123...
# Author: Alice <alice@example.com>
# Date:   Mon May 5 10:00:00 2025 +0000
#
#     Add note
```

## Q6. What do HEAD, main, and origin refer to?

**Answer:**

- **HEAD** is a pointer to the current commit you have checked out. Usually it points to a branch name, which then points to a commit.
- **main** (or **master**) is the default branch name in many repositories — just a label pointing to a commit.
- **origin** is the default name for the remote you cloned from. `origin/main` is your local view of the remote's `main` branch.

```bash
cat .git/HEAD            # ref: refs/heads/main
git branch               # which branch HEAD points to
git remote -v            # remote URLs
```

---

## 2. Working Directory, Staging, Commits

## Q7. What do `git status` and `git diff` show?

**Answer:**

`git status` summarizes which files are modified, staged, or untracked.

`git diff` shows the actual line-level changes.

```bash
git status                # full status report
git status -s             # short version
git diff                  # working dir changes (not yet staged)
git diff --cached         # staged changes
git diff HEAD             # all uncommitted changes (staged + unstaged)
git diff main..feature    # changes on feature not on main
```

## Q8. How do you stage changes granularly?

**Answer:**

You can stage entire files, individual files, or even individual chunks (hunks) of a file.

```bash
git add file.txt              # stage one file
git add src/                  # stage a directory
git add .                     # stage everything in current dir
git add -A                    # stage everything in the repo
git add -p                    # interactively stage hunks (very useful)
git restore --staged file.txt # unstage a file
```

`git add -p` walks you through each change and asks "stage this? [y/n/s/...]". Great for splitting unrelated edits into separate commits.

## Q9. What are good commit message conventions?

**Answer:**

A common convention is **Conventional Commits**:

```text
type(scope): short summary

Optional longer body explaining the why.

Footer: BREAKING CHANGE, references, etc.
```

Examples:

```text
feat(auth): add OAuth2 login
fix(billing): handle null discount in invoice total
refactor(orders): extract pricing to a service
docs: update README with deploy steps
chore: bump dependencies
```

Rules of thumb: 50-character subject, imperative mood ("add" not "added"), explain *why* in the body if not obvious.

## Q10. How do you amend a commit?

**Answer:**

`git commit --amend` rewrites the most recent commit. Use it to fix a typo in the message or to add a forgotten file.

```bash
git add forgotten-file.txt
git commit --amend                    # opens editor for new message
git commit --amend --no-edit          # keep the same message
```

Caution: amending changes the commit's SHA. Do not amend commits that have already been pushed to a shared branch.

---

## 3. Branches, Merge, Rebase

## Q11. What are the basic branch operations?

**Answer:**

```bash
git branch                          # list local branches
git branch -a                       # include remote-tracking branches
git switch -c feature/login         # create and switch (new style)
git checkout -b feature/login       # create and switch (older style)
git switch main                     # switch back
git branch -d feature/login         # delete (safe; refuses if unmerged)
git branch -D feature/login         # delete (force)
git branch -m old-name new-name     # rename
```

## Q12. What is the difference between a fast-forward and a three-way merge?

**Answer:**

A **fast-forward** merge happens when the target branch (e.g., `main`) has not moved since the feature branch started. Git just moves `main`'s pointer forward to the feature's tip — no merge commit needed.

A **three-way merge** happens when both branches have new commits. Git combines the changes from both sides and creates a new merge commit with two parents.

```bash
git merge feature/login                 # fast-forward if possible
git merge --no-ff feature/login         # always create a merge commit
git merge --ff-only feature/login       # refuse if not fast-forward
```

`--no-ff` keeps the feature branch visible in the history graph, which many teams prefer.

## Q13. Merge vs rebase — what is the difference?

**Answer:**

**Merge** preserves history exactly as it happened. The merge commit shows where two lines of work joined.

**Rebase** rewrites your branch's commits as if they had been made on top of the latest target branch. The result is a clean linear history.

```bash
# Merge approach
git switch feature
git merge main           # creates a merge commit on feature

# Rebase approach
git switch feature
git rebase main          # replay feature commits on top of main
# resolve any conflicts as Git pauses; then:
git rebase --continue
# or to abort:
git rebase --abort
```

Rule of thumb: rebase your *local* branch to keep history clean before merging it; never rebase a branch others are working on.

## Q14. What is interactive rebase?

**Answer:**

Interactive rebase lets you reorder, edit, squash, or drop commits before they reach the shared branch.

```bash
git rebase -i HEAD~5
```

Git opens an editor showing the last 5 commits:

```text
pick a1b2c3 add login form
pick d4e5f6 fix typo
pick g7h8i9 add password reset
pick j1k2l3 wip
pick m4n5o6 polish login UI
```

Change `pick` to:
- `reword` — keep the commit, change the message
- `edit` — pause to amend the commit
- `squash` — combine into the previous commit (asks for a new message)
- `fixup` — like squash but discards this commit's message
- `drop` — remove the commit entirely

You can also reorder lines.

## Q15. How do you resolve merge conflicts?

**Answer:**

When Git cannot automatically combine changes, it inserts conflict markers in the file:

```text
<<<<<<< HEAD
const port = 3000;
=======
const port = 8080;
>>>>>>> feature/port
```

To resolve:

```bash
# 1. Edit each conflicted file, choose the right content,
#    remove the <<<<<<< ======= >>>>>>> markers.
# 2. Stage the resolved files.
git add src/app.js
# 3. Continue the operation.
git commit                       # for merge
git rebase --continue            # for rebase
```

Useful tools:

```bash
git status                       # shows files with conflicts
git diff                         # shows the conflict regions
git mergetool                    # opens a GUI tool
git checkout --ours file         # take our version
git checkout --theirs file       # take their version
```

## Q16. What is the difference between `git pull` and `git fetch`?

**Answer:**

- `git fetch` downloads new commits from the remote into your local remote-tracking branches (`origin/main`, etc.) but **does not change your working branch**.
- `git pull` is `git fetch` + `git merge` (or `git pull --rebase` is `git fetch` + `git rebase`). It updates your current branch.

```bash
git fetch                        # safe; just refreshes origin/* refs
git log main..origin/main        # see what would be pulled

git pull                         # default: fetch + merge
git pull --rebase                # fetch + rebase (linear history)
```

A good default is `git config --global pull.rebase true`.

---

## 4. Resetting, Reverting, Recovery

## Q17. What is the difference between `git reset --soft`, `--mixed`, and `--hard`?

**Answer:**

`git reset` moves the current branch pointer to a specific commit. The flag controls what happens to the index and working directory.

| Flag      | Branch | Index    | Working dir | Use case                                    |
| --------- | ------ | -------- | ----------- | ------------------------------------------- |
| `--soft`  | moved  | unchanged | unchanged   | Undo a commit but keep changes staged       |
| `--mixed` (default) | moved | reset to commit | unchanged | Undo commit and unstage changes |
| `--hard`  | moved  | reset    | reset       | Throw everything away (destructive!)        |

```bash
git reset --soft HEAD~1          # undo last commit, keep changes staged
git reset HEAD~1                 # undo last commit, keep changes in working dir
git reset --hard HEAD~1          # delete the last commit AND its changes
```

## Q18. What is `git revert`?

**Answer:**

`git revert` creates a *new* commit that undoes the changes of a previous commit. It does not rewrite history.

```bash
git revert abc1234               # creates "Revert ... abc1234" commit
git revert HEAD                  # revert the most recent commit
git revert -n abc1234            # stage but don't commit yet
```

This is the safe way to undo something on a shared branch.

## Q19. Revert vs reset — when do I use which?

**Answer:**

| Tool           | Effect                              | Safe on shared branches? |
| -------------- | ----------------------------------- | ------------------------ |
| `git revert`   | Adds a new commit that undoes       | Yes                      |
| `git reset`    | Moves the branch pointer (rewrites) | No (force-push needed)   |

Use `revert` to undo a commit that has been pushed. Use `reset` to clean up your *local* commits before pushing.

## Q20. How do you recover lost commits with the reflog?

**Answer:**

`git reflog` records every place HEAD has been. If you accidentally reset, rebased, or deleted a branch, the commits are still there for ~90 days.

```bash
git reflog
# abc1234 HEAD@{0}: reset: moving to HEAD~3
# def5678 HEAD@{1}: commit: my important work     <- this is what I want back
# ...

git checkout def5678               # detach HEAD onto the lost commit
git switch -c rescue               # create a branch from it
```

## Q21. What are `git restore` and `git switch`?

**Answer:**

These are newer commands (Git 2.23+) that split `git checkout` into clearer halves.

- **`git switch`** changes branches.
- **`git restore`** restores files.

```bash
git switch main                    # switch branch
git switch -c feature              # create and switch

git restore file.txt               # discard working-dir changes
git restore --staged file.txt      # unstage
git restore --source=HEAD~1 file.txt   # restore from a specific commit
```

The old `git checkout` still works but is overloaded.

---

## 5. Stash, Cherry-pick, Reflog

## Q22. How does `git stash` work?

**Answer:**

`git stash` saves your uncommitted changes (working dir + staged) and reverts the working dir to a clean state, so you can switch branches without losing work.

```bash
git stash                          # stash with default message
git stash push -m "wip auth fix"   # stash with a message
git stash list
# stash@{0}: On feature: wip auth fix

git stash pop                      # apply latest stash and remove it
git stash apply stash@{1}          # apply specific stash, keep it
git stash drop stash@{0}           # delete a stash
git stash show -p stash@{0}        # show what's in the stash

git stash -u                       # include untracked files
```

## Q23. What is `git cherry-pick`?

**Answer:**

Cherry-pick copies a single commit from one branch onto your current branch.

```bash
git switch main
git cherry-pick abc1234            # apply commit abc1234 here
git cherry-pick abc1234 def5678    # multiple commits
git cherry-pick A..B               # range (exclusive of A)
git cherry-pick --abort
```

Common use: hotfix on `main` needs to be replayed onto a release branch.

---

## 6. Tags and Releases

## Q24. What is the difference between lightweight and annotated tags?

**Answer:**

- **Lightweight tag**: just a name pointing to a commit. No metadata.
- **Annotated tag**: a full Git object with author, date, message, optional GPG signature. Recommended for releases.

```bash
git tag v1.0.0                                # lightweight
git tag -a v1.0.0 -m "Release 1.0.0"          # annotated
git tag -s v1.0.0 -m "Signed"                 # signed (GPG)

git tag                              # list
git show v1.0.0
git push origin v1.0.0               # push one tag
git push origin --tags               # push all tags
git tag -d v1.0.0                    # delete locally
git push origin :refs/tags/v1.0.0    # delete remotely
```

## Q25. How does SemVer work with tags?

**Answer:**

Semantic Versioning uses `MAJOR.MINOR.PATCH`:

- **MAJOR**: breaking changes
- **MINOR**: new features, backward compatible
- **PATCH**: bug fixes, backward compatible

```bash
git tag -a v1.4.2 -m "Fix login redirect bug"
git tag -a v1.5.0 -m "Add OAuth2 support"
git tag -a v2.0.0 -m "Drop support for Node 16"
```

Many teams automate tagging from CI based on commit messages (e.g., semantic-release).

---

## 7. Remotes, Push, Pull

## Q26. How do you manage remotes?

**Answer:**

```bash
git remote -v                                            # list remotes
git remote add origin git@github.com:org/repo.git
git remote add upstream git@github.com:upstream/repo.git
git remote set-url origin git@github.com:org/new-repo.git
git remote rename origin github
git remote remove upstream
```

## Q27. Show me the fork workflow with `upstream`.

**Answer:**

When you fork someone else's repo on GitHub, your fork is `origin`. The original repo is conventionally added as `upstream`.

```bash
git clone git@github.com:me/forked-repo.git
cd forked-repo
git remote add upstream git@github.com:original/forked-repo.git

# Stay in sync with the original:
git fetch upstream
git switch main
git merge upstream/main           # or: git rebase upstream/main
git push origin main
```

## Q28. What are the semantics of `git push`?

**Answer:**

```bash
git push                          # push current branch to its tracked remote
git push origin feature           # push branch to origin
git push -u origin feature        # set upstream tracking, then push
git push --tags                   # push tags
git push --delete origin feature  # delete remote branch
```

By default Git pushes only matching branches; modern Git uses `simple` mode (push current branch to the same name on remote).

## Q29. When should you NOT force-push?

**Answer:**

Never force-push to a branch that other people are working on. Force-pushing rewrites history; anyone who has pulled the old history will get confused, and resolving the mess is painful.

Force-push only on your *own* feature branch that nobody else is using. Force-pushing to `main` or release branches should be blocked by branch protection.

## Q30. `--force` vs `--force-with-lease` — what is the difference?

**Answer:**

- **`--force`** unconditionally overwrites the remote branch. If a teammate has pushed something you have not pulled, you will silently destroy their commits.
- **`--force-with-lease`** only force-pushes if the remote is in the state you expect (i.e., nobody else pushed since your last fetch).

Always prefer `--force-with-lease`.

```bash
git push --force-with-lease origin feature
```

---

## 8. Workflows and Code Review

## Q31. Gitflow vs trunk-based development?

**Answer:**

| Aspect             | Gitflow                                   | Trunk-based                          |
| ------------------ | ----------------------------------------- | ------------------------------------ |
| Long-lived branches| `main`, `develop`, `release/*`, `hotfix/*` | Mostly `main` only                  |
| Feature branches   | Long-lived; merged to `develop`           | Short-lived (hours/days)             |
| Releases           | From `release/*` branches                 | Tag a commit on `main`               |
| Best for           | Slow release cycles, multiple versions    | Continuous delivery                  |

Modern teams favor trunk-based with feature flags for new functionality.

## Q32. What are the essentials of feature branching?

**Answer:**

1. Branch off `main` for each feature/bugfix.
2. Keep branches short-lived (a few days max).
3. Rebase or merge `main` into your branch frequently to reduce conflicts.
4. Open a pull/merge request when ready.
5. Squash or rebase-merge to keep `main` history clean.
6. Delete the branch after merging.

```bash
git switch main
git pull
git switch -c feature/cart-coupon
# ... edit, commit, push, open PR ...
```

## Q33. What are the PR merge strategies?

**Answer:**

GitHub/GitLab usually offer three:

| Strategy       | Result on main                                | Best for                            |
| -------------- | --------------------------------------------- | ----------------------------------- |
| Merge commit   | All feature commits + a merge commit          | Preserve detailed history           |
| Squash & merge | One commit on main summarizing the PR         | Clean main, throwaway feature steps |
| Rebase & merge | Feature commits replayed linearly (no merge)  | Clean main, keep individual commits |

Most teams choose squash or rebase for `main` and merge commits for long-lived release branches.

## Q34. Code review etiquette in git?

**Answer:**

1. Keep PRs small (~200-400 lines of diff if possible).
2. One logical change per commit.
3. Write a good PR description: what, why, how to test.
4. Respond to feedback with new commits while review is in progress; squash before merging.
5. Test locally before clicking "approve."
6. Re-request review after substantive changes.

---

## 9. Hooks, Submodules, LFS

## Q35. What are git hooks?

**Answer:**

Git hooks are scripts in `.git/hooks/` that run at specific points in the workflow. Common hooks: `pre-commit`, `commit-msg`, `pre-push`, `post-merge`.

```bash
# .git/hooks/pre-commit (executable)
#!/usr/bin/env bash
npm test || exit 1
```

```bash
chmod +x .git/hooks/pre-commit
```

Hooks live outside the repo, so to share them use a tool like **pre-commit** or **husky**:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
```

## Q36. What are submodules?

**Answer:**

A submodule is a Git repo embedded inside another. The parent repo records a specific commit of the submodule.

```bash
git submodule add https://github.com/org/lib vendor/lib
git commit -m "Add lib submodule"

git clone --recursive <repo>          # clone with submodules
git submodule update --init --recursive   # if you forgot --recursive
git submodule update --remote         # update to latest remote commit
```

Submodules are powerful but tricky — they are commonly avoided in favor of package managers.

## Q37. Submodules vs subtrees?

**Answer:**

| Aspect          | Submodule                          | Subtree                            |
| --------------- | ---------------------------------- | ---------------------------------- |
| Storage         | Reference to external repo         | Copy of files merged into history  |
| Cloning         | Need `--recursive`                 | Just clone, everything is there    |
| Updating        | `git submodule update`             | `git subtree pull`                 |
| Complexity      | Higher; users often forget commands| Lower; transparent                 |

## Q38. What is `.gitignore`?

**Answer:**

`.gitignore` lists patterns of files Git should not track. One per line, supports globs.

```text
# Dependencies
node_modules/
vendor/

# Build
dist/
build/
*.o

# Env
.env
.env.local

# IDE
.idea/
.vscode/

# OS
.DS_Store
Thumbs.db

# Logs
*.log
```

To stop tracking a file that is already committed, you also need `git rm --cached`:

```bash
echo ".env" >> .gitignore
git rm --cached .env
git commit -m "stop tracking .env"
```

## Q39. What is `.gitattributes`?

**Answer:**

`.gitattributes` controls per-path Git behavior: line endings, diff/merge drivers, export behavior.

```text
* text=auto eol=lf
*.png binary
*.lock linguist-generated=true
package-lock.json merge=ours
```

The first line forces LF line endings, which prevents the classic Windows/Mac/Linux line-ending conflicts.

## Q40. What is Git LFS?

**Answer:**

Git LFS (Large File Storage) replaces large files in your repo with small text pointers. The actual file content is stored on a separate LFS server.

```bash
git lfs install
git lfs track "*.psd"
git lfs track "*.mp4"
git add .gitattributes
git add design.psd
git commit -m "add design"
git push
```

Use LFS for large binary assets that change rarely. Without LFS, big binaries bloat the history forever.

## Q41. What are signed commits?

**Answer:**

Signed commits use GPG or SSH keys to cryptographically prove who made the commit. Otherwise the author field is just a string.

```bash
# GPG
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true
git commit -m "signed commit"

# SSH (Git 2.34+)
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```

GitHub shows a green "Verified" badge for signed commits.

---

## 10. Worktrees, Bisect, Blame

## Q42. What are git worktrees?

**Answer:**

A worktree lets you check out multiple branches at once into different directories without re-cloning the repo.

```bash
git worktree add ../repo-hotfix hotfix/login-bug
cd ../repo-hotfix
# work, commit, push

cd -
git worktree list
git worktree remove ../repo-hotfix
```

Useful when you want to keep your main work intact and quickly fix something on another branch.

## Q43. What is `git bisect`?

**Answer:**

`git bisect` does a binary search through the commit history to find the commit that introduced a bug.

```bash
git bisect start
git bisect bad                  # current HEAD is broken
git bisect good v1.0.0          # this older tag was fine
# Git checks out a commit in between; you test
git bisect bad                  # or 'good' depending on test result
# repeat until git names the culprit
git bisect reset
```

Even better, automate it:

```bash
git bisect start HEAD v1.0.0
git bisect run npm test
```

## Q44. What do `git blame` and `git log -L` do?

**Answer:**

`git blame` shows who last touched each line of a file.

```bash
git blame src/auth.js
git blame -L 100,150 src/auth.js     # only lines 100-150
```

`git log -L` shows the full history of a specific function or line range.

```bash
git log -L :functionName:src/auth.js
git log -L 100,150:src/auth.js
```

## Q45. What are some useful log filters?

**Answer:**

```bash
git log --oneline --graph --decorate --all
git log --since="2 weeks ago"
git log --author="Alice"
git log --grep="bug"                       # search commit messages
git log -S"functionName"                   # commits adding/removing the string
git log --follow src/old-name.js           # track renames
git log --stat                             # file change summary
git log -p                                 # full patches
git log -- src/                            # only commits touching src/
```

---

## 11. Configuration, Aliases, Performance

## Q46. What useful global config should I set?

**Answer:**

```bash
git config --global user.name "Alice"
git config --global user.email "alice@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global rebase.autoStash true
git config --global core.editor "code --wait"
git config --global merge.conflictStyle zdiff3
git config --global push.default current
git config --global push.autoSetupRemote true
git config --global fetch.prune true
git config --global help.autocorrect 20
```

Show your current config:

```bash
git config --list --show-origin
```

## Q47. What are some useful git aliases?

**Answer:**

```bash
git config --global alias.s   "status -s"
git config --global alias.co  "checkout"
git config --global alias.br  "branch"
git config --global alias.cm  "commit -m"
git config --global alias.lg  "log --oneline --graph --decorate --all"
git config --global alias.unstage "restore --staged"
git config --global alias.amend  "commit --amend --no-edit"
```

Now `git lg` gives you a pretty graph; `git s` is fast status.

## Q48. How do you handle performance with large repos?

**Answer:**

```bash
git clone --depth=1 <url>             # shallow clone, only latest commit
git clone --filter=blob:none <url>    # partial clone, fetch blobs on demand
git sparse-checkout init --cone       # check out only some directories
git sparse-checkout set src/ docs/

# Maintenance
git maintenance start                  # background tasks: gc, pack, prefetch
git gc --aggressive --prune=now        # one-shot deep cleanup
```

## Q49. What is `git gc` and maintenance?

**Answer:**

`git gc` (garbage collect) removes unreachable objects and packs loose objects into pack files for speed and space.

```bash
git gc                          # routine
git gc --aggressive --prune=now # one-time aggressive cleanup
git fsck                        # integrity check
git count-objects -v            # repo statistics
```

Modern Git can run maintenance automatically:

```bash
git maintenance start
```

## Q50. What do you watch for in monorepos?

**Answer:**

1. Slow operations: enable partial/sparse clones (`--filter=blob:none`, `sparse-checkout`).
2. CI selectivity: only build/test packages that changed.
3. Atomic, large commits across many directories.
4. Shared tooling: monorepos benefit from tools like Nx, Turborepo, or Bazel.
5. Codeowners files for review routing.

---

## 12. Common Scenarios

## Q51. "I committed to the wrong branch."

**Answer:**

Move the commits to the right branch.

```bash
# Suppose you committed N commits on main that should be on feature
git switch -c feature              # create feature from current state
git switch main
git reset --hard origin/main       # rewind main to clean state
git switch feature
```

Or move just the last commit:

```bash
git switch feature                 # create or switch to right branch
git cherry-pick main               # take latest main commit
git switch main
git reset --hard HEAD~1
```

## Q52. "I want to undo `git push`."

**Answer:**

The safe way is `git revert` — it adds a new commit that undoes the change. History is preserved.

```bash
git revert abc1234
git push
```

The unsafe way is to rewrite history (only on a branch you control):

```bash
git reset --hard HEAD~1
git push --force-with-lease
```

## Q53. "I committed a secret. How do I purge it?"

**Answer:**

If the commit has not been pushed, `git reset` and re-commit. If it has been pushed, you must rewrite history *and* rotate the secret (the secret should be considered compromised).

```bash
# Modern tool: git-filter-repo
pip install git-filter-repo
git filter-repo --path secrets.env --invert-paths

# Or BFG Repo-Cleaner
bfg --delete-files secrets.env

# Then force-push (and notify the team)
git push --force --all
git push --force --tags
```

Always rotate the leaked credential — assume it has been seen.

## Q54. "I want to change the author of past commits."

**Answer:**

For the most recent commit:

```bash
git commit --amend --author="Alice <alice@example.com>" --no-edit
```

For a range (interactive rebase, then amend each):

```bash
git rebase -i HEAD~5
# mark commits as 'edit'
# for each pause:
git commit --amend --author="Alice <alice@example.com>" --no-edit
git rebase --continue
```

## Q55. "I want to split one commit into many."

**Answer:**

```bash
git rebase -i <commit>^
# mark target commit as 'edit'
# when rebase pauses:
git reset HEAD^                # un-commit, keep changes in working dir
git add file1
git commit -m "first part"
git add file2
git commit -m "second part"
git rebase --continue
```

## Q56. "I want to combine the last 3 commits into one."

**Answer:**

```bash
git rebase -i HEAD~3
# change last two from 'pick' to 'squash' (or 'fixup')
# save and edit the combined commit message
```

Or non-interactively:

```bash
git reset --soft HEAD~3
git commit -m "combined message"
```

## Q57. "I want to recover a deleted branch."

**Answer:**

```bash
git reflog
# find the last commit of the deleted branch, e.g. abc1234
git switch -c recovered-branch abc1234
```

If the deletion happened on a remote, ask whoever has the branch in their reflog (or check the GitHub events log).

## Q58. "Two people changed the same line."

**Answer:**

You will get a merge conflict. Coordinate with the team to decide the right answer.

```bash
git pull origin main
# CONFLICT in src/app.js
# manually resolve the file (remove markers, choose content)
git add src/app.js
git commit
# or, with deliberate decision:
git checkout --ours src/app.js     # keep your version
git checkout --theirs src/app.js   # take incoming version
git add src/app.js
git commit
```

## Q59. "How do I see what I'm about to push?"

**Answer:**

```bash
git fetch
git log origin/main..HEAD                  # commits on local that aren't on origin
git diff origin/main..HEAD                 # the diff
git push --dry-run                         # simulate the push
```

## Q60. Quick reference for the `gh` CLI?

**Answer:**

```bash
gh auth login
gh repo clone org/repo
gh pr create --title "Add login" --body "..."
gh pr list
gh pr checkout 42
gh pr view 42 --web
gh pr merge 42 --squash
gh issue list --assignee @me
gh run list                # CI runs
gh run watch
```

`gh` is GitHub's official CLI; it is a huge time saver for everyday workflows.

## Q61. What is a sensible Git checklist for a new project?

**Answer:**

- `.gitignore` for the language and editors
- `.gitattributes` enforcing LF
- Branch protection on `main`: require PR, require checks, require reviews
- Conventional commits or another standard
- Pre-commit hooks (lint, format, tests)
- Signed commits (optional, recommended)
- CI runs on every PR
- Squash or rebase merge enforced
- Stale branches deleted on merge
- Tag-based releases (SemVer)
- Secrets scanning enabled
