# GitHub Actions self-hosted runner pool

This recipe provisions **N GitHub Actions self-hosted runners on one Debian/Ubuntu host** so multiple jobs can run concurrently.

> One self-hosted runner executes one job at a time. Multiple runner instances increase concurrency, but all jobs still share host CPU, memory, disk, Docker, and network.

## Prerequisites

Generate a fresh registration token immediately before running the recipe:

- **Organization runner:** Organization → Settings → Actions → Runners → New self-hosted runner
- **Repository runner:** Repository → Settings → Actions → Runners → New self-hosted runner

## Example: two organization runners

```bash
curl -fsSL https://raw.githubusercontent.com/aiherrera/vps-hardener/main/recipes/github-actions-runners.sh -o /tmp/github-actions-runners.sh

sudo RUNNER_COUNT=2 \
  GITHUB_URL=https://github.com/Lynsoft \
  RUNNER_TOKEN='<fresh-token>' \
  RUNNER_PREFIX=lynsoft-ci-01 \
  RUNNER_LABELS=lynsoft,ci \
  bash /tmp/github-actions-runners.sh
```

This creates `/home/github-runner/actions-runner-01`, `/home/github-runner/actions-runner-02` and registers runners `lynsoft-ci-01-01` and `lynsoft-ci-01-02`.

## Variables

| Variable | Required | Default | Description |
|---|---:|---|---|
| `RUNNER_COUNT` | yes | — | Number of runner instances |
| `GITHUB_URL` | yes | — | Organization or repository URL |
| `RUNNER_TOKEN` | yes | — | Fresh registration token |
| `RUNNER_USER` | no | `github-runner` | Linux service account |
| `RUNNER_PREFIX` | no | hostname | Prefix for runner names |
| `RUNNER_LABELS` | no | empty | Comma-separated custom labels |
| `RUNNER_GROUP` | no | `Default` | GitHub runner group |
| `RUNNER_BASE_DIR` | no | `/home/$RUNNER_USER` | Parent directory |
| `RUNNER_VERSION` | no | latest | Pin actions/runner version |
| `INSTALL_DOCKER` | no | `true` | Install/enable Docker and grant runner Docker access |

## Capacity guidance

There is no fixed runners-per-host formula; workflow load is the real limit. For a **4 vCPU / 8 GB RAM** CI host, start with **2 runners**, measure representative peak CPU/RAM/I/O, and only then increase.

Docker-heavy jobs share one Docker daemon. Workflows that launch services with fixed ports or names (for example local Supabase) can collide. Isolate per runner or serialize those jobs with GitHub Actions `concurrency`.

## Service management

```bash
systemctl list-units --type=service --all 'actions.runner.*'
```

```bash
journalctl -u 'actions.runner.*' -n 100 --no-pager
```

Do not run `./run.sh` manually after installing services, or GitHub can report a duplicate runner session.

## Security notes

- Use only for trusted repositories/workflows.
- Docker group membership is effectively root-equivalent.
- Prefer a dedicated CI server rather than sharing production.
- Scope labels and runner groups so sensitive jobs only land on intended machines.