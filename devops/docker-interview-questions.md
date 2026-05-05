# Docker Interview Questions

A practical, teaching-style Q&A guide for Docker. Each question gives a plain-language explanation followed by a working command, Dockerfile, or compose example you can run.

---

## Table of Contents

1. Fundamentals
2. Images and Dockerfile
3. Containers and Runtime
4. Docker Compose
5. Networking
6. Volumes and Storage
7. Security
8. Production Patterns
9. BuildKit and Advanced Builds
10. Debugging and Troubleshooting

---

## 1. Fundamentals

## Q1. What is Docker?

**Answer:**

Docker is a tool that lets you package an application together with its operating system libraries, runtime, and configuration into a single unit called a container. Once packaged, that container runs the same way on any machine that has Docker installed: your laptop, a CI server, or a production cloud VM.

The benefit is consistency. The classic problem of "it works on my machine" is solved because the container carries its own environment with it.

```bash
docker run -d -p 8080:80 --name web nginx:1.27-alpine
curl http://localhost:8080
```

This pulls the Nginx image and runs it as a container, mapping port 8080 on your machine to port 80 inside the container.

## Q2. What is the difference between containers and virtual machines?

**Answer:**

A virtual machine virtualizes the hardware. Each VM contains a full guest operating system and its own kernel. This makes VMs heavy: gigabytes of disk, slow to boot, and expensive in memory.

A container shares the host kernel. It only ships the application and its user-space libraries. This makes containers small (often tens of megabytes), fast to start (seconds or less), and cheap to run hundreds at a time.

| Aspect       | Virtual Machine        | Container             |
| ------------ | ---------------------- | --------------------- |
| Kernel       | Own kernel per VM      | Shares host kernel    |
| Boot time    | 30–60 seconds          | < 1 second            |
| Image size   | Gigabytes              | Megabytes             |
| Isolation    | Strong (hardware-level)| Process-level         |

## Q3. What is Docker's architecture?

**Answer:**

Docker has three main pieces. The Docker client is the CLI you type commands into. The Docker daemon (`dockerd`) is a background process that does the real work: building images, running containers, managing networks. The two talk over a Unix socket. Behind the daemon is `containerd`, which manages container lifecycle, and `runc`, which actually creates the Linux namespaces and cgroups that make a container.

```bash
docker version
# Client: Docker Engine - Community
#   Version: 27.x
# Server: Docker Engine - Community
#   Version: 27.x
```

When you type `docker run`, the client sends a request to the daemon, the daemon asks containerd to start the container, and containerd asks runc to set up the kernel isolation.

## Q4. What is the difference between an image and a container?

**Answer:**

An image is a read-only template. It is a stack of filesystem layers plus metadata that says "to run this, execute command X." Think of an image like a class in programming.

A container is a running (or stopped) instance of an image. It adds a writable layer on top so the application can create files. Think of a container like an object created from a class. You can run many containers from the same image.

```bash
docker pull nginx:1.27-alpine     # downloads the image
docker run -d nginx:1.27-alpine   # creates and starts a container
docker run -d nginx:1.27-alpine   # creates a SECOND container from the same image
docker ps                         # lists running containers
docker images                     # lists local images
```

## Q5. What are image layers?

**Answer:**

Every instruction in a Dockerfile (`RUN`, `COPY`, `ADD`) creates a layer. Layers stack on top of each other and are cached. If a layer has not changed, Docker reuses the cache, making subsequent builds fast.

Layers are also shared between images. If two images both build on `node:20-alpine`, the base layers are stored on disk only once.

```bash
docker history nginx:1.27-alpine
# IMAGE          CREATED      CREATED BY                       SIZE
# abc123         2 weeks ago  CMD ["nginx" "-g" "daemon off;"] 0B
# def456         2 weeks ago  COPY docker-entrypoint.sh /...   1.2kB
```

## Q6. What is the OCI specification?

**Answer:**

OCI (Open Container Initiative) is an industry standard that defines two things: the image format (how layers and metadata are packaged) and the runtime (how to start a container from an image). Because of OCI, an image built by Docker can be run by Podman, containerd, CRI-O, or Kubernetes without modification.

```bash
docker buildx imagetools inspect nginx:1.27-alpine
```

---

## 2. Images and Dockerfile

