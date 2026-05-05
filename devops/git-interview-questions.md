# Git Interview Questions

**Level:** Mid to Senior
**Topics:** Internals, Branching, Merge/Rebase, Recovery, Workflows, Hooks, Large Repos

---

## Table of Contents

1. [Fundamentals](#fundamentals)
2. [Working Directory, Staging, Commits](#working-directory-staging-commits)
3. [Branches, Merge, Rebase](#branches-merge-rebase)
4. [Resetting, Reverting, Recovery](#resetting-reverting-recovery)
5. [Stash, Cherry-pick, Reflog](#stash-cherry-pick-reflog)
6. [Tags and Releases](#tags-and-releases)
7. [Remotes, Push, Pull](#remotes-push-pull)
8. [Workflows and Code Review](#workflows-and-code-review)
9. [Hooks, Submodules, LFS](#hooks-submodules-lfs)
10. [Worktrees, Bisect, Blame](#worktrees-bisect-blame)
11. [Configuration, Aliases, Performance](#configuration-aliases-performance)
12. [Common Scenarios](#common-scenarios)

---

## Fundamentals

### Q1. What is Git?

**Answer:**
A distributed version control system that tracks changes to files. Every clone is a full repository with complete history, enabling offline work and resilience. Git is content-addressable — objects are identified by SHA-1 (or SHA-256) hash of their content.

---

### Q2. Centralized vs distributed VCS?

| | Centralized (SVN, CVS) | Distributed (Git, Mercurial) |
|---|---|---|
| Server | Required for almost every op | Only for sync |
| Offline work | Limited | Full history available |
| Branching | Heavy | Cheap and fast |
| Merging | Often painful | First-class operation |
| Single point of failure | Yes | No |

---

### Q3. Git's three-tree model?

**Answer:**

| Tree | What it is |
|------|-----------|
| **Working directory** | Files you see and edit |
| **Staging area (index)** | Snapshot prepared for the next commit |
| **Repository (HEAD)** | Committed history |

```
working dir → (git add) → index → (git commit) → repository
```

---

### Q4. Git internals — object types?

| Object | Purpose |
|--------|---------|
| **blob** | File contents (no name) |
| **tree** | Directory listing — names → blobs/trees |
| **commit** | Snapshot pointer (tree + parent(s) + message + author) |
| **tag** | Annotated tag — points to a commit |

Stored under `.git/objects/`. Refs (branches, tags) are pointers in `.git/refs/`.

---

### Q5. What does a commit contain?

```
tree    a1b2c3...           # snapshot
parent  d4e5f6...           # previous commit (or none for root)
author  Alice <a@x.com> 1700000000 +0000
committer Alice <a@x.com> 1700000000 +0000

Commit message
```

Commits are immutable — changing a parent rewrites the SHA. This is why "amend" and "rebase" produce new commit hashes.

---

### Q6. HEAD, main, origin — what do they refer to?

**Answer:**
- **HEAD** — current commit (usually via the current branch).
- **main**/**master** — local branch.
- **origin** — default name for the remote.
- **origin/main** — local cache of the remote's main, updated by `fetch`.

---

## Working Directory, Staging, Commits

### Q7. Status and diff?

```bash
git status                  # what's changed and staged
git status -s               # short
git diff                    # unstaged changes
git diff --staged           # staged changes
git diff main..feature      # commits on feature not in main
git diff main...feature     # changes on feature since branched from main
git diff --stat             # summary
```

---

### Q8. Staging granularly?

```bash
git add file
git add .                       # all in current dir
git add -A                      # all in repo (including deletes)
git add -p                      # interactive — pick hunks
git restore --staged file       # unstage
git restore file                # discard working changes (DESTRUCTIVE)
```

`git add -p` is invaluable for splitting large changes into focused commits.

---

### Q9. Commit message conventions?

**Conventional Commits:**
```
type(scope)!: short summary

body explaining the change

BREAKING CHANGE: details
Refs: #123
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`. The `!` indicates breaking change.

```
feat(auth): support TOTP MFA

Adds time-based one-time passwords using RFC 6238.
Stores encrypted secret per user. Falls back to SMS.

BREAKING CHANGE: /login response shape changed.
Refs: SEC-421
```

Why it matters: enables semantic-release, auto-changelog, and easier history navigation.

---

### Q10. Amend a commit?

```bash
git commit --amend                       # edit last commit's content/message
git commit --amend --no-edit             # add staged changes silently
git commit --amend -m "new message"
```

Don't amend pushed commits unless you own the branch and coordinate.

---

## Branches, Merge, Rebase

### Q11. Branch operations?

```bash
git branch                          # list local
git branch -a                       # all (remote-tracking)
git branch -vv                      # show tracking + last commit
git switch -c feature               # create + switch
git switch main                     # switch (modern, replaces checkout for branches)
git branch -d feature               # delete (safe — refuses unmerged)
git branch -D feature               # force delete
git branch -m old new               # rename
```

---

### Q12. Fast-forward vs three-way merge?

**Answer:**

- **Fast-forward** — `main` has no new commits since `feature` branched. Git just moves the `main` pointer to `feature`'s tip. No merge commit.
- **Three-way merge** — both branches have diverged. Git computes a merge using the common ancestor and creates a merge commit with two parents.

```bash
git merge --ff-only feature        # fail if not fast-forwardable
git merge --no-ff feature          # always create a merge commit
git merge feature                  # default: ff if possible, else 3-way
```

`--no-ff` preserves the fact that a feature branch existed.

---

### Q13. Merge vs rebase — deep dive?

| | Merge | Rebase |
|---|---|---|
| History shape | Non-linear, with merge commits | Linear |
| Commits preserved? | Yes, plus merge commit | Replayed (new SHAs) |
| Conflicts resolved | Once | Once per commit (potentially) |
| Safe on shared branches | Yes | No (rewrites history) |
| Easier to revert | Yes (`git revert -m 1`) | Each commit individually |
| Better for | Long-lived branches, releases | Feature branches before merge |

```bash
# rebase feature onto main
git switch feature
git fetch origin
git rebase origin/main

# resolve conflicts
git add .
git rebase --continue
# or
git rebase --abort
```

**Golden rule:** never rebase commits that have been pushed and others may have pulled.

---

### Q14. What is interactive rebase?

```bash
git rebase -i HEAD~5
```

Lets you reorder, squash, fixup, edit, drop, or reword commits.

```
pick   abc123 feat(api): add user endpoint
squash def456 add tests
fixup  ghi789 fix typo
reword jkl012 refactor service
drop   mno345 debug logging
```

| Action | Effect |
|--------|--------|
| pick | Keep |
| reword | Keep, edit message |
| edit | Pause to amend |
| squash | Combine with previous, edit messages |
| fixup | Combine, discard message |
| drop | Remove |

---

### Q15. Resolving merge conflicts?

```bash
git merge feature
# conflict in src/app.js
git status
git diff
# edit file, remove <<<<<<< ======= >>>>>>> markers
git add src/app.js
git commit                 # for merge — message pre-filled
# or for rebase
git rebase --continue
```

Tools:
```bash
git mergetool              # GUI tool (configured)
git checkout --ours file   # keep current branch version
git checkout --theirs file # keep incoming version
```

For rebase: "ours"/"theirs" are reversed compared to merge — careful.

---

### Q16. `git pull` vs `git fetch`?

**Answer:**
- `git fetch` — updates remote-tracking refs; doesn't touch working tree.
- `git pull` — `fetch` + `merge` (or `rebase`).

Configure:
```bash
git config --global pull.rebase true       # pull = fetch + rebase
git config --global pull.ff only           # only fast-forward, else fail
```

`pull.ff only` is safest — forces explicit merge/rebase decisions.

---

## Resetting, Reverting, Recovery

### Q17. `git reset` — soft, mixed, hard?

| Mode | HEAD moves | Index changes | Working tree changes |
|------|------------|---------------|----------------------|
| `--soft` | Yes | No | No |
| `--mixed` (default) | Yes | Yes | No |
| `--hard` | Yes | Yes | Yes (DESTRUCTIVE) |

```bash
git reset --soft HEAD~1     # undo commit, keep changes staged
git reset HEAD~1            # undo commit, unstage but keep edits
git reset --hard HEAD~1     # NUKE last commit and any local changes
```

`--hard` discards uncommitted work. Only use when you're sure.

---

### Q18. `git revert`?

```bash
git revert <sha>            # creates a new commit that undoes <sha>
git revert -m 1 <merge-sha> # revert a merge commit (1 = mainline parent)
git revert --no-commit <sha1> <sha2>
```

Safe on shared branches — adds a forward commit instead of rewriting history.

---

### Q19. Revert vs reset?

| | reset | revert |
|---|---|---|
| Rewrites history | Yes | No |
| Safe on pushed branches | No | Yes |
| Creates new commit | No | Yes |
| Use for | Local cleanup | Public history |

---

### Q20. Recover lost commits — reflog?

```bash
git reflog                            # all HEAD movements
git reflog show feature
git reset --hard HEAD@{2}             # jump to 2 movements ago
git checkout <sha-from-reflog>
git branch recover-feature <sha>
```

Reflog is local-only and time-bounded (default 90 days for reachable, 30 for unreachable). It's your safety net for `reset --hard`, bad rebases, deleted branches.

---

### Q21. `git restore` and `git switch`?

**Answer:**
Modern split of `git checkout`:
- `git switch` — change branches.
- `git restore` — restore files (working tree or index).

```bash
git switch main
git switch -c feature
git restore file              # discard unstaged changes
git restore --staged file     # unstage
git restore --source=HEAD~3 file
```

---

## Stash, Cherry-pick, Reflog

### Q22. Stash basics?

```bash
git stash                            # save tracked changes
git stash push -u -m "WIP fixing X"  # include untracked, with message
git stash list
git stash show -p stash@{0}
git stash pop                        # apply + drop
git stash apply stash@{1}            # apply, keep in stash
git stash drop stash@{0}
git stash branch wip stash@{0}       # create branch from stash
```

Use `git stash push -- <pathspec>` to stash specific files.

---

### Q23. Cherry-pick?

```bash
git cherry-pick <sha>
git cherry-pick <sha1> <sha2>
git cherry-pick A..B                 # range (exclusive A)
git cherry-pick -x <sha>             # records "cherry picked from"
git cherry-pick --continue / --abort
```

Use to backport fixes to release branches.

---

## Tags and Releases

### Q24. Lightweight vs annotated tags?

| | Lightweight | Annotated |
|---|---|---|
| Stored as | Just a ref | Full object (tagger, date, message, optional GPG) |
| Use for | Private bookmarks | Releases (recommended) |

```bash
git tag v1.0.0                                    # lightweight
git tag -a v1.0.0 -m "Release 1.0.0"              # annotated
git tag -s v1.0.0 -m "Release 1.0.0"              # signed (GPG)
git push origin v1.0.0
git push --tags                                   # push all tags
git tag -d v0.9.0                                 # delete locally
git push origin :refs/tags/v0.9.0                 # delete remote
```

---

### Q25. SemVer + tags?

**Answer:**
`MAJOR.MINOR.PATCH` — tag releases as `v1.4.2`. Tools like `semantic-release` automate this from Conventional Commits, generate changelog, publish, and tag.

---

## Remotes, Push, Pull

### Q26. Remote management?

```bash
git remote -v
git remote add origin git@github.com:org/repo.git
git remote add upstream git@github.com:upstream/repo.git
git remote rename origin gh
git remote set-url origin git@new-host:org/repo.git
git remote remove old
git fetch --all --prune                # also delete stale remote-tracking refs
```

---

### Q27. Fork workflow with `upstream`?

```bash
git remote add upstream git@github.com:upstream/repo.git
git fetch upstream
git switch main
git rebase upstream/main          # keep main in sync with upstream
git push origin main
```

---

### Q28. Push semantics?

```bash
git push                               # push current branch (with default config)
git push origin feature                # explicit
git push -u origin feature             # set upstream tracking
git push --tags
git push --delete origin old-feature
git push --force                       # DANGEROUS
git push --force-with-lease            # safer — fails if remote moved
```

---

### Q29. When NOT to force-push?

**Answer:**
- `main`/`master` and other shared branches.
- Release branches.
- Any branch others may have based work on.

If you must rewrite shared history: announce, then `--force-with-lease`. Even then, prefer `git revert` over force-push for shared branches.

---

### Q30. `--force` vs `--force-with-lease`?

**Answer:**
- `--force` — overwrites remote unconditionally; can clobber others' work.
- `--force-with-lease` — pushes only if remote ref matches what you last fetched; refuses if someone else pushed in the meantime.

Always prefer `--force-with-lease`.

---

## Workflows and Code Review

### Q31. Gitflow vs trunk-based?

| | Gitflow | Trunk-based |
|---|---|---|
| Branches | main, develop, feature/*, release/*, hotfix/* | main + short-lived feature branches |
| Release cadence | Slower, scheduled | Continuous |
| Complexity | High | Low |
| Best for | Versioned libraries, mobile apps | SaaS, continuous deployment |

Modern web/SaaS tends to favor trunk-based + feature flags + CI gating.

---

### Q32. Feature branching essentials?

1. Create from main: `git switch -c feat/payment`.
2. Commit early and often.
3. Keep branch short-lived (< 1 week ideally).
4. Rebase on main daily to avoid drift.
5. Open PR/MR; pass CI.
6. Squash or rebase-merge into main; delete branch.

---

### Q33. PR merge strategies?

| Strategy | History |
|----------|---------|
| **Merge commit** | Preserves all commits + merge commit |
| **Squash merge** | One commit on main; loses granular history but clean |
| **Rebase merge** | Linear history; replays commits onto main |

Pick one and stick with it. Many teams choose squash for clean main + branch history preserved in PR.

---

### Q34. Code review etiquette in git?

- One concern per PR; small (< ~400 lines preferred).
- Atomic commits with clear messages.
- Don't mix refactors with feature work.
- Address review comments via fixup commits, then `git rebase -i --autosquash` before merge.

```bash
git commit --fixup=<sha>
git rebase -i --autosquash main
```

---

## Hooks, Submodules, LFS

### Q35. Git hooks?

**Answer:**
Scripts in `.git/hooks/` triggered by Git events. Local (not pushed). Common ones:

| Hook | When |
|------|------|
| pre-commit | Before commit (lint, format) |
| commit-msg | Validate message |
| pre-push | Before push (run tests) |
| post-merge | After merge |
| pre-receive / post-receive | Server-side |

Use **Husky** (Node) or **pre-commit** (Python) to share hooks via the repo.

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

---

### Q36. Submodules?

```bash
git submodule add https://github.com/x/lib.git vendor/lib
git submodule update --init --recursive
git clone --recurse-submodules <url>
```

Pinned to a specific commit. Pros: clean separation. Cons: complex workflow, easy to forget to update.

---

### Q37. Submodules vs subtrees?

| | Submodule | Subtree |
|---|---|---|
| Storage | Pointer to external repo | Vendored copy |
| Clone overhead | Extra step | None |
| Updates | Explicit `submodule update` | `git subtree pull` |
| History | Separate | Merged in |
| Common pitfalls | Detached HEADs, forgotten updates | Larger repo, complex commands |

Many teams have moved to monorepo + workspaces (npm/yarn/pnpm) instead.

---

### Q38. `.gitignore`?

```gitignore
# Dependencies
node_modules/
vendor/

# Build
dist/
build/
*.o
*.class

# Env
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp

# OS
.DS_Store
Thumbs.db

# Logs
*.log
```

`.gitignore` only ignores untracked files. To stop tracking an already-committed file:
```bash
git rm --cached path/to/file
```

Global ignore: `git config --global core.excludesfile ~/.gitignore_global`.

---

### Q39. `.gitattributes`?

**Answer:**
Per-path attributes — line endings, diff handlers, merge strategies, LFS, export filters.

```gitattributes
* text=auto eol=lf
*.png binary
*.lock merge=ours
package-lock.json -diff
*.psd filter=lfs diff=lfs merge=lfs -text
```

`text=auto eol=lf` solves Windows/Unix line-ending headaches in mixed teams.

---

### Q40. Git LFS?

**Answer:**
Stores large binary files (designs, datasets, media) outside the main repo. Git only stores pointers; LFS server handles bytes.

```bash
git lfs install
git lfs track "*.psd"
git add .gitattributes
git add design.psd
git commit -m "feat: add design"
```

Without LFS, large binaries balloon the repo and slow every clone.

---

### Q41. Signed commits?

```bash
git config --global user.signingkey <KEYID>
git config --global commit.gpgsign true
git commit -S -m "..."
git log --show-signature
```

GitHub/GitLab show "Verified" badges. Modern alternatives: SSH signing (`gpg.format=ssh`), Sigstore (`gitsign`).

---

## Worktrees, Bisect, Blame

### Q42. Worktrees?

**Answer:**
Multiple checkouts from the same `.git` directory.

```bash
git worktree add ../repo-hotfix hotfix/critical
git worktree list
git worktree remove ../repo-hotfix
```

Useful for: working on a hotfix without stashing your feature work, running tests on another branch, parallel review.

---

### Q43. `git bisect`?

**Answer:**
Binary-search history to find the commit that introduced a bug.

```bash
git bisect start
git bisect bad                       # current HEAD is broken
git bisect good v1.4.0               # this version was fine
# Git checks out a commit in between; you test
git bisect bad / good
# repeat until git names the culprit
git bisect reset
```

Automate with a test script:
```bash
git bisect run npm test
```

---

### Q44. `git blame` and `git log -L`?

```bash
git blame file.js
git blame -L 10,20 file.js                # specific lines
git blame -w                              # ignore whitespace changes
git log -L 10,20:file.js                  # history of those lines
git log -S "functionName"                 # commits where occurrences changed
git log -G "regex"                        # commits whose diff matches regex
```

`-S` (pickaxe) is great for "when was X added/removed?".

---

### Q45. Useful log filters?

```bash
git log --oneline --graph --all --decorate
git log --since="2 weeks ago" --until="yesterday"
git log --author="alice"
git log --grep="bugfix"
git log -- path/to/file
git log --stat
git log --follow -- file              # follow renames
git shortlog -sn                      # author commit counts
```

---

## Configuration, Aliases, Performance

### Q46. Useful global config?

```bash
git config --global user.name  "Alice"
git config --global user.email "alice@example.com"
git config --global init.defaultBranch main
git config --global pull.ff only
git config --global push.default current
git config --global push.autoSetupRemote true
git config --global rebase.autoStash true
git config --global rerere.enabled true             # remember conflict resolutions
git config --global core.editor "code --wait"
git config --global diff.colorMoved zebra
```

---

### Q47. Useful aliases?

```bash
git config --global alias.s "status -s"
git config --global alias.co "checkout"
git config --global alias.br "branch"
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.last "log -1 HEAD --stat"
git config --global alias.unstage "reset HEAD --"
git config --global alias.amend "commit --amend --no-edit"
```

---

### Q48. Performance with large repos?

**Answer:**
- **Shallow clone** — `git clone --depth=1 <url>` for CI.
- **Partial clone** — `git clone --filter=blob:none <url>` (lazy fetch blobs).
- **Sparse checkout** — only check out a subset of paths:
  ```bash
  git sparse-checkout init --cone
  git sparse-checkout set apps/web libs/shared
  ```
- **Commit-graph** — `git config --global fetch.writeCommitGraph true`.
- **Background maintenance** — `git maintenance start` (auto gc/prefetch).
- **Scalar** — Microsoft's tool for very large repos.

---

### Q49. `git gc` and maintenance?

```bash
git gc                       # cleanup, pack objects
git gc --aggressive          # heavier optimization
git fsck                     # verify object integrity
git count-objects -v
git maintenance start        # schedules background tasks
```

---

### Q50. Monorepo considerations?

**Answer:**
- Use sparse-checkout to limit working set.
- Tooling: Nx, Turborepo, Bazel, Lerna for build orchestration.
- CI must compute affected projects (don't rebuild everything).
- CODEOWNERS for review routing.
- Hooks scoped per package.
- Be mindful of repo size — LFS for binaries; consider partial clone.

---

## Common Scenarios

### Q51. "I committed to the wrong branch."

```bash
# Last N commits
git log --oneline -5
git switch correct-branch
git cherry-pick <sha-from-wrong>
git switch wrong-branch
git reset --hard HEAD~1     # remove from wrong branch
```

---

### Q52. "I want to undo `git push`."

**Local change first**, then push:
```bash
git revert <sha>                          # safest — adds inverse commit
git push

# Or if you must rewrite (you own the branch and coordinated):
git reset --hard <previous-sha>
git push --force-with-lease
```

---

### Q53. "I committed a secret. How do I purge it?"

**Answer:**
1. Rotate the secret immediately — assume it's compromised.
2. Remove from history:
   ```bash
   git filter-repo --path config/secrets.yml --invert-paths
   # or use BFG Repo-Cleaner
   ```
3. Force-push (and notify everyone — all clones become invalid).
4. Add the file to `.gitignore`.
5. Audit logs for leak window.

`git filter-repo` is the recommended modern tool (replaces `filter-branch`).

---

### Q54. "I want to change the author of past commits."

```bash
git rebase -i <root>
# pick → edit; then:
git commit --amend --author="Alice <a@x.com>" --no-edit
git rebase --continue
# Or:
git filter-repo --commit-callback '...'
```

---

### Q55. "I want to split one commit into many."

```bash
git rebase -i HEAD~3
# mark target commit as 'edit'
git reset HEAD^                  # un-stage that commit's changes
git add -p                       # stage hunks for commit 1
git commit -m "first part"
git add -p
git commit -m "second part"
git rebase --continue
```

---

### Q56. "I want to combine the last 3 commits into one."

```bash
git rebase -i HEAD~3
# change last two from 'pick' to 'squash' (or 'fixup')
```

Or, on push:
```bash
git reset --soft HEAD~3
git commit -m "combined message"
```

---

### Q57. "I want to recover a deleted branch."

```bash
git reflog                       # find the SHA
git branch recovered <sha>
```

If the branch was on the remote but you deleted it locally:
```bash
git fetch
git switch -c recovered origin/recovered
```

---

### Q58. "Two people changed the same line."

```bash
git pull --rebase
# conflict — manually resolve
git add <file>
git rebase --continue
```

Or merge:
```bash
git pull
# resolve, commit (or use ours/theirs as decided with the team).
```

For repeated identical conflicts (e.g., long-running rebase), enable `rerere`:
```bash
git config --global rerere.enabled true
```

---

### Q59. "How do I see what I'm about to push?"

```bash
git log @{u}..HEAD                # commits ahead of upstream
git diff @{u}..HEAD               # full diff
git status                        # shows ahead/behind
```

---

### Q60. `gh` CLI quick reference?

```bash
gh auth login
gh repo clone org/repo
gh pr create --fill --base main
gh pr list
gh pr checkout 42
gh pr review --approve
gh pr merge 42 --squash --delete-branch
gh issue list --label bug
gh run watch
gh workflow run deploy.yml -f env=staging
```

`gh` is great for scripting and CI — handles auth and API in one tool.

---

### Q61. Senior-level git checklist?

- [ ] Configure `pull.ff only` and `push.autoSetupRemote`.
- [ ] Conventional Commits enforced via commit-msg hook.
- [ ] `.gitignore` and `.gitattributes` curated.
- [ ] Pre-commit hooks for lint/format/secret scanning (gitleaks, trufflehog).
- [ ] Signed commits where required (GPG/SSH/Sigstore).
- [ ] Branch protection: required reviews, status checks, no force-push to main.
- [ ] CODEOWNERS for review routing.
- [ ] Strategy chosen (squash/rebase/merge) and applied consistently.
- [ ] LFS configured for binaries.
- [ ] Reflog awareness — recover, don't fear `reset --hard` locally.
- [ ] Rerere enabled for repetitive conflicts.
- [ ] CI uses shallow / partial clone for speed where possible.
