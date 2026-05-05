# CI/CD and GitHub Actions Interview Questions

A practical, teaching-style Q&A guide for CI/CD with a focus on GitHub Actions. Each question gives a plain-language explanation followed by a working YAML workflow example.

---

## Table of Contents

1. CI/CD Fundamentals
2. GitHub Actions Architecture
3. Workflow YAML Essentials
4. Triggers
5. Matrix and Parallelism
6. Caching and Artifacts
7. Reusable Workflows and Composite Actions
8. Secrets, Environments, and OIDC
9. Self-Hosted Runners
10. Build, Test, Deploy Patterns
11. Container Builds in CI
12. Deployment Strategies
13. Comparison with Other CI Systems
14. Troubleshooting and Best Practices

---

## 1. CI/CD Fundamentals

## Q1. What is the difference between CI, CD, and Continuous Deployment?

**Answer:**

- **Continuous Integration (CI)** means every change is automatically built and tested as soon as it is pushed. The goal is to catch problems early.
- **Continuous Delivery (CD)** means every change that passes CI is automatically packaged and made ready to deploy. A human still clicks "deploy."
- **Continuous Deployment** goes one step further: every change that passes is automatically deployed to production with no human in the loop.

| Term                  | Auto-test? | Auto-package? | Auto-deploy?      |
| --------------------- | ---------- | ------------- | ----------------- |
| CI                    | Yes        | No            | No                |
| Continuous Delivery   | Yes        | Yes           | No (manual click) |
| Continuous Deployment | Yes        | Yes           | Yes               |

## Q2. Why CI/CD?

**Answer:**

1. **Catch bugs early** — failures show up on every commit, not at release time.
2. **Faster releases** — automated pipelines remove manual toil.
3. **Confidence** — passing tests on every PR makes refactors safe.
4. **Audit trail** — every build, test, and deploy is logged.
5. **Consistency** — the same pipeline runs in dev and prod, so "works on my machine" disappears.

## Q3. What is a pipeline?

**Answer:**

A pipeline is the sequence of stages a change goes through from commit to production. A typical pipeline:

```text
Lint -> Build -> Unit tests -> Integration tests -> Security scan -> Package -> Deploy staging -> Smoke tests -> Deploy production
```

Each stage either passes or stops the pipeline. Pipelines can run stages in parallel where there are no dependencies.

## Q4. What are common pipeline anti-patterns?

**Answer:**

1. **Slow pipelines** — devs stop trusting CI when it takes 40 minutes.
2. **Flaky tests** — random failures train people to "click retry."
3. **Manual deploys after CI** — defeats the purpose of automation.
4. **Long-lived secrets** — long-lived cloud credentials are a security risk; use OIDC.
5. **No environments** — pushing straight to prod with no staging.
6. **No rollback plan** — when prod breaks, panic.
7. **Building on every push to every branch** — wastes minutes; use path filters and concurrency control.

---

## 2. GitHub Actions Architecture

## Q5. What are the core concepts in GitHub Actions?

**Answer:**

| Concept    | Meaning                                                                |
| ---------- | ---------------------------------------------------------------------- |
| Workflow   | A YAML file in `.github/workflows/` that defines automation            |
| Event      | What triggers the workflow (push, PR, schedule, manual, etc.)          |
| Job        | A set of steps that run on the same runner                             |
| Step       | A single command or "action" within a job                              |
| Action     | A reusable unit of code (e.g., `actions/checkout`)                     |
| Runner     | The machine that executes the job (GitHub-hosted or self-hosted)       |

## Q6. Show me a skeleton workflow.

**Answer:**

```yaml
# .github/workflows/ci.yml
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
          node-version: 20
          cache: npm

      - run: npm ci
      - run: npm test
```

This runs on every push to `main` and on every PR. It checks out the code, sets up Node 20, installs dependencies, and runs tests.

## Q7. How do job dependencies work?

**Answer:**

Use `needs:` to make one job wait for another. Without `needs`, jobs run in parallel.

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test

  deploy:
    needs: [lint, test]            # only run if both pass
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
```

---

## 3. Workflow YAML Essentials

## Q8. What are expressions and contexts?

**Answer:**

Expressions in `${{ ... }}` evaluate at runtime. Contexts are objects you can read from inside expressions.

| Context        | Examples                                                  |
| -------------- | --------------------------------------------------------- |
| `github`       | `github.actor`, `github.ref`, `github.event_name`         |
| `env`          | environment variables                                     |
| `secrets`      | `secrets.AWS_ROLE_ARN`                                    |
| `matrix`       | values from a matrix strategy                             |
| `steps`        | outputs from previous steps                               |
| `needs`        | outputs from previous jobs                                |

```yaml
- name: Print info
  run: |
    echo "Triggered by: ${{ github.actor }}"
    echo "Branch: ${{ github.ref_name }}"
    echo "Event: ${{ github.event_name }}"

