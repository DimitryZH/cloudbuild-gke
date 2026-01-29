# GKE Cloud Build to GKE Demo

End‑to‑end CI/CD example for a minimal Go web service deployed to Google Kubernetes Engine (GKE) using Google Cloud Build, Artifact Registry, and environment‑specific Kubernetes manifests. This repository is intended as a portfolio‑ready reference implementation for DevOps / Cloud Engineering practices on Google Cloud.

The application is a tiny HTTP server implemented in [`main.go`](main.go) that serves a dynamically generated blue PNG image at the `/blue` endpoint. Container images are built by Cloud Build using the multi‑stage [`Dockerfile`](Dockerfile) and deployed into `dev` and `prod` namespaces via simple Kubernetes `Deployment` manifests.

---

## Key Features

- Minimal but realistic Go microservice: [`main()`](main.go:11) and [`blueHandler()`](main.go:16) expose an HTTP endpoint returning an in‑memory PNG.
- Multi‑stage container build using Distroless runtime image for secure, small containers.
- GitHub‑driven CI/CD with separate Cloud Build configurations for development and production:
  - [`cloudbuild-dev.yaml`](cloudbuild-dev.yaml) for the `dev` branch.
  - [`cloudbuild.yaml`](cloudbuild.yaml) for the `main` branch.
- Automated Docker image build and push to Artifact Registry for each environment.
- Kubernetes `Deployment` manifests for `dev` and `prod` namespaces:
  - [`dev/deployment.yaml`](dev/deployment.yaml).
  - [`prod/deployment.yaml`](prod/deployment.yaml).
- Clear separation of concerns between application code, containerization, CI/CD, and Kubernetes manifests.
- Demonstrates safe rollout patterns and rollback via Kubernetes deployment history.

---

## Tech Stack

**Languages & Runtime**

- Go 1.19 (`net/http`, `image`, `image/png`).

**Containerization**

- Docker multi‑stage builds defined in [`Dockerfile`](Dockerfile).
- Distroless base image `gcr.io/distroless/base-debian11` for minimal runtime surface.

**CI/CD & Registry**

- Google Cloud Build with YAML configurations:
  - [`cloudbuild.yaml`](cloudbuild.yaml) (production).
  - [`cloudbuild-dev.yaml`](cloudbuild-dev.yaml) (development).
- Google Artifact Registry for storing versioned Docker images.

**Orchestration**

- Google Kubernetes Engine (GKE) standard cluster.
- Kubernetes `Deployment` resources for dev/prod:
  - [`dev/deployment.yaml`](dev/deployment.yaml).
  - [`prod/deployment.yaml`](prod/deployment.yaml).

**Source Control & Triggers**

- GitHub repository with branch‑based Cloud Build triggers:
  - `dev` branch → development pipeline.
  - `main` branch → production pipeline.

---

## Repository Structure

High‑level layout:

```text
.
├── Dockerfile                # Multi-stage build for Go binary and distroless runtime image
├── main.go                   # Simple Go HTTP server serving a blue PNG at /blue
├── cloudbuild.yaml           # Cloud Build config for production (main branch)
├── cloudbuild-dev.yaml       # Cloud Build config for development (dev branch)
├── dev/
│   └── deployment.yaml       # Kubernetes Deployment for the dev namespace
├── prod/
│   └── deployment.yaml       # Kubernetes Deployment for the prod namespace
└── Readme.md                 # Project documentation (this file)
```

Key files (clickable):

- Application: [`main.go`](main.go)
- Container build: [`Dockerfile`](Dockerfile)
- CI/CD configs: [`cloudbuild.yaml`](cloudbuild.yaml), [`cloudbuild-dev.yaml`](cloudbuild-dev.yaml)
- Kubernetes manifests: [`dev/deployment.yaml`](dev/deployment.yaml), [`prod/deployment.yaml`](prod/deployment.yaml)

---

## Installation / Setup

### Prerequisites

- A Google Cloud project with billing enabled.
- `gcloud` CLI installed and authenticated.
- `kubectl` installed and configured.
- Access to create and manage:
  - GKE clusters.
  - Cloud Build triggers.
  - Artifact Registry repositories.
  - GitHub repository connected to Cloud Build.

Optional for local testing:

- Go 1.19+ installed locally.
- Docker installed locally.

### 1. Enable Required APIs

```sh
gcloud services enable \
  container.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com
```

