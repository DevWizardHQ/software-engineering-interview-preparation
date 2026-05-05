# Docker Interview Questions

**Level:** Mid to Senior
**Topics:** Containers, Images, Dockerfile, Compose, Networking, Volumes, Security, Production Patterns

---

## Table of Contents

1. [Fundamentals](#fundamentals)
2. [Images and Dockerfile](#images-and-dockerfile)
3. [Containers and Runtime](#containers-and-runtime)
4. [Docker Compose](#docker-compose)
5. [Networking](#networking)
6. [Volumes and Storage](#volumes-and-storage)
7. [Security](#security)
8. [Production Patterns](#production-patterns)
9. [BuildKit and Advanced Builds](#buildkit-and-advanced-builds)
10. [Debugging and Troubleshooting](#debugging-and-troubleshooting)

---

## Fundamentals

### Q1. What is Docker?

**Answer:**
Docker is a platform for packaging applications and their dependencies into portable, isolated units called containers. It uses Linux kernel features (namespaces, cgroups, union filesystems) to provide process isolation without the overhead of a full virtual machine.

---

### Q2. Containers vs Virtual Machines?

| Aspect | Container | Virtual Machine |
|--------|-----------|-----------------|
| OS | Shares host kernel | Full guest OS |
| Boot time | Seconds (or less) | Minutes |
| Size | MBs | GBs |
| Isolation | Process-level (namespaces, cgroups) | Hardware-level (hypervisor) |
| Performance | Near-native | Slight virtualization overhead |
| Density | 100s per host | 10s per host |
| Use case | Microservices, app packaging | OS isolation, legacy workloads |

Containers share the host kernel, making them lightweight; VMs each run their own kernel.

---

### Q3. What is Docker's architecture?

**Answer:**
- **Docker Client** — the CLI (`docker`) that sends commands.
- **Docker Daemon (`dockerd`)** — manages images, containers, networks, volumes.
- **containerd** — high-level container runtime; pulls images and manages container lifecycle.
- **runc** — low-level runtime that creates and runs containers per the OCI spec.
- **Registry** — stores images (Docker Hub, GHCR, ECR, private).

Client → REST API → Daemon → containerd → runc → kernel.

---

### Q4. Image vs container?

**Answer:**
- **Image** — read-only template with the filesystem and metadata. Built from a Dockerfile, made of layers.
- **Container** — a running (or stopped) instance of an image with a thin writable top layer.

Analogy: image is the class, container is the instance.

---

### Q5. What are image layers?

**Answer:**
Each instruction in a Dockerfile produces a layer. Layers are stacked using a union filesystem (overlay2). Layers are:
- immutable
- shared between images (saves disk and bandwidth)
- cached for fast rebuilds

```dockerfile
FROM node:20-alpine          # base layer
WORKDIR /app                 # metadata layer (no fs change)
COPY package*.json ./        # layer with package files
RUN npm ci                   # layer with node_modules
COPY . .                     # layer with source code
CMD ["node", "server.js"]    # metadata only
```

---

### Q6. What is the OCI specification?

**Answer:**
The Open Container Initiative defines standards for container image format and runtime behavior. Docker images and runtimes are OCI-compliant, so they interop with other tools (Podman, containerd, CRI-O, Kubernetes).

---

## Images and Dockerfile

### Q7. What is a Dockerfile?

**Answer:**
A text file with instructions to build an image.

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY . .
EXPOSE 3000
USER node
CMD ["node", "server.js"]
```

---

### Q8. Common Dockerfile instructions?

| Instruction | Purpose |
|-------------|---------|
| `FROM` | Base image |
| `WORKDIR` | Sets working directory |
| `COPY` / `ADD` | Copy files into image |
| `RUN` | Execute command at build time |
| `CMD` | Default container command |
| `ENTRYPOINT` | Container entrypoint (combined with CMD) |
| `ENV` | Environment variable |
| `ARG` | Build-time variable |
| `EXPOSE` | Document a port |
| `VOLUME` | Declare a mount point |
| `USER` | Set runtime user |
| `HEALTHCHECK` | Container health probe |
| `LABEL` | Metadata |

---

### Q9. CMD vs ENTRYPOINT?

**Answer:**
- **CMD** — default arguments; can be overridden by `docker run image arg`.
- **ENTRYPOINT** — the executable; CMD becomes its default arguments.

```dockerfile
ENTRYPOINT ["node"]
CMD ["server.js"]
```

`docker run app` → `node server.js`
`docker run app worker.js` → `node worker.js`

Best practice: use `ENTRYPOINT` for the binary, `CMD` for default flags. Always use exec form (JSON array) for proper signal handling.

---

### Q10. COPY vs ADD?

**Answer:**
Both copy files. `ADD` additionally:
- auto-extracts local tar archives
- supports remote URLs

Best practice: prefer `COPY`. Use `ADD` only when you need its extra features. URLs should be fetched via `RUN curl` so you can clean up in the same layer.

---

### Q11. What is a multi-stage build?

**Answer:**
Multiple `FROM` statements in a single Dockerfile. Each stage is independent; you copy only the needed artifacts to the final stage. Result: small, secure production images.

```dockerfile
# Stage 1: build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: runtime
FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=builder /app/dist ./dist
USER node
CMD ["node", "dist/server.js"]
```

---

### Q12. How does layer caching work?

**Answer:**
Docker checks each instruction against its cache key (instruction text + parent layer + file content for COPY/ADD). On a hit, it reuses the cached layer. On a miss, that step and all subsequent steps re-run.

**Optimization:** put rarely changing instructions first.

```dockerfile
# Good: deps cached when only source changes
COPY package*.json ./
RUN npm ci
COPY . .

# Bad: any source change reinstalls deps
COPY . .
RUN npm ci
```

---

### Q13. What is `.dockerignore`?

**Answer:**
Excludes files from the build context sent to the daemon. Reduces build time, image size, and prevents secret leakage.

```
node_modules
.git
.env
.env.local
*.log
dist
coverage
.vscode
.DS_Store
Dockerfile
docker-compose*.yml
```

---

### Q14. Alpine vs slim vs distroless?

| Image | Size | Tools | Use case |
|-------|------|-------|----------|
| `node:20` | ~1 GB | Full Debian | Development |
| `node:20-slim` | ~250 MB | Minimal Debian | Production with shell access |
| `node:20-alpine` | ~150 MB | musl libc, busybox | Smallest with shell |
| `gcr.io/distroless/nodejs20` | ~120 MB | No shell, no package manager | Production hardened |

**Trade-offs:**
- Alpine uses musl libc (some packages with native bindings break).
- Distroless has no shell, making `docker exec` impossible — debug via `:debug` variants.
- Slim is a safe default when alpine causes issues.

---

### Q15. Best practices for small images?

**Answer:**
1. Use minimal base images (alpine, slim, distroless).
2. Multi-stage builds — drop build tools.
3. Combine `RUN` commands to reduce layers; clean up in the same layer:
   ```dockerfile
   RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
   ```
4. Use `.dockerignore`.
5. Order instructions for cache (rarely-changing first).
6. Don't install dev/test dependencies in production stage.
7. Avoid `apt-get upgrade`; use a fresh base image.

---

### Q16. Why is `latest` tag dangerous?

**Answer:**
- Not immutable — points to a moving target.
- Builds aren't reproducible.
- Rollback is unclear.
- Image pulls may produce a different image on different days.

Use specific tags or digests:
```dockerfile
FROM node:20.11.1-alpine3.19
# or
FROM node@sha256:abc123...
```

---

### Q17. What is a `HEALTHCHECK`?

**Answer:**
A periodic command Docker runs to determine container health. Reflected in `docker ps` STATUS and used by orchestrators.

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:3000/health || exit 1
```

Exit 0 = healthy, 1 = unhealthy.

---

### Q18. ARG vs ENV?

**Answer:**

| | ARG | ENV |
|---|---|---|
| Scope | Build time only | Build and runtime |
| Override | `--build-arg` | `-e` or compose `environment` |
| In running container | No | Yes |

```dockerfile
ARG NODE_VERSION=20
FROM node:${NODE_VERSION}-alpine
ENV PORT=3000
```

Never put secrets in ARG/ENV — they leak into image history and `docker inspect`.

---

## Containers and Runtime

### Q19. Common Docker commands?

```bash
docker run -d --name api -p 3000:3000 myimage:tag   # run detached
docker ps                                             # running containers
docker ps -a                                          # all containers
docker logs -f api                                    # follow logs
docker exec -it api sh                                # shell into running container
docker inspect api                                    # full metadata
docker stats                                          # live resource usage
docker stop api && docker rm api                      # stop and remove
docker image ls                                       # list images
docker image prune -a                                 # remove unused images
docker system df                                      # disk usage
docker system prune -af --volumes                     # nuke everything unused
```

---

### Q20. What is a restart policy?

**Answer:**
Tells Docker when to restart a container.

| Policy | Behavior |
|--------|----------|
| `no` | Never restart (default) |
| `on-failure[:N]` | Restart on non-zero exit, optional max retries |
| `always` | Always restart, even after daemon restart |
| `unless-stopped` | Like always, but respects manual `docker stop` |

```bash
docker run --restart unless-stopped myapp
```

For production: `unless-stopped` or use an orchestrator.

---

### Q21. How do containers handle signals?

**Answer:**
PID 1 in the container receives signals. `docker stop` sends SIGTERM (10s grace by default), then SIGKILL.

**Pitfall:** shell-form CMD (`CMD node server.js`) wraps in `/bin/sh -c`, which doesn't forward signals. Use exec form (`CMD ["node", "server.js"]`).

For Node, ensure graceful shutdown:
```js
process.on('SIGTERM', () => server.close(() => process.exit(0)));
```

Use `tini` or `--init` for proper PID 1 behavior (zombie reaping):
```bash
docker run --init myapp
```

---

### Q22. How to limit container resources?

```bash
docker run \
  --cpus=1.5 \
  --memory=512m \
  --memory-swap=512m \
  --pids-limit=200 \
  myapp
```

Backed by Linux cgroups. Always set limits in production to prevent noisy-neighbor issues.

---

### Q23. Difference between `docker run` and `docker create`?

**Answer:**
- `docker create` — creates the container without starting.
- `docker start` — starts an existing container.
- `docker run` = `create` + `start`.

---

## Docker Compose

### Q24. What is Docker Compose?

**Answer:**
A tool for defining and running multi-container applications via a YAML file. Manages networks, volumes, build, dependencies, and environment as a single unit.

```yaml
services:
  api:
    build: .
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://app:secret@db:5432/app
    depends_on:
      db:
        condition: service_healthy
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: app
    volumes:
      - dbdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
      retries: 10
volumes:
  dbdata:
```

---

### Q25. Compose `depends_on` — does it wait for the service to be ready?

**Answer:**
Plain `depends_on` only waits for the container to start, not for the application inside to be ready. Use `condition: service_healthy` with a healthcheck for true readiness, or implement retry logic in your app.

---

### Q26. How do services communicate in Compose?

**Answer:**
Compose creates a default bridge network. Services reach each other by service name as DNS:
```
postgres://db:5432
http://api:3000
```

No need to expose ports between services on the same network — only expose to the host with `ports:` when needed externally.

---

### Q27. Profiles and override files?

**Answer:**
- **Profiles** — selectively start services (`docker compose --profile dev up`).
- **Override files** — `docker-compose.override.yml` is auto-merged. Use named overrides for environments:
  ```bash
  docker compose -f docker-compose.yml -f docker-compose.prod.yml up
  ```

---

## Networking

### Q28. Docker network drivers?

| Driver | Use case |
|--------|----------|
| `bridge` | Default; isolated network on a single host |
| `host` | Container shares host network namespace; no isolation |
| `none` | No networking |
| `overlay` | Multi-host networking (Swarm/Kubernetes) |
| `macvlan` | Container appears as physical device on LAN |

---

### Q29. Default bridge vs user-defined bridge?

**Answer:**
- **Default bridge** (`docker0`) — containers reach each other only by IP; legacy.
- **User-defined bridge** — automatic DNS resolution by container name; better isolation. Always create one for multi-container apps.

```bash
docker network create app-net
docker run --network app-net --name api ...
docker run --network app-net --name db ...
# api can reach db at "db:5432"
```

Compose creates a user-defined bridge automatically.

---

### Q30. Host vs bridge network?

**Answer:**
- **Bridge** — NAT, port mapping required, isolation.
- **Host** — no isolation, no port mapping, slightly higher performance, conflicts on ports.

Host is useful for high-throughput apps or when you need broadcast/multicast. Avoid on shared hosts.

---

### Q31. How does port mapping work?

```bash
docker run -p 8080:80 nginx
# host:container — host's 8080 forwards to container's 80
docker run -p 127.0.0.1:8080:80 nginx
# bind only to localhost
```

Implemented via iptables NAT rules.

---

### Q32. What is overlay network?

**Answer:**
Spans multiple Docker hosts. Used by Swarm and Kubernetes (via CNI plugins). Encapsulates traffic in VXLAN so containers on different machines share an L2 network.

---

## Volumes and Storage

### Q33. Volume types?

| Type | Managed by Docker | Path control | Best for |
|------|-------------------|--------------|----------|
| Named volume | Yes | No (Docker chooses) | Production data |
| Bind mount | No | Yes (host path) | Dev, configs |
| `tmpfs` | Memory only | N/A | Secrets, scratch |

```bash
docker run -v dbdata:/var/lib/postgresql/data postgres        # named
docker run -v $(pwd)/src:/app/src myapp                       # bind
docker run --tmpfs /tmp myapp                                 # tmpfs
```

---

### Q34. Why prefer named volumes in production?

**Answer:**
- Decoupled from host paths (portable).
- Backed up and managed via Docker CLI.
- Permissions handled correctly.
- Drivers support remote storage (NFS, EBS).

Bind mounts are fine for development, but couple containers to host filesystem layout.

---

### Q35. How to back up a named volume?

```bash
docker run --rm \
  -v dbdata:/data \
  -v $(pwd):/backup \
  alpine \
  tar czf /backup/dbdata-$(date +%F).tar.gz -C /data .
```

---

### Q36. Volume vs `VOLUME` in Dockerfile?

**Answer:**
`VOLUME /data` declares a mount point — Docker auto-creates an anonymous volume if none is mounted. Anonymous volumes accumulate; prefer mounting explicit named volumes at runtime.

---

## Security

### Q37. Docker security best practices?

**Answer:**
1. **Don't run as root** — `USER node` in Dockerfile.
2. **Use minimal base images** (distroless, alpine).
3. **Pin versions** — never `latest`.
4. **Scan images** — `docker scout cves`, Trivy, Snyk.
5. **Sign images** — Cosign / Docker Content Trust.
6. **Drop capabilities** — `--cap-drop=ALL --cap-add=NET_BIND_SERVICE`.
7. **Read-only filesystem** — `--read-only` with `--tmpfs /tmp`.
8. **No new privileges** — `--security-opt=no-new-privileges`.
9. **Don't mount the Docker socket** into containers (full host control).
10. **Use secrets** for credentials — not ENV.
11. **Limit resources** to prevent DoS.
12. **Patch the daemon** — Docker itself.

---

### Q38. How to run as non-root?

```dockerfile
FROM node:20-alpine
RUN addgroup -S app && adduser -S -G app app
WORKDIR /app
COPY --chown=app:app . .
USER app
CMD ["node", "server.js"]
```

For ports < 1024, you need `setcap` or run on a higher port and proxy.

---

### Q39. How to scan images for vulnerabilities?

```bash
docker scout cves myimage:tag
trivy image myimage:tag
grype myimage:tag
```

Wire scanning into CI; fail builds on HIGH/CRITICAL CVEs.

---

### Q40. What is image signing?

**Answer:**
Cryptographic verification that an image is from the expected publisher and unmodified. Tools:
- **Cosign (Sigstore)** — keyless signing, common in modern CI.
- **Docker Content Trust** — older Notary-based signing.

```bash
cosign sign ghcr.io/org/app:1.0.0
cosign verify --certificate-identity=... ghcr.io/org/app:1.0.0
```

Kubernetes admission controllers (Connaisseur, Kyverno) enforce signed images only.

---

### Q41. How to handle secrets safely?

**Answer:**
**Don't:**
- Bake secrets into images via ENV/ARG.
- Commit secrets to Git.

**Do:**
- BuildKit secrets at build time:
  ```dockerfile
  RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
  ```
  ```bash
  docker build --secret id=npmrc,src=$HOME/.npmrc .
  ```
- Runtime: Docker Secrets (Swarm), Kubernetes Secrets, HashiCorp Vault, AWS Secrets Manager, mounted files, or env injected by orchestrator.

---

### Q42. Why never mount `/var/run/docker.sock` into a container?

**Answer:**
The socket is a root API. A container with the socket can:
- Run a privileged container.
- Mount the host filesystem.
- Effectively become root on the host.

If absolutely required (e.g., CI runners), use rootless Docker or a socket proxy that whitelists endpoints.

---

## Production Patterns

### Q43. Docker Swarm overview?

**Answer:**
Built-in container orchestrator. Modes: manager and worker nodes. Features:
- Declarative service definition.
- Rolling updates.
- Built-in load balancer (routing mesh).
- Overlay networking.
- Secrets and configs.

```bash
docker swarm init
docker stack deploy -c docker-compose.yml myapp
docker service ls
```

Mostly superseded by Kubernetes, but simpler for small deployments.

---

### Q44. Swarm vs Kubernetes?

| Aspect | Swarm | Kubernetes |
|--------|-------|------------|
| Setup | Built-in, minutes | Complex, hours |
| Scaling | Up to ~1000 nodes | 5000+ nodes |
| Ecosystem | Small | Massive |
| Features | Basic | Auto-scaling, operators, CRDs, etc. |
| Learning curve | Easy | Steep |
| Community | Declining | Dominant |

Use Swarm for simple deploys you control end-to-end; Kubernetes for everything else at scale.

---

### Q45. Common production patterns?

1. **Sidecar** — auxiliary container next to the main app (logging, proxy).
2. **Init container** — runs to completion before the main container starts (migrations).
3. **Ambassador** — proxy that abstracts external services.
4. **Adapter** — normalizes outputs (e.g., logs to a standard format).
5. **Worker pool** — N replicas of a queue consumer behind a queue.

---

### Q46. How to log from containers?

**Answer:**
Write to stdout/stderr; let the orchestrator route logs.

```bash
docker logs -f --tail 100 mycontainer
```

Logging drivers: `json-file` (default), `journald`, `syslog`, `fluentd`, `awslogs`, `gelf`. Configure rotation:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "5"
```

Otherwise logs grow unbounded and fill the disk.

---

### Q47. Zero-downtime deploys with Compose?

**Answer:**
Compose isn't designed for it. Patterns:
- Run two stacks behind a reverse proxy (blue/green) and switch upstream.
- Use `docker compose up -d --no-deps --build service` with multiple replicas + healthchecks + a proxy with retries.

For real zero-downtime, use Swarm rolling updates or Kubernetes.

---

## BuildKit and Advanced Builds

### Q48. What is BuildKit?

**Answer:**
The modern Docker build engine, default in Docker 23+. Improvements:
- Parallel stage execution.
- Better cache (content-addressable, exportable).
- Build secrets (`--mount=type=secret`).
- SSH forwarding (`--mount=type=ssh`).
- Cache mounts (`--mount=type=cache`).
- Frontend support (e.g., Dockerfile, but also Buildpacks).

```dockerfile
# syntax=docker/dockerfile:1.7

FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build
```

---

### Q49. What is `buildx`?

**Answer:**
Docker CLI plugin for BuildKit — supports multi-platform, remote builders, and advanced cache.

```bash
docker buildx create --name multi --use
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag ghcr.io/org/app:1.0.0 \
  --push .
```

---

### Q50. How to build multi-arch images?

**Answer:**
With buildx + QEMU emulation or native multi-arch builders:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
docker buildx build --platform linux/amd64,linux/arm64 -t myimg --push .
```

The result is a manifest list — clients pull the matching arch.

---

### Q51. Cache mounts vs layer cache?

**Answer:**
- **Layer cache** — entire layer reused if instruction is unchanged.
- **Cache mount** — directory persisted across builds without baking into the image.

Cache mounts are great for package managers:
```dockerfile
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt/lists \
    apt-get update && apt-get install -y curl
```

The mounted directory does not become part of the image.

---

### Q52. Remote/registry cache?

```bash
docker buildx build \
  --cache-from=type=registry,ref=ghcr.io/org/app:cache \
  --cache-to=type=registry,ref=ghcr.io/org/app:cache,mode=max \
  -t ghcr.io/org/app:1.0.0 --push .
```

Crucial in CI where each runner is fresh.

---

## Debugging and Troubleshooting

### Q53. Debugging a failing container?

```bash
docker logs <container>                        # check stderr/stdout
docker inspect <container>                     # state, exit code, mounts
docker exec -it <container> sh                 # shell in running container
docker run --rm -it --entrypoint sh myimage    # shell into image without entrypoint
docker events                                  # live daemon events
docker stats                                   # CPU/mem live
docker top <container>                         # processes inside container
docker diff <container>                        # filesystem changes
```

For distroless / scratch images: build a debug variant or use `docker debug` (Docker Desktop) / `kubectl debug`.

---

### Q54. Container exits immediately. Why?

**Common causes:**
1. **No long-running process** — e.g., `CMD ["bash"]` exits because there's no TTY. Use `-it` for interactive.
2. **Crash on startup** — check `docker logs` and exit code (`docker inspect --format='{{.State.ExitCode}}'`).
3. **Missing dependency / wrong base image arch** (e.g., x86 binary on arm64).
4. **PID 1 issues** — shell-form CMD swallows signals.
5. **Missing config / env vars**.
6. **Port already in use**.

---

### Q55. Disk filling up — how to investigate?

```bash
docker system df                  # overview
docker system df -v               # detailed per-resource
docker image prune -a             # remove unused images
docker container prune            # remove stopped containers
docker volume prune               # remove unused volumes
docker builder prune --all        # build cache
docker system prune -af --volumes # nuclear option
```

Common culprits: unbounded logs, accumulated build cache, dangling images, orphan volumes.

---

### Q56. Common pitfalls in production?

1. Running as root.
2. Using `latest` tags.
3. No resource limits.
4. No healthchecks.
5. Secrets in environment variables.
6. Not handling SIGTERM (graceful shutdown).
7. Logging to files instead of stdout.
8. Building images with secrets in layers (`docker history` reveals them).
9. Not using `.dockerignore` (huge build contexts, leaked files).
10. Mounting Docker socket into containers.
11. Building on unpinned base images.
12. No image signing/scanning.

---

### Q57. Performance tuning tips?

- Use `slirp4netns` or `vpnkit` carefully on Mac/Windows — networking is slower than Linux.
- Mount caches (npm, pip, go) with BuildKit.
- Order Dockerfile for cache hits.
- Use multi-stage builds.
- Push only delta layers (registry already has bases).
- Tune `--memory`, `--cpus`, `--ulimit` per workload.
- For I/O heavy workloads, use named volumes (faster than bind mounts on Mac/Windows).

---

### Q58. How does `docker exec` differ from `docker attach`?

**Answer:**
- `docker exec` — runs a new process in the container (e.g., a shell). Most common for debugging.
- `docker attach` — attaches your terminal to the main process. Detaching wrong (Ctrl+C) can kill the container.

---

### Q59. What is rootless Docker?

**Answer:**
Runs the daemon and containers as a non-root user, using user namespaces. Stronger isolation; no root on host even if container escapes. Some limitations: no privileged ports without setup, slightly slower networking.

---

### Q60. Production checklist?

- [ ] Pinned base image (digest or specific version)
- [ ] Multi-stage build with minimal final image
- [ ] Non-root user
- [ ] `.dockerignore` excludes secrets and build artifacts
- [ ] HEALTHCHECK or orchestrator probe
- [ ] Resource limits set
- [ ] Restart policy
- [ ] Logs to stdout, rotation configured
- [ ] Vulnerability scan passing
- [ ] Image signed
- [ ] Read-only filesystem where possible
- [ ] Secrets managed externally
- [ ] Graceful SIGTERM handling
- [ ] CI builds reproducible (locked dependencies)
- [ ] Multi-arch images (if needed)