- name: Only on main
  if: ${{ github.ref == 'refs/heads/main' }}
  run: ./deploy.sh
```

## Q9. How do you set environment variables and outputs?

**Answer:**

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    env:
      NODE_ENV: production           # available to all steps in this job
    steps:
      - name: Set env at runtime
        run: echo "VERSION=1.2.3" >> $GITHUB_ENV

      - name: Use it
        run: echo "Version is $VERSION"

      - id: meta
        name: Produce an output
        run: echo "sha-short=$(git rev-parse --short HEAD)" >> $GITHUB_OUTPUT

      - name: Use a step output
        run: echo "Short SHA: ${{ steps.meta.outputs.sha-short }}"
```

To pass outputs between jobs:

```yaml
jobs:
  setup:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.v.outputs.version }}
    steps:
      - id: v
        run: echo "version=1.0.0" >> $GITHUB_OUTPUT

  build:
    needs: setup
    runs-on: ubuntu-latest
    steps:
      - run: echo "Building ${{ needs.setup.outputs.version }}"
```

## Q10. How do conditional steps and `continue-on-error` work?

**Answer:**

```yaml
steps:
  - name: Always
    run: echo "always runs"

  - name: Only on main
    if: github.ref == 'refs/heads/main'
    run: ./deploy.sh

  - name: Only on PR from same repo
    if: github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name == github.repository
    run: ./run-integration-tests.sh

  - name: Run anyway, ignore failure
    continue-on-error: true
    run: ./flaky-script.sh

  - name: After a failure, run only on failure
    if: failure()
    run: ./notify-slack.sh
```

`failure()`, `success()`, `cancelled()`, and `always()` are useful status functions.

---

## 4. Triggers

## Q11. What are common triggers?

**Answer:**

```yaml
on:
  push:
    branches: [main, "release/*"]
    paths: ["src/**", "!docs/**"]   # only when these paths change
  pull_request:
    types: [opened, synchronize, reopened]
  schedule:
    - cron: "0 6 * * *"             # daily at 06:00 UTC
  workflow_dispatch:                # manual trigger from UI
    inputs:
      env:
        type: choice
        options: [staging, production]
  release:
    types: [published]
  workflow_call:                    # callable from other workflows
```

`workflow_dispatch` adds a "Run workflow" button on the Actions tab.

## Q12. What is the difference between `pull_request` and `pull_request_target`?

**Answer:**

- **`pull_request`** runs in the context of the *PR's* code. For PRs from forks, it runs with **read-only** `GITHUB_TOKEN` and **no** secrets. Safe for untrusted code.
- **`pull_request_target`** runs in the context of the *base* repo. It has full secrets and write permissions. Dangerous to combine with checking out the PR's code, because that code could read your secrets.

Rule: use `pull_request` for normal CI. Use `pull_request_target` only for tasks like labeling or commenting on PRs, and never check out the PR's code in it.

## Q13. How does concurrency control work?

**Answer:**

`concurrency` cancels older runs of the same workflow on the same branch when a new one starts. This saves minutes when devs push rapidly.

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

For deploy workflows you usually do *not* want to cancel — set `cancel-in-progress: false` so deploys queue.

---

## 5. Matrix and Parallelism

## Q14. What is the matrix strategy?

**Answer:**

A matrix runs the same job multiple times with different parameters. Great for testing across versions or operating systems.

```yaml
jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node: [18, 20, 22]
        exclude:
          - os: windows-latest
            node: 18
        include:
          - os: ubuntu-latest
            node: 20
            extra: "with-coverage"

    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm ci && npm test
```

`fail-fast: false` lets all matrix jobs finish so you can see all failures, not just the first.

## Q15. How do you shard tests?

**Answer:**

Sharding splits a large test suite across N runners running in parallel.

```yaml
jobs:
  test:
    strategy:
      matrix:
        shard: [1, 2, 3, 4]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - name: Run shard
        run: npx jest --shard=${{ matrix.shard }}/4
```

The 4 shards run simultaneously, cutting wall time roughly 4x.

---

## 6. Caching and Artifacts

## Q16. How do you cache dependencies?