### 2. Create Artifact Registry Repository

```sh
export PROJECT_ID="$(gcloud config get-value project)"
gcloud artifacts repositories create my-repository \
  --repository-format=docker \
  --location=us-east1 \
  --description="Demo Docker repository for Cloud Build → GKE pipeline"

gcloud auth configure-docker us-east1-docker.pkg.dev
```

### 3. Provision GKE Cluster and Namespaces

```sh
gcloud container clusters create my-cluster \
  --zone=us-east1-d \
  --release-channel=regular \
  --enable-autoscaling \
  --min-nodes=2 \
  --max-nodes=6 \
  --num-nodes=3

gcloud container clusters get-credentials my-cluster --zone=us-east1-d

kubectl create namespace dev
kubectl create namespace prod
```

### 4. Grant Cloud Build Permissions to Deploy to GKE

```sh
PROJECT_ID="$(gcloud config get-value project)"
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/container.developer"
```

### 5. Connect GitHub Repository and Configure Triggers

1. Create a GitHub repository and push this source code.
2. In the Cloud Console, connect the repo to Cloud Build.
3. Create two triggers:
   - **Dev trigger**
     - Event: Push to branch `^dev$`
     - Config: [`cloudbuild-dev.yaml`](cloudbuild-dev.yaml)
   - **Prod trigger**
     - Event: Push to branch `^main$`
     - Config: [`cloudbuild.yaml`](cloudbuild.yaml)

---

## Usage / Execution

### Run Locally (Without Docker)

```sh
go run main.go
```

Then request the endpoint:

```sh
curl -v http://localhost:8080/blue --output blue.png
```

You should receive a 100x100 blue PNG.

### Run Locally in Docker

```sh
docker build -t local/cloudbuild-gke-demo:latest .
docker run --rm -p 8080:8080 local/cloudbuild-gke-demo:latest
```

Request the same `/blue` endpoint as above.

### Deploy via Cloud Build (Dev / Prod)

Typical flow:

1. Commit changes on the `dev` branch.
2. Push to GitHub → dev Cloud Build trigger runs [`cloudbuild-dev.yaml`](cloudbuild-dev.yaml):
   - Builds the Go binary.
   - Builds and tags the Docker image as `cloudbuild-dev:v1.0` (or another version you configure).
   - Pushes the image to Artifact Registry.
   - Applies [`dev/deployment.yaml`](dev/deployment.yaml) into the `dev` namespace.
3. Once validated, merge to `main`.
4. Push to `main` → prod Cloud Build trigger runs [`cloudbuild.yaml`](cloudbuild.yaml) and deploys to the `prod` namespace using [`prod/deployment.yaml`](prod/deployment.yaml).

You can also invoke a build manually:

```sh
gcloud builds submit --config=cloudbuild-dev.yaml .
gcloud builds submit --config=cloudbuild.yaml .
```

---

## Architecture Overview

At a high level, the system consists of:

- A developer pushing code to GitHub (`dev` / `main` branches).
- Cloud Build triggers that build and push images to Artifact Registry.
- A GKE cluster with `dev` and `prod` namespaces.
- Kubernetes `Deployment` resources running the Go container.
- (Optionally) Kubernetes `Service` resources of type `LoadBalancer` to expose the app externally.

### System / Architecture Diagram (Mermaid)

```mermaid
graph TD
  Dev[Developer] -->|git push (dev/main)| GH[GitHub Repository]
  GH -->|Cloud Build trigger| CB[Google Cloud Build]
  CB -->|Build & Push Image| AR[(Artifact Registry)]
  AR -->|Pull Image| GKE[GKE Cluster]
  GKE -->|Pods in dev namespace| DevNS[dev namespace / Deployment]
  GKE -->|Pods in prod namespace| ProdNS[prod namespace / Deployment]
  DevUser[Dev / QA User] --> DevSvc[dev Service (LoadBalancer)] --> DevNS
  EndUser[End User] --> ProdSvc[prod Service (LoadBalancer)] --> ProdNS
```

---

## Data Flow Overview

The application itself has a very small request path:

1. A client sends an HTTP `GET /blue` request to the LoadBalancer Service.
2. The request is routed to one of the Pods in the target `Deployment`.
3. The Go handler [`blueHandler()`](main.go:16) creates a 100x100 `RGBA` image, fills it with blue, encodes it as PNG, and writes it to the response body with `Content-Type: image/png`.

