# CI/CD and GitHub Actions Interview Questions

**Level:** Mid to Senior
**Topics:** CI/CD Concepts, GitHub Actions, Pipelines, Security (OIDC), Caching, Matrix, Reusable Workflows, Deployment Strategies

---

## Table of Contents

1. [CI/CD Fundamentals](#cicd-fundamentals)
2. [GitHub Actions Architecture](#github-actions-architecture)
3. [Workflow YAML Essentials](#workflow-yaml-essentials)
4. [Triggers](#triggers)
5. [Matrix and Parallelism](#matrix-and-parallelism)
6. [Caching and Artifacts](#caching-and-artifacts)
7. [Reusable Workflows and Composite Actions](#reusable-workflows-and-composite-actions)
8. [Secrets, Environments, and OIDC](#secrets-environments-and-oidc)
9. [Self-Hosted Runners](#self-hosted-runners)
10. [Build, Test, Deploy Patterns](#build-test-deploy-patterns)
11. [Container Builds in CI](#container-builds-in-ci)
12. [Deployment Strategies](#deployment-strategies)
13. [Comparison with Other CI Systems](#comparison-with-other-ci-systems)
14. [Troubleshooting and Best Practices](#troubleshooting-and-best-practices)

---

## CI/CD Fundamentals

### Q1. CI vs CD vs Continuous Deployment?

**Answer:**

| Term | Meaning |
|------|---------|
| **Continuous Integration (CI)** | Developers merge to a shared branch frequently; each merge triggers automated build + tests. |
| **Continuous Delivery (CD)** | Every change that passes CI is deployable; deployment is a manual button. |
| **Continuous Deployment** | Every passing change is automatically deployed to production. |

CI gives fast feedback. CD reduces release risk. Continuous Deployment maximizes velocity.

---

### Q2. Why CI/CD?

**Answer:**
- Catch bugs early (cheaper to fix).
- Smaller, frequent releases reduce risk.
- Repeatable builds — the pipeline is the source of truth.
- Faster feedback to developers.
- Auditable history of what shipped, when, by whom.
- Enables trunk-based development with confidence.

---

### Q3. What is a pipeline?

**Answer:**
A series of automated stages a code change passes through — typically lint → test → build → security scan → deploy. Pipelines are defined as code (YAML), versioned with the project, and reproducible.

---

### Q4. Pipeline anti-patterns?

- Long, slow pipelines (>15 min) — developers context-switch and lose flow.
- Flaky tests left unchecked — eroded trust → ignored failures.
- Secrets in plaintext logs.
- Manual steps in deployment ("just SSH in and run X").
- One giant job — no parallelism, hard to debug.
- No environment parity (dev passes, prod breaks).
- No rollback strategy.

---

## GitHub Actions Architecture

### Q5. Core concepts?

| Concept | Description |
|---------|-------------|
| **Workflow** | YAML file under `.github/workflows/`; contains jobs. |
| **Job** | A unit that runs on a runner; has steps. |
| **Step** | Single command or action invocation. |
| **Action** | Reusable unit (Docker, JavaScript, or composite). |
| **Runner** | Machine that executes the job (GitHub-hosted or self-hosted). |
| **Event** | Trigger (push, PR, schedule, manual, etc.). |

---

### Q6. Skeleton workflow?

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm test
```

---

### Q7. Job dependencies?

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps: [...]

  test:
    runs-on: ubuntu-latest
    needs: lint
    steps: [...]

  deploy:
    runs-on: ubuntu-latest
    needs: [lint, test]
    if: github.ref == 'refs/heads/main'
    steps: [...]
```

By default, jobs run in parallel. `needs:` enforces order. `if:` adds conditions.

---

## Workflow YAML Essentials

### Q8. Expressions and contexts?

```yaml
- if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  run: echo "deploy"

- run: echo "PR #${{ github.event.pull_request.number }}"
- run: echo "Actor: ${{ github.actor }}"
- run: echo "Commit: ${{ github.sha }}"
```

Common contexts: `github`, `env`, `secrets`, `vars`, `inputs`, `needs`, `matrix`, `runner`, `job`, `steps`.

---

### Q9. Setting environment variables and outputs?

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    env:
      NODE_ENV: production
    outputs:
      version: ${{ steps.meta.outputs.version }}
    steps:
      - id: meta
        run: echo "version=1.2.3" >> "$GITHUB_OUTPUT"

      - run: echo "FOO=bar" >> "$GITHUB_ENV"     # available to later steps

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - run: echo "deploying ${{ needs.build.outputs.version }}"
```

`set-output` and `set-env` echo commands were deprecated; use `$GITHUB_OUTPUT` and `$GITHUB_ENV` files.

---

### Q10. Conditional steps and `continue-on-error`?

```yaml
- name: Lint
  run: npm run lint
  continue-on-error: true       # don't fail the job

- name: Notify on failure
  if: failure()
  run: ./notify.sh

- name: Always run cleanup
  if: always()
  run: rm -rf /tmp/build
```

Status functions: `success()`, `failure()`, `cancelled()`, `always()`.

---

## Triggers

### Q11. Common triggers?

```yaml
on:
  push:
    branches: [main, 'release/**']
    tags: ['v*']
    paths-ignore: ['**.md', 'docs/**']

  pull_request:
    types: [opened, synchronize, reopened]
    branches: [main]

  schedule:
    - cron: '0 2 * * *'        # daily 02:00 UTC

  workflow_dispatch:
    inputs:
      env:
        type: choice
        options: [staging, production]
        default: staging

  repository_dispatch:
    types: [deploy-trigger]

  workflow_run:
    workflows: ['CI']
    types: [completed]
```

---

### Q12. `pull_request` vs `pull_request_target`?

**Answer:**

| | pull_request | pull_request_target |
|---|---|---|
| Code checked out | PR head (untrusted) | Base branch (trusted) |
| Secrets available | Limited (none for forks) | Full |
| Use case | CI on PR code | Adding labels, auto-merge from forks |
| Risk | Low | High — can leak secrets if you check out PR code |

**Never** check out untrusted PR code in `pull_request_target` and run scripts from it. That's a common supply-chain attack vector.

---

### Q13. Concurrency control?

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Cancels older runs of the same workflow + ref. For deploys, prefer queueing without cancellation:

```yaml
concurrency:
  group: deploy-prod
  cancel-in-progress: false
```

---

## Matrix and Parallelism

### Q14. Matrix strategy?

```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node: [18, 20, 22]
        include:
          - os: ubuntu-latest
            node: 22
            coverage: true
        exclude:
          - os: windows-latest
            node: 18
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '${{ matrix.node }}' }
      - run: npm test
```

- `fail-fast: false` — let other matrix jobs continue even if one fails.
- `include` / `exclude` — fine-tune combinations.

---

### Q15. Sharding tests?

```yaml
strategy:
  matrix:
    shard: [1, 2, 3, 4]
steps:
  - run: npx jest --shard=${{ matrix.shard }}/4
```

Splits the suite four ways across runners — quartering wall-clock time.

---

## Caching and Artifacts

### Q16. Caching dependencies?

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'                     # built-in cache for package managers
    cache-dependency-path: package-lock.json
```

Manual cache:
```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.npm
      .next/cache
    key: ${{ runner.os }}-build-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-build-
```

`hashFiles` produces a stable key when lockfile is unchanged; `restore-keys` falls back to a partial match.

---

### Q17. Cache scoping rules?

**Answer:**
- Caches are scoped to a branch.
- Branches can read the default branch's cache (one-way).
- Cache is evicted after 7 days of inactivity.
- 10 GB limit per repo.
- Don't cache mutable directories (`node_modules` directly) — cache the package manager's store and reinstall.

---

### Q18. Artifacts vs caches?

| | Cache | Artifact |
|---|---|---|
| Purpose | Speed up builds (deps) | Pass files between jobs / publish |
| TTL | 7 days, 10 GB | 90 days (configurable) |
| Cross-workflow | Yes (with limits) | No |
| API | actions/cache | actions/upload-artifact |

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: dist
    path: dist/
    retention-days: 7

- uses: actions/download-artifact@v4
  with:
    name: dist
    path: dist/
```

---

## Reusable Workflows and Composite Actions

### Q19. Reusable workflow?

```yaml
# .github/workflows/build.yml
on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '20'
    secrets:
      NPM_TOKEN:
        required: true
    outputs:
      artifact:
        value: ${{ jobs.build.outputs.artifact }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      artifact: dist
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '${{ inputs.node-version }}' }
      - run: npm ci
        env: { NODE_AUTH_TOKEN: '${{ secrets.NPM_TOKEN }}' }
      - run: npm run build
```

Caller:
```yaml
jobs:
  ci:
    uses: ./.github/workflows/build.yml
    with:
      node-version: '22'
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

---

### Q20. Composite action?

```yaml
# .github/actions/setup/action.yml
name: 'Setup project'
inputs:
  node-version:
    default: '20'
runs:
  using: 'composite'
  steps:
    - uses: actions/setup-node@v4
      with: { node-version: '${{ inputs.node-version }}' }
    - run: npm ci
      shell: bash
```

```yaml
- uses: ./.github/actions/setup
  with: { node-version: '22' }
```

---

### Q21. Reusable workflow vs composite action?

| | Reusable workflow | Composite action |
|---|---|---|
| Granularity | Whole jobs | Steps within a job |
| Runs on | Its own runner(s) | Caller's runner |
| Secrets | Explicit pass-through | Inherits caller's |
| Matrix | Supported | Not directly |
| Use case | Whole pipelines (build, test, deploy) | DRY step sequences |

---

### Q22. Custom action types?

| Type | Implementation |
|------|----------------|
| **JavaScript** | Node.js code; fastest startup |
| **Docker** | Container image; full env control; Linux-only on hosted runners |
| **Composite** | YAML steps; no extra deps |

---

## Secrets, Environments, and OIDC

### Q23. Secrets handling?

**Answer:**
- Define at repo, environment, or org level.
- Reference: `${{ secrets.NAME }}`.
- Masked in logs (but not when transformed — e.g., base64).
- Not available to workflows triggered by PRs from forks.
- Rotate regularly.

```yaml
- run: deploy.sh
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

---

### Q24. Environments and approvals?

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://app.example.com
    steps:
      - run: ./deploy.sh
```

Configure in repo Settings → Environments:
- Required reviewers (manual approval gate).
- Wait timer.
- Branch restrictions (e.g., only `main` deploys to production).
- Environment-scoped secrets and variables.

---

### Q25. OIDC for cloud authentication?

**Answer:**
GitHub Actions can issue an OIDC token that AWS/Azure/GCP exchange for short-lived credentials — eliminating long-lived static keys.

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/GitHubDeployRole
      aws-region: us-east-1

  - run: aws s3 sync ./dist s3://my-bucket
```

The IAM role's trust policy validates `token.actions.githubusercontent.com` and limits to specific repo/branch/environment claims:

```json
"Condition": {
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:org/repo:environment:production"
  }
}
```

---

### Q26. Why OIDC over static credentials?

- No secrets to rotate.
- Tokens are short-lived (minutes).
- Scoped to a specific workflow run.
- Conditioned on branch/environment.
- Auditable in cloud's IAM logs.

---

### Q27. `permissions:` and the `GITHUB_TOKEN`?

```yaml
permissions:
  contents: read
  pull-requests: write
  id-token: write
```

Default permissions are configurable at org/repo level. Principle of least privilege — grant only what the workflow needs.

---

### Q28. Reviewing third-party actions?

**Answer:**
1. Pin to a full commit SHA (not a tag — tags are mutable):
   ```yaml
   uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11   # v4.1.1
   ```
2. Audit the action's source.
3. Prefer official `actions/*` and major vendors.
4. Use Dependabot to keep them current:
   ```yaml
   # .github/dependabot.yml
   version: 2
   updates:
     - package-ecosystem: "github-actions"
       directory: "/"
       schedule: { interval: "weekly" }
   ```
5. Restrict allowed actions at org level (Settings → Actions).

---

### Q29. Branch protection rules?

**Answer:**
- Require status checks to pass before merge.
- Require PR reviews (1+, code owners).
- Require linear history.
- Require signed commits.
- Restrict who can push to protected branches.
- Require up-to-date branches before merging.

Combined with environment protection rules, these are the foundation of safe CD.

---

## Self-Hosted Runners

### Q30. Hosted vs self-hosted runners?

| | GitHub-hosted | Self-hosted |
|---|---|---|
| Setup | Zero | Install runner agent |
| Cost | Per-minute (free tier varies) | Your infra |
| Customization | Limited | Full |
| Secrets isolation | Strong (ephemeral VMs) | Your responsibility |
| Use cases | Most projects | Special hardware (GPU, ARM), private network access, larger machines |

---

### Q31. Securing self-hosted runners?

- **Never** use self-hosted runners for public repos with PRs from forks — attackers can run arbitrary code on them.
- Use **ephemeral runners** (one-job lifetime) — `--ephemeral` flag.
- Run runners in isolated networks/VPCs.
- Run as least-privileged user.
- Patch OS regularly.
- Use Actions Runner Controller (ARC) on Kubernetes for autoscaling.

---

## Build, Test, Deploy Patterns

### Q32. Standard CI pipeline?

```yaml
name: CI
on:
  push: { branches: [main] }
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env: { POSTGRES_PASSWORD: test }
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci
      - run: npm test
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/test

  build:
    needs: [lint, test]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with: { name: dist, path: dist/ }
```

---

### Q33. Service containers?

**Answer:**
Sidecar containers attached to a job (databases, caches, queues for integration tests). Available via `localhost` inside the job (or by service name when the job runs in a container).

```yaml
services:
  redis:
    image: redis:7-alpine
    ports: ['6379:6379']
```

---

### Q34. Monorepo CI patterns?

**Answer:**
- **Path filtering** — only run jobs when relevant paths change:
  ```yaml
  on:
    push:
      paths: ['apps/web/**', '.github/workflows/web.yml']
  ```
- **Affected detection** — Nx, Turborepo, or Bazel compute changed projects.
- **Reusable workflows** per project, dispatched from a top-level orchestrator.
- **Cache** package manager stores per workspace.
- **Parallel matrix** of affected projects.

```yaml
- name: Detect affected
  id: affected
  run: |
    apps=$(npx nx show projects --affected --base=origin/main --json)
    echo "apps=$apps" >> "$GITHUB_OUTPUT"

- name: Run tests
  if: steps.affected.outputs.apps != '[]'
  run: npx nx run-many --target=test --projects=${{ steps.affected.outputs.apps }}
```

---

### Q35. Semantic versioning automation?

```yaml
release:
  needs: build
  runs-on: ubuntu-latest
  permissions:
    contents: write
    issues: write
    pull-requests: write
  steps:
    - uses: actions/checkout@v4
      with: { fetch-depth: 0 }
    - uses: actions/setup-node@v4
      with: { node-version: '20', cache: 'npm' }
    - run: npm ci
    - run: npx semantic-release
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

`semantic-release` reads Conventional Commits, bumps versions, generates changelog, tags, and publishes.

---

## Container Builds in CI

### Q36. Building and pushing to GHCR?

```yaml
build-image:
  runs-on: ubuntu-latest
  permissions:
    contents: read
    packages: write
  steps:
    - uses: actions/checkout@v4

    - uses: docker/setup-qemu-action@v3
    - uses: docker/setup-buildx-action@v3

    - uses: docker/login-action@v3
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - id: meta
      uses: docker/metadata-action@v5
      with:
        images: ghcr.io/${{ github.repository }}
        tags: |
          type=sha
          type=ref,event=branch
          type=semver,pattern={{version}}

    - uses: docker/build-push-action@v5
      with:
        context: .
        platforms: linux/amd64,linux/arm64
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
```

`type=gha` uses GitHub's caching backend for BuildKit — fast layer reuse across runs.

---

### Q37. Pushing to AWS ECR with OIDC?

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: actions/checkout@v4
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/GitHubECRPush
      aws-region: us-east-1
  - uses: aws-actions/amazon-ecr-login@v2
    id: ecr
  - uses: docker/build-push-action@v5
    with:
      push: true
      tags: ${{ steps.ecr.outputs.registry }}/myapp:${{ github.sha }}
```

---

### Q38. Image scanning in CI?

```yaml
- uses: aquasecurity/trivy-action@master
  with:
    image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
    format: sarif
    output: trivy.sarif
    severity: 'CRITICAL,HIGH'
    exit-code: '1'

- uses: github/codeql-action/upload-sarif@v3
  if: always()
  with:
    sarif_file: trivy.sarif
```

Fails the build on CRITICAL/HIGH CVEs and surfaces results in GitHub's Security tab.

---

## Deployment Strategies

### Q39. Rolling, blue-green, canary?

| Strategy | How | Pros | Cons |
|----------|-----|------|------|
| **Rolling** | Replace pods/instances incrementally | Built-in (k8s, ECS), no extra cost | Mixed versions during deploy; long rollback |
| **Blue-green** | Two stacks; switch traffic at the LB | Instant rollback; clean test | 2x cost during deploy |
| **Canary** | Send small % to new version; ramp up | Real-world validation; gradual | Complex routing, monitoring |
| **Recreate** | Stop all, start new | Simple | Downtime |

---

### Q40. Canary deploy in GitHub Actions?

```yaml
deploy-canary:
  runs-on: ubuntu-latest
  environment: production
  steps:
    - run: ./deploy.sh --weight 10

run-smoke-tests:
  needs: deploy-canary
  runs-on: ubuntu-latest
  steps: [...]

promote:
  needs: run-smoke-tests
  runs-on: ubuntu-latest
  steps:
    - run: ./deploy.sh --weight 100

rollback:
  if: failure()
  needs: run-smoke-tests
  runs-on: ubuntu-latest
  steps:
    - run: ./deploy.sh --weight 0 --rollback
```

---

### Q41. Rollback strategies?

**Answer:**
- **Re-deploy previous artifact** — pin every release to an immutable build (image digest).
- **Database migrations** — design forward-compatible (expand → migrate → contract). Avoid breaking changes in a single release.
- **Feature flags** — flip features off without redeploy.
- **Traffic rollback** — revert weight in canary/blue-green.
- **Auto-rollback** — wire SLO/error-rate monitoring (Prometheus alert → workflow_dispatch rollback).

---

### Q42. Feature flags integration?

**Answer:**
Decouple deploy from release. Ship code dark, flip flags via LaunchDarkly, Unleash, Flagsmith, or Split.

```yaml
deploy:
  steps:
    - run: ./deploy.sh
- run: curl -X POST $LD_API/flags/$FEATURE -d '{"enabled":true}'
```

Allows gradual rollout, per-tenant targeting, instant kill switch.

---

### Q43. Deploying to Kubernetes?

```yaml
- uses: azure/setup-kubectl@v4
- run: |
    kubectl set image deployment/app \
      app=ghcr.io/${{ github.repository }}:${{ github.sha }} \
      --record
    kubectl rollout status deployment/app --timeout=2m
```

For declarative deploys: GitOps with ArgoCD or Flux — CI builds and pushes images; the GitOps controller reconciles cluster state from a manifest repo.

---

## Comparison with Other CI Systems

### Q44. GitHub Actions vs GitLab CI vs Jenkins vs CircleCI vs Azure DevOps?

| Aspect | GitHub Actions | GitLab CI | Jenkins | CircleCI | Azure DevOps |
|--------|----------------|-----------|---------|----------|--------------|
| Hosting | SaaS + self-hosted | SaaS + self-managed | Self-hosted (mostly) | SaaS + self-hosted | SaaS + self-hosted |
| Config | YAML in repo | YAML in repo | Groovy (Jenkinsfile) | YAML in repo | YAML in repo |
| Marketplace | Huge | Built-in templates | Plugins | Orbs | Tasks |
| Tight VCS integration | GitHub | GitLab | Any | Any | Azure Repos / GitHub |
| Secrets | Native + OIDC | Native + OIDC | Plugins | Native + OIDC | Native + OIDC |
| Best for | GitHub repos, OSS | Self-managed GitLab | Legacy enterprise, custom needs | JS/JVM-heavy teams | Microsoft stack |

Modern teams on GitHub overwhelmingly use Actions; GitLab teams use GitLab CI. Jenkins remains common in regulated/legacy environments.

---

### Q45. Migrating from Jenkins to GitHub Actions?

**Common pain points:**
- Jenkinsfile (Groovy) → YAML (declarative).
- Shared libraries → composite/reusable actions.
- Plugins → marketplace actions or shell scripts.
- Master-agent model → GitHub-hosted or self-hosted runners.
- Long-running pipelines → chunked into parallel jobs.

---

## Troubleshooting and Best Practices

### Q46. Flaky CI — how to fix?

**Answer:**
1. **Quarantine** flaky tests; track in an issue.
2. **Identify causes**:
   - Race conditions in parallel tests.
   - Time/date dependencies.
   - External services (mock or use `services:`).
   - Order-dependent tests (randomize order).
   - Resource contention on shared runners.
3. **Retry** transient operations (network) — never retry to mask logic bugs.
4. **Pin versions** (Node, system deps) to reduce drift.
5. Use `ts/test-retry-action` only as a stopgap.
6. Track flake rate as a metric; it's tech debt.

---

### Q47. Debugging a failing workflow?

```yaml
- name: Debug
  run: |
    echo "::group::env"
    env | sort
    echo "::endgroup::"
    echo "::group::context"
    echo '${{ toJSON(github) }}'
    echo "::endgroup::"

# Re-run with debug logs
# Set repo secret ACTIONS_RUNNER_DEBUG=true and ACTIONS_STEP_DEBUG=true
```

`act` can run Actions locally for fast iteration: `act -j build`.

For interactive debugging: `mxschmitt/action-tmate` opens an SSH session into the runner (use cautiously, never on protected branches with secrets).

---

### Q48. Speeding up pipelines?

1. **Cache** — package managers, build artifacts, Docker layers.
2. **Parallelize** — split jobs, shard tests.
3. **Skip on no-op paths** — `paths-ignore`, monorepo affected detection.
4. **Concurrency cancellation** — drop superseded runs.
5. **Smaller images / shallow clones** for runner setup.
6. **Larger runners** — paid tier; 8/16 vCPU cuts CPU-bound jobs.
7. **Avoid setup steps repeated across jobs** — build once, reuse via artifacts.
8. **Pre-warm self-hosted runners** with deps already installed.

---

### Q49. Monitoring CI metrics?

**Track:**
- Pipeline duration (P50/P95).
- Failure rate per workflow.
- Flake rate per test.
- Mean time to recovery (MTTR) on red main.
- Deploy frequency, lead time for changes (DORA).

GitHub provides workflow run history; export via `gh run list --json` or third-party (Allstar, CircleCI Insights-style dashboards).

---

### Q50. Deployment runbook essentials?

- Pipeline visible to all engineers.
- Clear ownership per environment.
- Pre-merge: lint, test, build, scan.
- Pre-deploy: integration tests on staging.
- Deploy: gated on environment approval (production).
- Post-deploy: smoke tests, synthetic checks, error/latency monitors.
- Rollback procedure documented and rehearsed.
- Incident communication channel.

---

### Q51. Common GitHub Actions pitfalls?

1. Using mutable tags (`@v4`) instead of SHAs for third-party actions.
2. `pull_request_target` with checkout of PR code (RCE risk).
3. Echoing secrets via base64 or after string transforms (unmasked).
4. Running `npm install` instead of `npm ci` (non-reproducible).
5. Storing build state in `node_modules` cache (corruption — cache the package store).
6. Forgetting `permissions:` (default may be too broad).
7. No concurrency control — old PR runs queue up.
8. Single huge workflow — slow to debug; split into focused jobs.
9. Long-lived AWS keys instead of OIDC.
10. Self-hosted runners exposed to fork PRs.
11. Not pinning `ubuntu-latest` for reproducibility (tag changes underneath you).
12. No artifact retention strategy — runs out of space, history lost.

---

### Q52. Senior-level CI/CD checklist?

- [ ] Pipeline as code, versioned with project.
- [ ] All third-party actions pinned to SHAs; Dependabot updates them.
- [ ] OIDC for cloud auth — no long-lived secrets.
- [ ] Environments with required reviewers for prod.
- [ ] Branch protection: required checks, PR reviews, signed commits.
- [ ] Concurrency control on workflows.
- [ ] Caching configured for fast builds.
- [ ] Reusable workflows / composite actions for DRY.
- [ ] Container images built with BuildKit + cache + multi-arch.
- [ ] Image scanning gates merges.
- [ ] Deployment strategy chosen (rolling/blue-green/canary) with automated rollback.
- [ ] Feature flags for risky changes.
- [ ] Pipeline metrics tracked (DORA).
- [ ] Runbooks for incidents and rollback.
- [ ] Self-hosted runners (if any) ephemeral, isolated, never running fork PRs.
- [ ] Secret scanning enabled (push protection).