**Answer:**

The `setup-*` actions usually have built-in caching:

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: npm                # or yarn, pnpm

- uses: actions/setup-python@v5
  with:
    python-version: "3.12"
    cache: pip
```

For custom caches use `actions/cache`:

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.cargo
      target
    key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
    restore-keys: |
      ${{ runner.os }}-cargo-
```

`hashFiles` keys the cache by lockfile contents, so it invalidates only when dependencies change.

## Q17. What are the cache scoping rules?

**Answer:**

- A cache created on a branch is available to that branch and its descendants.
- The default branch (`main`) can write a "base" cache that PR branches can read.
- Total cache storage per repo is limited (10 GB at the time of writing); GitHub evicts the least recently used.

PRs from forks have **read-only** access to caches.

## Q18. What is the difference between artifacts and caches?

**Answer:**

| Feature  | Cache                                     | Artifact                                |
| -------- | ----------------------------------------- | --------------------------------------- |
| Purpose  | Speed up future runs                      | Persist a build output for later use    |
| Lifespan | Up to 7 days unused, evicted by size      | Up to 90 days, configurable             |
| Access   | Across runs of the same repo              | Across jobs in the same run, or download |

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: dist
    path: dist/
    retention-days: 14

- uses: actions/download-artifact@v4
  with:
    name: dist
    path: dist/
```

Use a cache for things you can rebuild (npm modules). Use an artifact for things you want to keep (the build output, test reports).

---

## 7. Reusable Workflows and Composite Actions

## Q19. What is a reusable workflow?

**Answer:**

A reusable workflow is a workflow file that can be called from other workflows. Use it to share entire pipelines (e.g., a standard "build, test, scan" sequence) across repos.

```yaml
# .github/workflows/build.yml — the reusable workflow
on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: "20"
    secrets:
      NPM_TOKEN:
        required: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
      - run: npm ci
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
      - run: npm test
```

Call it:

```yaml
# .github/workflows/ci.yml
jobs:
  ci:
    uses: ./.github/workflows/build.yml
    with:
      node-version: "20"
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

## Q20. What is a composite action?

**Answer:**

A composite action bundles a sequence of steps you want to reuse across workflows in one place.

```yaml
# .github/actions/setup/action.yml
name: "Setup"
description: "Set up Node and install deps"
inputs:
  node-version:
    required: true
runs:
  using: "composite"
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: npm
    - run: npm ci
      shell: bash
```

Use it:

```yaml
- uses: ./.github/actions/setup
  with:
    node-version: "20"
```

## Q21. Reusable workflow vs composite action — when do I choose which?

**Answer:**

| Aspect              | Reusable workflow            | Composite action            |
| ------------------- | ---------------------------- | --------------------------- |
| Scope               | Whole jobs                   | Steps within a job          |
| Runs on             | Its own runner               | The calling job's runner    |
| Has its own secrets | Yes (passed as `secrets:`)   | Inherits caller's           |
| Best for            | Sharing entire pipelines     | Sharing step sequences      |

## Q22. What types of custom actions exist?

**Answer:**

1. **JavaScript actions** — run on Node, cross-platform.
2. **Docker container actions** — run in a Docker container; Linux runners only.
3. **Composite actions** — combine other actions and shell commands.

JS and composite actions are the most common.

---

## 8. Secrets, Environments, and OIDC

## Q23. How are secrets handled?

**Answer:**

Secrets are encrypted values managed at the org, repo, or environment level. They are exposed to workflows as `${{ secrets.NAME }}` and are masked in logs.

```yaml
steps:
  - run: ./deploy.sh
    env:
      AWS_ACCESS_KEY_ID:     ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

Rules:
- Never `echo` a secret directly.
- Secrets are not passed to forked-PR workflows.
- Prefer **OIDC** to long-lived cloud credentials.

## Q24. What are environments and approvals?

**Answer:**

GitHub Environments group secrets and protection rules for a deployment target (staging, production). You can require approval, restrict to specific branches, and add a wait timer.

```yaml
jobs:
  deploy-prod:
    environment:
      name: production
      url: https://example.com
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
        env:
          API_KEY: ${{ secrets.PROD_API_KEY }}