## Q7. What is a Dockerfile?

**Answer:**

A Dockerfile is a text file containing the steps to build an image. Each line is an instruction that Docker executes in order, and most instructions create a new layer.

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

Build and run it:

```bash
docker build -t myapp:1.0 .
docker run -d -p 3000:3000 myapp:1.0
```

## Q8. What are the most common Dockerfile instructions?

**Answer:**

| Instruction  | Purpose                                                          |
| ------------ | ---------------------------------------------------------------- |
| `FROM`       | Base image to start from                                         |
| `WORKDIR`    | Sets the working directory inside the image                      |
| `COPY`       | Copies files from build context into the image                   |
| `RUN`        | Runs a command at build time and saves the result as a new layer |
| `ENV`        | Sets an environment variable                                     |
| `ARG`        | Build-time variable                                              |
| `EXPOSE`     | Documents which port the app listens on                          |
| `CMD`        | Default command run when the container starts                    |
| `ENTRYPOINT` | Fixed entry executable; arguments come from CMD or `docker run`  |
| `USER`       | Switch to a non-root user                                        |
| `HEALTHCHECK`| Defines how Docker checks if the container is healthy            |

## Q9. What is the difference between CMD and ENTRYPOINT?

**Answer:**

`ENTRYPOINT` defines the executable that always runs. `CMD` provides default arguments to that executable, and those arguments can be overridden on the command line.

```dockerfile
ENTRYPOINT ["python", "app.py"]
CMD ["--port", "8000"]
```

```bash
docker run myapp                  # runs: python app.py --port 8000
docker run myapp --port 9000      # runs: python app.py --port 9000
```

If you only use `CMD` with no `ENTRYPOINT`, the entire CMD can be replaced at runtime.

## Q10. What is the difference between COPY and ADD?

**Answer:**

`COPY` copies local files into the image. It is simple and predictable.

`ADD` does the same, but with two extra behaviors: it can fetch from a URL, and it auto-extracts local tar files. These extras are mostly footguns. Use `COPY` unless you specifically need ADD's auto-extract.

```dockerfile
COPY ./src /app/src                        # preferred
ADD https://example.com/file.tar.gz /tmp/  # rarely needed; prefer RUN curl
```

## Q11. What is a multi-stage build?

**Answer:**

A multi-stage build uses several `FROM` statements in one Dockerfile. You build the application in one stage (which can be heavy because it has compilers, dev dependencies, etc.) and copy only the final artifacts into a small runtime stage. This keeps your final image small and free of build tools.

```dockerfile
# Stage 1: build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: runtime
FROM nginx:1.27-alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

The final image only contains Nginx and the built static files, not Node or `node_modules`.

## Q12. How does layer caching work?

**Answer:**

Docker hashes each instruction along with its inputs (files copied, command run). If the hash matches a previous build, the cached layer is reused. The cache is checked in order, so the moment a layer changes, all layers below it are rebuilt.

The practical lesson: put rarely-changing things first.

```dockerfile
# GOOD: dependencies cached when only source changes
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .

# BAD: any source change reinstalls dependencies
FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm ci
```

## Q13. What is `.dockerignore`?

**Answer:**

`.dockerignore` works like `.gitignore`. It tells Docker which files to skip when sending the build context to the daemon. This makes builds faster and avoids leaking secrets into the image.

```text
node_modules
.git
.env
*.log
dist
.DS_Store
```

Without it, your entire `node_modules` and `.git` folder get uploaded to the daemon every build.

## Q14. Alpine vs slim vs distroless — how do I choose a base image?

**Answer:**

| Base       | Size    | Pros                                    | Cons                                |
| ---------- | ------- | --------------------------------------- | ----------------------------------- |
| `ubuntu`   | ~70 MB  | Familiar, full package manager          | Largest                             |
| `*-slim`   | ~30 MB  | Smaller, still uses glibc               | Fewer tools available               |
| `alpine`   | ~5 MB   | Very small                              | Uses musl libc; some packages break |
| distroless | ~2 MB   | No shell, very few CVEs, secure         | Hard to debug (no shell)            |

A reasonable default for Node, Python, or Go is the `*-slim` or `*-alpine` image of the official language base. For production hardening, use distroless.

```dockerfile
FROM gcr.io/distroless/nodejs20-debian12
COPY --from=builder /app /app
WORKDIR /app
CMD ["server.js"]
```

## Q15. What are best practices for keeping images small?

**Answer:**

1. Use a small base (alpine, slim, or distroless).
2. Use multi-stage builds so build tools never end up in the final image.
3. Combine `RUN` commands and clean up package caches in the same layer.
4. Add a `.dockerignore`.
5. Avoid copying unneeded files like tests, docs, or development configs.

```dockerfile
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*
```

## Q16. Why is the `latest` tag dangerous?

**Answer:**

`latest` is just a tag; it does not mean "newest." It points to whatever the publisher last tagged as `latest`, which can change at any moment. If you deploy with `latest` today and again next week, you may get two completely different images. This breaks reproducibility and can suddenly introduce breaking changes.

Always pin to a specific version, or even better, a digest.

```dockerfile
# Bad
FROM node:latest

