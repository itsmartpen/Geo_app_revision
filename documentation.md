# CI/CD Pipeline

GitHub Actions builds, scans, and deploys this app on every push to `main`.
Workflow file: [.github/workflows/ci.yaml](.github/workflows/ci.yaml).

## Pipeline stages

1. **Build & test** — checkout, JDK 17, `mvn clean package` (compiles + runs unit tests, produces the jar).
2. **Source scan** — Trivy filesystem scan for vulnerable dependencies.
3. **SonarQube analysis** — scans the code via SonarCloud (sonarqube.io) using `sonar-maven-plugin`, then waits on the Quality Gate result.
4. **Docker build** — builds the image from the [Dockerfile](Dockerfile).
5. **Image scan** — Trivy scans the built image for CRITICAL/HIGH vulnerabilities.
6. **Push image** — pushes the same image to **GHCR** (`ghcr.io/<owner>/<repo>`) and **Amazon ECR** (private repo, created automatically if missing).
7. **Deploy** — bumps the Helm chart version, then `helm upgrade --install` against an EKS cluster, pulling the image from ECR.

## One-time setup

### 1. SonarCloud (sonarqube.io)
- Create an account/organization at https://sonarcloud.io and import this repository.
- The org key and host are already set in [pom.xml](pom.xml) (`sonar.organization`, `sonar.host.url`) — update them if you use a different org.
- Generate a token: **My Account → Security → Generate Token**.

### 2. GHCR
- No extra credentials needed — the workflow uses the built-in `GITHUB_TOKEN` (repo Settings → Actions → General → Workflow permissions must allow "Read and write permissions").
- Images publish to `ghcr.io/<owner>/<repo>`.

### 3. Amazon ECR + EKS
- Create an IAM user/role with permissions for ECR (push/pull) and EKS (`eks:DescribeCluster`, plus an entry in the cluster's `aws-auth`/access entries so the CI user can run `kubectl`/`helm`).
- Update `AWS_REGION` and `EKS_CLUSTER_NAME` at the top of [ci.yaml](.github/workflows/ci.yaml) to match your cluster.

### 4. GitHub Secrets
Add these under **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
|---|---|
| `SONAR_TOKEN` | SonarCloud authentication |
| `AWS_ACCESS_KEY_ID` | Push to ECR, deploy to EKS |
| `AWS_SECRET_ACCESS_KEY` | Push to ECR, deploy to EKS |

`GITHUB_TOKEN` is provided automatically by GitHub Actions for GHCR.

### 5. Runtime app secrets
The app reads mail/DB credentials from environment variables (`MAIL_USERNAME`, `MAIL_PASSWORD`, see [application.properties](src/main/resources/application.properties)) instead of hardcoded values. Supply real values in the cluster via a Kubernetes `Secret` and reference them from the Helm chart's deployment env, rather than committing them to the repo.

## Security note

A previous version of this repository had a real Gmail SMTP app password committed in `application.properties`. It has been replaced with an environment variable placeholder, but **the old value is still visible in git history** — rotate/revoke that Gmail app password now (Google Account → Security → App passwords) since it must be treated as compromised regardless of the code fix.

## Local development

```bash
mvn clean package
docker build -t geoapp:local .
docker run -p 8087:8087 -e MAIL_USERNAME=you@example.com -e MAIL_PASSWORD=your-app-password geoapp:local
```

## Helm chart

The chart lives in [geoapp/](geoapp/). The CI deploy step overrides `image.repository` and `image.tag` at deploy time, so [values.yaml](geoapp/values.yaml) only needs to hold sane local defaults.