```

Configure required reviewers and branch restrictions in the repo settings under **Environments**.

## Q25. How does OIDC for cloud authentication work?

**Answer:**

OIDC lets a workflow authenticate to AWS, GCP, Azure, etc. with a short-lived token, instead of storing static cloud credentials as secrets.

The flow:
1. GitHub issues a signed JWT identifying the workflow run.
2. Your cloud provider verifies the JWT against GitHub's public keys.
3. The cloud issues short-lived credentials (e.g., AWS STS tokens).

AWS example:

```yaml
permissions:
  id-token: write              # required to request the OIDC token
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-deploy
          aws-region: us-east-1
      - run: aws s3 sync ./dist s3://my-bucket/
```

You configure the IAM role with a trust policy that only accepts tokens from your specific GitHub org/repo/branch.

## Q26. Why use OIDC over static credentials?

**Answer:**

1. **No long-lived keys** stored anywhere.
2. **Short-lived tokens** — typically 1 hour.
3. **Per-workflow scope** — the role can require the token to come from a specific repo and branch.
4. **No rotation** to manage.
5. **Audit trail** is rich (you can see which workflow assumed which role).

## Q27. What are `permissions:` and the `GITHUB_TOKEN`?

**Answer:**

Every workflow run gets an automatically-generated `GITHUB_TOKEN` to authenticate to the GitHub API. By default it has broad permissions; the principle of least privilege says you should set `permissions:` explicitly.

```yaml
permissions:
  contents: read              # default everywhere
  pull-requests: write        # to comment on PRs
  packages: write             # to push to GHCR
  id-token: write             # for OIDC
```

You can set permissions at the workflow level (default) and override per-job.

## Q28. How do you review third-party actions safely?

**Answer:**

A malicious action can read your secrets. To mitigate:

1. **Pin to a SHA** instead of a tag (tags are mutable).
2. Prefer well-known, widely used actions (verified creators).
3. Read the action's source.
4. Keep actions up to date with Dependabot.

```yaml
# Bad: tag is mutable
- uses: someorg/some-action@v1

# Good: pinned to a specific commit
- uses: someorg/some-action@a1b2c3d4e5f6...
```

## Q29. What are branch protection rules?

**Answer:**

Branch protection prevents direct pushes to important branches and enforces quality gates.

Common settings for `main`:
- Require pull request reviews (1 or more approvers).
- Require status checks to pass (your CI workflows).
- Require branches to be up to date.
- Require signed commits.
- Require linear history (no merge commits).
- Restrict who can push.

Configure in **Settings → Branches → Branch protection rules**, or via Rulesets for org-wide policies.

---

## 9. Self-Hosted Runners

## Q30. Hosted vs self-hosted runners — what is the difference?

**Answer:**

| Aspect          | GitHub-hosted                       | Self-hosted                           |
| --------------- | ----------------------------------- | ------------------------------------- |
| Setup           | Zero                                | You install and maintain the runner   |
| Image           | Standard Ubuntu/Windows/macOS       | Whatever you build                    |
| Cost            | Per minute (free tier for public)   | Your infra cost                       |
| Network access  | Public internet                     | Your VPC; can reach private resources |
| Hardware        | Fixed                               | You pick (GPUs, big RAM, etc.)        |
| Ephemeral       | Yes (clean per job)                 | Configurable                          |

Use self-hosted when you need private network access, custom hardware, or enormous CI volume.

## Q31. How do you secure self-hosted runners?

**Answer:**

1. **Never** run self-hosted runners on public repos — anyone can run code on them via PRs.
2. Use **ephemeral** runners (one job, then destroyed). Tools: Actions Runner Controller (ARC) on Kubernetes.
3. Run with a non-privileged user; limit network egress.
4. Patch the runner agent and the OS regularly.
5. Use labels to scope which jobs can run on which runners.

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, gpu]
```

---

## 10. Build, Test, Deploy Patterns

## Q32. Show me a standard CI pipeline.

**Answer:**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      - run: npm test -- --coverage
      - uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/

  build:
    needs: [lint, test]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/
```

## Q33. What are service containers?

**Answer:**

Service containers are sidecar containers that run alongside your job — typically databases or message brokers used by integration tests.

```yaml
jobs:
  integration:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_PASSWORD: secret
        ports: ["5432:5432"]
        options: >-
          --health-cmd "pg_isready -U postgres"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - run: ./run-integration-tests.sh
        env:
          DATABASE_URL: postgres://postgres:secret@localhost:5432/postgres
```

The runner waits for the health check to pass before running steps.

## Q34. What patterns work for monorepo CI?

**Answer:**

Monorepos benefit from running CI only for the parts that changed.

```yaml
on:
  push:
    paths:
      - "packages/api/**"
      - ".github/workflows/api.yml"

jobs:
  test-api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd packages/api && npm ci && npm test