# Good
FROM node:20.11.0-alpine

# Best (immutable)
FROM node:20.11.0-alpine@sha256:abc123...
```

## Q17. What is `HEALTHCHECK`?

**Answer:**

`HEALTHCHECK` tells Docker how to verify the container is actually working, not just running. Docker periodically runs the check command. If it fails enough times, the container is marked unhealthy, which orchestrators can use to restart or stop sending traffic.

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

Check status:

```bash
docker ps
# STATUS: Up 2 minutes (healthy)
```

## Q18. What is the difference between ARG and ENV?

**Answer:**

`ARG` is a build-time variable. It exists only while the image is being built and is not present at runtime.

`ENV` is a runtime environment variable. It is baked into the image and visible to processes inside the container.

```dockerfile
ARG NODE_VERSION=20
FROM node:${NODE_VERSION}-alpine

ENV APP_ENV=production
ENV PORT=3000
```

Pass an ARG at build time:

```bash
docker build --build-arg NODE_VERSION=18 -t myapp .
```

Override an ENV at runtime:

```bash
docker run -e APP_ENV=staging myapp
```

---

## 3. Containers and Runtime

## Q19. What are the most common Docker commands?

**Answer:**

```bash
docker ps                       # list running containers
docker ps -a                    # include stopped
docker images                   # list local images
docker run -d --name web nginx  # run detached with a name
docker exec -it web sh          # open a shell in a running container
docker logs -f web              # tail logs
docker stop web                 # graceful stop (SIGTERM, then SIGKILL)
docker rm web                   # remove a stopped container
docker rmi nginx                # remove an image
docker system df                # show disk usage by Docker
docker system prune             # delete unused data (careful)
```

## Q20. What is a restart policy?

**Answer:**

A restart policy tells Docker what to do when the container exits.

| Policy            | Behavior                                                  |
| ----------------- | --------------------------------------------------------- |
| `no` (default)    | Never restart                                             |
| `on-failure`      | Restart only if the exit code is non-zero                 |
| `always`          | Always restart, even if you stop it manually              |
| `unless-stopped`  | Restart unless explicitly stopped (good default for prod) |

```bash
docker run -d --restart unless-stopped --name web nginx
```

## Q21. How do containers handle signals?

**Answer:**

When you run `docker stop`, Docker sends `SIGTERM` to PID 1 inside the container. After a grace period (10 seconds by default), it sends `SIGKILL`. Your application should listen for SIGTERM and shut down cleanly: finish in-flight requests, close database connections, then exit.

A common bug: if you start your app with `CMD npm start`, the shell becomes PID 1 and may not forward signals. Use the exec form:

```dockerfile
# Bad: shell wraps and may swallow signals
CMD npm start

# Good: node is PID 1 and receives SIGTERM directly
CMD ["node", "server.js"]
```

If you must use a shell, add `tini` as init: `--init` flag or `ENTRYPOINT ["/sbin/tini", "--"]`.

## Q22. How do you limit container resources?

**Answer:**

By default a container can use as much CPU and memory as the host has. Use flags to cap it.

```bash
docker run -d \
  --memory=512m \
  --memory-swap=512m \
  --cpus=1.5 \
  --pids-limit=200 \
  myapp