### Application / Infrastructure Flowchart (Mermaid)

```mermaid
flowchart LR
  Client[Client Browser / curl] --> LB[LoadBalancer Service]
  LB --> Pod[Go App Pod]
  Pod --> Handler[blueHandler()]
  Handler --> Img[Generate 100x100 Blue PNG]
  Img --> Resp[HTTP Response image/png]
```

### Dataflow Diagram (Mermaid)

```mermaid
graph LR
  Req[HTTP Request /blue] --> SVC[Service]
  SVC --> POD[Go Container]
  POD --> FUNC[blueHandler()]
  FUNC --> IMG[image.RGBA Buffer]
  IMG --> PNG[PNG Encoder]
  PNG --> OUT[HTTP Response Body]
```

---

## CI/CD and Automation Flow

The CI/CD pipeline is defined by [`cloudbuild-dev.yaml`](cloudbuild-dev.yaml) and [`cloudbuild.yaml`](cloudbuild.yaml).

### Dev Pipeline (`cloudbuild-dev.yaml`)

Steps:

1. **Compile Go application** using `gcr.io/cloud-builders/go`.
2. **Build Docker image** tagged as `cloudbuild-dev:v1.0` (or version of your choice).
3. **Push image** to Artifact Registry.
4. **Deploy to GKE** by applying [`dev/deployment.yaml`](dev/deployment.yaml) into the `dev` namespace using `gcr.io/cloud-builders/kubectl`.

### Prod Pipeline (`cloudbuild.yaml`)

Steps:

1. **Compile Go application**.
2. **Build Docker image** tagged as `cloudbuild:v1.0` (or version of your choice).
3. **Push image** to Artifact Registry.
4. **Deploy to GKE** by applying [`prod/deployment.yaml`](prod/deployment.yaml) into the `prod` namespace.

Both pipelines set environment variables to ensure `kubectl` points at the correct region and cluster:

- `CLOUDSDK_COMPUTE_REGION=us-east1-d`
- `CLOUDSDK_CONTAINER_CLUSTER=my-cluster`

### CI/CD Pipeline Diagram (Mermaid)

```mermaid
flowchart LR
  DevBranch[Commit to dev] --> DevTrig[Cloud Build Trigger (dev)]
  MainBranch[Commit to main] --> ProdTrig[Cloud Build Trigger (prod)]

  subgraph DevPipeline[Dev Pipeline]
    DevTrig --> DevBuild[Go Build]
    DevBuild --> DevDocker[Docker Build]
    DevDocker --> DevPush[Push to Artifact Registry]
    DevPush --> DevDeploy[kubectl apply dev/deployment.yaml]
  end

  subgraph ProdPipeline[Prod Pipeline]
    ProdTrig --> ProdBuild[Go Build]
    ProdBuild --> ProdDocker[Docker Build]
    ProdDocker --> ProdPush[Push to Artifact Registry]
    ProdPush --> ProdDeploy[kubectl apply prod/deployment.yaml]
  end

  DevDeploy --> DevGKE[Dev Namespace Pods]
  ProdDeploy --> ProdGKE[Prod Namespace Pods]
```

### Rollback Strategy

Rollbacks are managed at the Kubernetes level using `Deployment` revision history. For example:

```sh
kubectl rollout undo deployment/production-deployment --to-revision=1 -n prod
```

This pairs well with Cloud Build build history and Git history to audit what changed between revisions.

---

## Future Improvements

This repository is intentionally minimal but can be extended in several portfolio‑friendly directions:

- Add a Kubernetes `Service` and `Ingress`/`Gateway` manifests to fully define external exposure.
- Parameterize image tags (e.g., using `$SHORT_SHA`) instead of fixed `v1.0` to better reflect real‑world CI/CD.
- Introduce separate overlays (e.g., Kustomize or Helm) for dev/stage/prod.
- Add automated tests executed in a pre‑build Cloud Build step.
- Integrate Policy Controller / Gatekeeper for admission control on deployments.
- Add monitoring and logging dashboards (Cloud Monitoring, Cloud Logging) documentation.
- Introduce canary or blue‑green deployment strategies using additional Deployments and Services.

---

## Author

**Your Name**  
DevOps / Cloud Engineer

Feel free to fork and adapt this project to showcase your own Google Cloud and Kubernetes CI/CD practices.