```

For more sophistication, use **dorny/paths-filter** or a tool like Nx/Turborepo that knows the dependency graph between packages.

## Q35. How do you automate semantic versioning?

**Answer:**

Use **semantic-release**: it parses Conventional Commits, determines the next version, creates a tag, generates a changelog, and publishes.

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npx semantic-release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN:    ${{ secrets.NPM_TOKEN }}
```

A commit like `feat: add login` triggers a minor bump; `fix: handle null` triggers a patch; `feat!: drop Node 16` triggers a major.

---

## 11. Container Builds in CI

## Q36. How do you build and push to GHCR?

**Answer:**

```yaml
name: Docker

on:
  push:
    branches: [main]
    tags: ["v*"]

permissions:
  contents: read
  packages: write

jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

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
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=sha,format=short

      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

`type=gha` uses GitHub Actions' build cache — fast and free.

## Q37. How do you push to AWS ECR with OIDC?

**Answer:**

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-ecr-push
          aws-region: us-east-1

      - id: ecr
        uses: aws-actions/amazon-ecr-login@v2

      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.ecr.outputs.registry }}/myapp:${{ github.sha }}
```

No AWS keys are ever stored in GitHub.

## Q38. How do you scan images in CI?

**Answer:**

```yaml
- name: Build image
  uses: docker/build-push-action@v6
  with:
    context: .
    load: true
    tags: myapp:ci

- name: Scan with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: myapp:ci
    severity: HIGH,CRITICAL
    exit-code: 1                       # fail the build on findings
    ignore-unfixed: true
```

Run scans on every push so vulnerabilities are caught before deploy.

---

## 12. Deployment Strategies

## Q39. Rolling, blue-green, canary — what are the differences?

**Answer:**

| Strategy   | How it works                                                | Rollback                        |
| ---------- | ----------------------------------------------------------- | ------------------------------- |
| Rolling    | Replace instances a few at a time                           | Continue rolling old version    |
| Blue-green | Run two full environments; switch traffic in one step       | Switch traffic back             |
| Canary     | Send small % of traffic to new version, increase gradually  | Stop sending traffic to canary  |

Rolling is simplest and the default for Kubernetes. Blue-green gives instant rollback. Canary lets you catch issues with minimal blast radius.

## Q40. Show me a canary deploy in GitHub Actions.

**Answer:**

```yaml
jobs:
  canary:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Deploy 10% canary
        run: kubectl set image deploy/api api=myapp:${{ github.sha }} -n canary
      - name: Wait and watch metrics
        run: ./scripts/check-canary-metrics.sh
      - name: Promote to 100%
        if: success()
        run: kubectl set image deploy/api api=myapp:${{ github.sha }}
      - name: Roll back canary
        if: failure()
        run: kubectl rollout undo deploy/api -n canary
```

`./scripts/check-canary-metrics.sh` queries Prometheus for error rate and latency and exits non-zero if they regress.

## Q41. What rollback strategies are common?

**Answer:**

1. **Re-deploy the previous artifact** — simple if your registry retains old images.
2. **Kubectl rollout undo** — for Kubernetes, the easiest path.
3. **DB migrations** — make migrations backward-compatible so the old code still runs.
4. **Feature flags** — instead of rolling back code, flip the flag off.

```bash
kubectl rollout undo deployment/api
kubectl rollout history deployment/api
```

## Q42. How do you integrate feature flags?

**Answer:**

Deploy code dark (behind a flag), then flip the flag separately. Decouple deploy from release.

Tools: LaunchDarkly, Unleash, Flagsmith, or roll your own with a config service.

```javascript
if (flags.isEnabled("new-checkout", { userId })) {
  return renderNewCheckout();
}
return renderOldCheckout();
```

A flagged rollout means rollback is a config change, not a redeploy.

## Q43. How do you deploy to Kubernetes from GitHub Actions?

**Answer:**

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-eks
          aws-region: us-east-1

      - run: aws eks update-kubeconfig --name prod-cluster

      - run: |
          kubectl set image deployment/api api=myapp:${{ github.sha }}
          kubectl rollout status deployment/api --timeout=5m