```

`--memory` is a hard cap; the kernel kills the container if it exceeds it. `--cpus=1.5` means at most 1.5 CPU cores worth of compute.

## Q23. What is the difference between `docker run` and `docker create`?

**Answer:**

`docker create` makes a container but does not start it. `docker run` is `docker create` followed by `docker start`. Use `create` when you want to prepare a container, configure it, then start it later.

```bash
docker create --name web nginx
docker start web
```

---

## 4. Docker Compose

## Q24. What is Docker Compose?

**Answer:**

Docker Compose lets you describe a multi-container application in a single YAML file and start everything with one command. It is ideal for local development, integration testing, and small single-host deployments.

```yaml
# docker-compose.yml
services:
  web:
    image: nginx:1.27-alpine
    ports:
      - "8080:80"
  api:
    build: ./api
    environment:
      DATABASE_URL: postgres://postgres:secret@db:5432/app
    depends_on:
      - db
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - dbdata:/var/lib/postgresql/data

volumes:
  dbdata:
```

```bash
docker compose up -d
docker compose logs -f api
docker compose down
```

## Q25. Does `depends_on` wait for the service to be ready?

**Answer:**

By default, `depends_on` only waits until the dependency container has *started*, not until it is *ready* to accept connections. A Postgres container can be started but not yet accepting queries.

Use the `condition: service_healthy` form together with a `healthcheck`:

```yaml
services:
  api:
    build: ./api
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      retries: 5
```

## Q26. How do services communicate in Docker Compose?

**Answer:**

Compose creates a default network and registers each service by name. Inside any container, you can reach another service using its service name as the hostname.

```yaml
services:
  api:
    environment:
      DATABASE_URL: postgres://postgres@db:5432/app
  db:
    image: postgres:16
```

From the `api` container, `db` resolves to the database container's IP. There is no need for IP addresses or port mapping for inter-service traffic.

## Q27. What are profiles and override files?

**Answer:**

Profiles let you tag services so they only start when the profile is selected. This is useful for things like a debug container or a load tester you do not always want running.

```yaml
services:
  app:
    image: myapp
  loadtest:
    image: locust
    profiles: ["test"]
```

```bash
docker compose up                       # only starts app
docker compose --profile test up        # starts both
```

Override files let you layer environment-specific config. Compose automatically merges `docker-compose.override.yml` if it exists.

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 5. Networking

## Q28. What are Docker network drivers?

**Answer:**

| Driver  | When to use                                                            |
| ------- | ---------------------------------------------------------------------- |
| bridge  | Default for single-host setups; isolated network per `docker run`      |
| host    | Container shares host network namespace; no isolation, max performance |
| none    | No networking                                                          |
| overlay | Multi-host networking (Swarm/Kubernetes)                               |
| macvlan | Container appears as a physical device on the LAN                      |

## Q29. What is the difference between the default bridge and a user-defined bridge?

**Answer:**

The default bridge network does not provide DNS-based service discovery. To connect containers, you used to need `--link` (deprecated). A user-defined bridge enables automatic name-based DNS, so containers find each other by name.

```bash
docker network create app-net
docker run -d --name db --network app-net postgres:16
docker run -d --name api --network app-net myapi
# Inside api, "db" resolves to the database container.
```

This is what Docker Compose does for you automatically.

## Q30. What is the difference between host and bridge network?

**Answer:**

With bridge, the container has its own network stack and you publish ports with `-p`. Traffic goes through Docker's NAT.

With host, the container uses the host's network stack directly. There is no port mapping; the container binds directly to the host's ports. This is faster but breaks isolation and only works on Linux.

```bash
docker run -d --network host nginx
# Nginx now listens on the host's port 80 directly.
```

## Q31. How does port mapping work?

**Answer:**

`-p HOST:CONTAINER` tells Docker to forward traffic from a host port to a container port through iptables NAT rules.

```bash
docker run -d -p 8080:80 nginx
# Hitting localhost:8080 on the host reaches port 80 in the container.

docker run -d -p 127.0.0.1:8080:80 nginx
# Bind only to localhost (not exposed to the network).
```

## Q32. What is an overlay network?

**Answer:**

An overlay network spans multiple Docker hosts. Containers on different machines can talk to each other as if on the same network, using VXLAN tunneling underneath. Used in Docker Swarm and (in spirit) Kubernetes.

```bash
docker network create -d overlay --attachable my-overlay
```

---

## 6. Volumes and Storage

## Q33. What are the volume types?

**Answer:**

| Type         | Definition                                                |
| ------------ | --------------------------------------------------------- |
| Named volume | Managed by Docker, lives under `/var/lib/docker/volumes`  |
| Bind mount   | A specific host path mounted into the container           |
| tmpfs        | In-memory only; data gone when container stops            |

```bash
# Named volume
docker run -v dbdata:/var/lib/postgresql/data postgres:16