```

For GitOps, push the new image tag to a Git repo and let Argo CD or Flux apply it.

---

## 13. Comparison with Other CI Systems

## Q44. GitHub Actions vs GitLab CI vs Jenkins vs CircleCI vs Azure DevOps?

**Answer:**

| System           | Strengths                                  | Weaknesses                            |
| ---------------- | ------------------------------------------ | ------------------------------------- |
| GitHub Actions   | Tight GitHub integration, marketplace, OIDC | Vendor-locked to GitHub               |
| GitLab CI        | Built into GitLab, full DevOps platform    | Locked to GitLab                      |
| Jenkins          | Self-hosted, huge plugin ecosystem         | Maintenance burden, dated UI          |
| CircleCI         | Mature, fast, good Docker support          | Separate billing                      |
| Azure DevOps     | Enterprise integration, board + repo + CI  | Heavier UI, fewer marketplace actions |

If your code lives in GitHub, Actions is the obvious default.

## Q45. How do you migrate from Jenkins to GitHub Actions?

**Answer:**

1. Pick one Jenkinsfile to start with.
2. Map stages → jobs, steps → steps.
3. Replace plugins with marketplace actions (e.g., AWS, Slack).
4. Move credentials from Jenkins to repo secrets (or OIDC).
5. Replace agents/labels with `runs-on:` and self-hosted runners if needed.
6. Run both in parallel for a while; cut over once green.

---

## 14. Troubleshooting and Best Practices

## Q46. Flaky CI — how do you fix it?

**Answer:**

1. Identify which tests are flaky (track failure rates).
2. Quarantine them so the pipeline stays green.
3. Fix or delete them.
4. Common causes: shared global state, timing assumptions, network calls in unit tests, non-deterministic ordering.
5. Use deterministic test data and seed RNGs.

`Retry on flake` should be the last resort, not the cure.

## Q47. How do you debug a failing workflow?

**Answer:**

```yaml
# Re-run with debug logs
# Set repo secrets:
#   ACTIONS_RUNNER_DEBUG=true
#   ACTIONS_STEP_DEBUG=true
# Then re-run the failed job; logs are far more verbose.
```

Or open an interactive shell on the runner using `mxschmitt/action-tmate`:

```yaml
- name: Debug shell on failure
  if: failure()
  uses: mxschmitt/action-tmate@v3
  with:
    limit-access-to-actor: true
```

## Q48. How do you speed up pipelines?

**Answer:**

1. Cache dependencies (npm, pip, gradle, cargo).
2. Use BuildKit caching for Docker images.
3. Run jobs in parallel; use matrix and sharding.
4. Skip unchanged paths with `paths:` filters.
5. Use `concurrency` to cancel superseded runs.
6. Choose smaller base images for build steps.
7. Move integration tests to a separate workflow that runs less often.
8. Profile your slow steps — sometimes one `npm install` dominates.

## Q49. What CI metrics should you monitor?

**Answer:**

1. **Pipeline duration (p50, p95)** — slow pipelines hurt productivity.
2. **Pipeline success rate** — too many failures means flaky tests or process issues.
3. **Time to merge** — from PR open to merge.
4. **DORA metrics** — deployment frequency, lead time, change failure rate, MTTR.
5. **Actions minutes consumed** — for cost management.

GitHub now exposes some of these via the Insights tab and the workflow run API.

## Q50. What goes into a deployment runbook?

**Answer:**

A runbook is the document a tired on-caller reads at 3 AM. It should include:

1. What this service does.
2. How to deploy and roll back.
3. Health-check URLs and key dashboards.
4. Common failure modes and their remediation.
5. Escalation paths and contacts.
6. Database migration procedures.
7. Where logs and metrics live.

## Q51. What are common GitHub Actions pitfalls?

**Answer:**

1. Using `pull_request_target` and checking out PR code (security hole).
2. Storing long-lived AWS keys instead of using OIDC.
3. Not pinning third-party actions to SHAs.
4. No `concurrency` block — duplicate runs cost minutes.
5. No `permissions:` block — `GITHUB_TOKEN` defaults are too broad.
6. Building Docker images without caching.
7. Running everything on every push, even unrelated changes.
8. Storing secrets in workflow YAML (visible in Git history).

## Q52. What is a sensible CI/CD checklist?

**Answer:**

- Every PR runs lint, tests, build, and security scans.
- Concurrency cancels superseded runs.
- Caches keyed by lockfile hashes.
- Permissions block scoped to least privilege.
- Cloud auth via OIDC, not static keys.
- Third-party actions pinned to SHA.
- Branch protection on `main` requires green CI and review.
- Environments configured with required reviewers for production.
- Deploys are idempotent and have a one-command rollback.
- Docker images built with BuildKit cache and scanned for CVEs.
- Pipeline runs in well under 15 minutes.
- Runbook documented for every deploy target.