# Bind mount
docker run -v $(pwd)/code:/app node:20 node /app/server.js

# tmpfs
docker run --tmpfs /tmp:size=64m alpine
```

## Q34. Why prefer named volumes in production?

**Answer:**

Named volumes are managed by Docker. They are portable, get a stable name, can be backed up easily, and do not depend on any specific host directory layout. Bind mounts couple your container to host paths, which makes them fragile when you migrate to another machine.

```yaml
services:
  db:
    image: postgres:16
    volumes:
      - dbdata:/var/lib/postgresql/data

volumes:
  dbdata:
```

## Q35. How do you back up a named volume?

**Answer:**

Run a temporary container that mounts both the volume and a host directory, and tar the data out.

```bash
docker run --rm \
  -v dbdata:/data \
  -v $(pwd):/backup \
  alpine \
  tar czf /backup/dbdata-$(date +%F).tgz -C /data .
```

To restore:

```bash
docker run --rm \
  -v dbdata:/data \
  -v $(pwd):/backup \
  alpine \
  sh -c "cd /data && tar xzf /backup/dbdata-2025-05-05.tgz"
```

## Q36. What is the difference between `volumes:` in compose and `VOLUME` in Dockerfile?

**Answer:**

`VOLUME` in a Dockerfile declares that a path inside the image should be a volume mount point. If you do not provide a volume at runtime, Docker creates an anonymous volume for it. Anonymous volumes are easy to lose track of.

In Compose, `volumes:` explicitly maps a named volume or host path to a container directory. This is much clearer.

In practice: avoid `VOLUME` in Dockerfiles for application images; let the operator decide using compose or `-v`.

---

## 7. Security

## Q37. What are Docker security best practices?

**Answer:**

1. Use small, well-known base images and pin versions.
2. Run as a non-root user inside the container.
3. Make the filesystem read-only when possible (`--read-only`).
4. Drop unnecessary Linux capabilities (`--cap-drop=ALL`).
5. Never run with `--privileged` unless absolutely required.
6. Scan images for known vulnerabilities in CI.
7. Keep secrets out of images; pass them at runtime.

```bash
docker run --rm \
  --read-only \
  --tmpfs /tmp \
  --cap-drop=ALL \
  --user 1000:1000 \
  myapp
```

## Q38. How do you run a container as a non-root user?

**Answer:**

Create a user in the Dockerfile and switch to it. Many official base images already include a non-root user.

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY --chown=node:node . .
USER node
CMD ["node", "server.js"]
```

Or set the user at runtime:

```bash
docker run --user 1000:1000 myapp
```

## Q39. How do you scan images for vulnerabilities?

**Answer:**

Use a scanner like `trivy`, `grype`, or `docker scout`. They examine each image layer and report known CVEs.

```bash
trivy image --severity HIGH,CRITICAL myapp:1.0
docker scout cves myapp:1.0
```

In CI, fail the build when critical CVEs appear.

## Q40. What is image signing?

**Answer:**

Image signing produces a cryptographic signature you can verify before running an image. It proves the image came from a trusted publisher and has not been tampered with. Tools include cosign (Sigstore) and Docker Content Trust.

```bash
# Sign with cosign
cosign sign --key cosign.key ghcr.io/myorg/myapp:1.0

# Verify
cosign verify --key cosign.pub ghcr.io/myorg/myapp:1.0
```

## Q41. How do you handle secrets safely?

**Answer:**

Do not put secrets in Dockerfiles, image layers, or `ENV` variables baked into the image. Pass them at runtime through environment variables, mounted files, or a secrets manager.

```bash
# At runtime, from your local environment
docker run -e DB_PASSWORD="$DB_PASSWORD" myapp

# Mount from a file
docker run -v /etc/secrets/api.key:/run/secrets/api.key:ro myapp
```

In Compose use `secrets:`:

```yaml
services:
  app:
    image: myapp
    secrets:
      - db_password
secrets:
  db_password:
    file: ./db_password.txt
```

## Q42. Why should you never mount `/var/run/docker.sock` into a container?

**Answer:**

Mounting the Docker socket gives the container full control of the Docker daemon. Anyone inside the container can spawn new privileged containers on the host, mount the host's root filesystem, and effectively become root on the host. It is equivalent to giving root access.

If you need Docker-in-Docker for CI, use the rootless `dind` image inside an isolated runner, never on a shared host.

---

## 8. Production Patterns

## Q43. What is Docker Swarm?

**Answer:**

Docker Swarm is Docker's built-in clustering and orchestration tool. You join several Docker hosts into a swarm; Swarm schedules services across them, manages overlay networking, performs rolling updates, and handles failover. It is simpler than Kubernetes but much less feature-rich.

```bash
docker swarm init
docker service create --name web --replicas 3 -p 80:80 nginx
docker service ls
docker service update --image nginx:1.27 web   # rolling update
```

## Q44. Swarm vs Kubernetes — when do you choose which?

**Answer:**

| Aspect          | Swarm                       | Kubernetes                  |
| --------------- | --------------------------- | --------------------------- |
| Setup           | Single command              | Complex (or use managed)    |
| Learning curve  | Low                         | High                        |
| Ecosystem       | Small                       | Huge                        |
| Use case        | Small teams, simple needs   | Large, complex platforms    |

Choose Swarm for small projects where simplicity matters. Choose Kubernetes when you need autoscaling, advanced networking, ingress, observability, and a thriving ecosystem.

## Q45. What are common production patterns?

**Answer:**

1. One process per container.
2. Stateless application containers; state in databases or named volumes.
3. Configuration via environment variables.
4. Logs to stdout/stderr (let the orchestrator collect them).
5. Health checks defined and used by the orchestrator.
6. Resource limits set on every container.
7. Images pinned to immutable tags or digests.

## Q46. How do you log from containers?

**Answer:**

The convention is for the application to write logs to stdout and stderr. Docker captures them automatically and you can ship them with a logging driver.

```bash
docker run --log-driver=json-file --log-opt max-size=10m --log-opt max-file=3 myapp
```

Or send to a remote system:

```bash
docker run --log-driver=fluentd --log-opt fluentd-address=fluentd:24224 myapp
```

In Compose:

```yaml
services:
  app:
    image: myapp
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

## Q47. How do you do a zero-downtime deploy with Compose?

**Answer:**

Plain Docker Compose stops the old container before starting the new one, which causes a brief outage. To avoid that, use a small load balancer (Nginx, Traefik) and start the new container alongside the old one, then switch traffic.

```bash
docker compose up -d --no-deps --scale api=2 api
# wait for new container to become healthy
docker compose up -d --no-deps --scale api=1 api  # drops the old one
```

For real zero-downtime, prefer Swarm (`docker service update`) or Kubernetes rolling deployments.

---

## 9. BuildKit and Advanced Builds

## Q48. What is BuildKit?

**Answer:**

BuildKit is the modern Docker build engine. It is faster, supports parallel layer builds, secret mounts, cache mounts, and remote caches. It is the default in modern Docker.

```dockerfile
# syntax=docker/dockerfile:1.7
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
```

The `--mount=type=cache` keeps the npm cache between builds without bloating the final image.

## Q49. What is `buildx`?

**Answer:**

`buildx` is a CLI plugin that wraps BuildKit. It adds features like building for multiple architectures, pushing to multiple registries, and using remote builders.

```bash
docker buildx create --use --name mybuilder
docker buildx build --platform linux/amd64,linux/arm64 -t myorg/app:1.0 --push .
```

## Q50. How do you build multi-architecture images?

**Answer:**

Use `buildx` with the `--platform` flag. BuildKit emulates the foreign architecture using QEMU.

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/myorg/app:1.0 \
  --push .
```

The resulting image is a multi-arch manifest; pulling on an Apple Silicon Mac fetches the arm64 variant, pulling on an x86 server fetches the amd64 variant — all transparently.

## Q51. Cache mounts vs layer cache?

**Answer:**

Layer cache reuses a whole layer if its inputs match. Cache mounts let a single `RUN` step keep a directory around between builds without saving it as a layer. This is great for package manager caches.

```dockerfile
# syntax=docker/dockerfile:1.7
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y curl
```

The downloaded `.deb` files persist between builds, so subsequent `apt-get install` calls reuse them.

## Q52. What is a remote (registry) cache?

**Answer:**

A registry cache stores BuildKit's cache layers in a container registry. CI runners can share a cache without having a persistent disk.

```bash
docker buildx build \
  --cache-from=type=registry,ref=ghcr.io/myorg/app:buildcache \
  --cache-to=type=registry,ref=ghcr.io/myorg/app:buildcache,mode=max \
  -t ghcr.io/myorg/app:1.0 \
  --push .
```

---

## 10. Debugging and Troubleshooting

## Q53. How do you debug a failing container?

**Answer:**

```bash
docker ps -a                           # see exit code (under STATUS)
docker logs <container>                # see what it printed
docker inspect <container>             # full JSON: env, mounts, networks
docker exec -it <container> sh         # if it is still running
```

If it exits immediately, override the entrypoint to get a shell:

```bash
docker run -it --entrypoint sh myapp
```

## Q54. The container exits immediately. Why?

**Answer:**

Common causes:

1. The CMD/ENTRYPOINT exits with an error — check `docker logs`.
2. The main process is a daemon that backgrounds itself; PID 1 exits and the container stops. Run the process in the foreground.
3. The application crashes on missing env vars.
4. A volume or bind mount overwrites a directory the app needs.

```bash
docker run myapp
docker ps -a    # STATUS: Exited (1) 2 seconds ago
docker logs <container_id>
```

## Q55. The disk is filling up. How do you investigate?

**Answer:**

```bash
docker system df            # high-level breakdown
docker system df -v         # per-image, per-container, per-volume
docker images -a            # find big images
docker ps -a -s             # show container size
```

Clean up:

```bash
docker container prune                  # stopped containers
docker image prune -a                   # unused images
docker volume prune                     # unused volumes (careful!)
docker system prune -a --volumes        # everything (very careful!)
```

## Q56. What are common production pitfalls?

**Answer:**

1. Logs written to a file inside the container instead of stdout, filling the container disk.
2. No restart policy; an OOM kill takes the service down permanently.
3. No memory limit; one container starves the host.
4. Using `latest` tag and getting unexpected upgrades.
5. Storing data in container layers instead of volumes; data lost on redeploy.
6. Building on the production host instead of pushing to a registry.
7. Mounting `/var/run/docker.sock` in user containers.

## Q57. What are some performance tuning tips?

**Answer:**

1. Use Alpine or slim base images to reduce I/O.
2. Pre-build production images in CI; never build in prod.
3. Use `--init` (or tini) so PID 1 reaps zombies.
4. Set CPU and memory limits matching the workload.
5. Tune the logging driver — `json-file` with size caps prevents log bloat.
6. Use BuildKit cache mounts for faster CI.

## Q58. How does `docker exec` differ from `docker attach`?

**Answer:**

`docker exec` starts a new process inside an existing container. `docker attach` connects your terminal to the container's main process (PID 1).

If you `Ctrl+C` an `attach` session, you may signal the main process and kill the container. With `exec`, you only kill the new process.

```bash
docker exec -it web sh    # safe; starts a new shell
docker attach web         # connects to PID 1; Ctrl+C may stop the container
```

## Q59. What is rootless Docker?

**Answer:**

Rootless Docker runs the daemon and containers as a non-root user on the host. This greatly reduces the attack surface: even if a container escapes, the attacker is limited to the unprivileged user.

```bash
curl -fsSL https://get.docker.com/rootless | sh
systemctl --user start docker
```

Trade-offs: some features (low ports < 1024, certain network drivers, AppArmor) are restricted.

## Q60. What is a sensible production checklist?

**Answer:**

- Pinned image tags or digests
- Multi-stage builds; small final image
- Non-root user inside the container
- Resource limits (`--memory`, `--cpus`)
- Restart policy `unless-stopped`
- HEALTHCHECK defined
- Logs to stdout, with rotation configured
- Secrets via env or secret store, never baked in
- `.dockerignore` excludes `.git`, `node_modules`, secrets
- Image scanned for CVEs in CI
- Registry authentication via OIDC, not long-lived tokens
