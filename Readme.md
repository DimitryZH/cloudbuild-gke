# GKE CI/CD Pipeline with Cloud Build and GitHub

## Overview

This project demonstrates how to set up a CI/CD pipeline for a Go application using Google Kubernetes Engine (GKE), Cloud Build, and GitHub. By following this guide, you will automate the process of building, testing, and deploying your application to a GKE cluster whenever you push changes to your GitHub repository. This ensures that your application is always up-to-date and running the latest version in both development and production environments.

## Table of Contents

This project includes the following tasks:

1. [Initialize Resources](#task-1-initialize-resources)
2. [Create a Repository in GitHub](#task-2-create-a-repository-in-github)
3. [Create Cloud Build Triggers](#task-3-create-cloud-build-triggers)
4. [Deploy the First Versions](#task-4-deploy-the-first-versions)
5. [Deploy the Second Versions](#task-5-deploy-the-second-versions)
6. [Roll Back the Production Deployment](#task-6-roll-back-the-production-deployment)
7. [Conclusion](#conclusion)

Overall, you will create a simple CI/CD pipeline using GitHub Repositories, Artifact Registry, and Cloud Build.

## Task 1: Initialize Resources

Initialize your Google Cloud project for the demo environment by enabling required APIs, configuring Git in Cloud Shell, creating an Artifact Registry Docker repository, and creating a GKE cluster.

### Commands:
- Enable APIs:
  ```sh
  gcloud services enable container.googleapis.com cloudbuild.googleapis.com
  ```
- Add Kubernetes Developer role:
  ```sh
  export PROJECT_ID=$(gcloud config get-value project)
  gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member=serviceAccount:$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")@cloudbuild.gserviceaccount.com --role="roles/container.developer"
  ```
- Create Artifact Registry Docker repository:
  ```sh
  gcloud services enable artifactregistry.googleapis.com
  gcloud artifacts repositories create my-repository --repository-format=docker --location=us-east1 --description="My Docker repository"
  gcloud artifacts repositories list --location=us-east1
  gcloud auth configure-docker us-east1-docker.pkg.dev
  ```
- Create GKE Standard cluster:
  ```sh
  gcloud container clusters create my-cluster \
      --zone=us-east1-d \
      --release-channel=regular \
      --cluster-version=1.29 \
      --enable-autoscaling \
      --min-nodes=2 \
      --max-nodes=6 \
      --num-nodes=3
  ```
- Configure `kubectl`:
  ```sh
  gcloud container clusters get-credentials my-cluster --zone=us-east1-d
  ```
- Create namespaces:
  ```sh
  kubectl config use cluster my-cluster
  kubectl create namespace prod
  kubectl create namespace dev
  kubectl get namespaces
  ```

## Task 2: Create a Repository in GitHub

### Steps:
- Create an empty repository named `gke-app`.
- Clone the repository in Cloud Shell or local Git repo.
- Replace placeholders in YAML files:
  ```sh
  export REGION="REGION"
  export ZONE="ZONE"
  for file in sample-app/cloudbuild-dev.yaml gke-app/cloudbuild.yaml; do
      sed -i "s/<your-region>/${REGION}/g" "$file"
      sed -i "s/<your-zone>/${ZONE}/g" "$file"
  done
  ```
- Configure Git and GitHub:
  ```sh
  curl -sS https://webi.sh/gh | sh
  gh auth login
  gh api user -q ".login"
  GITHUB_USERNAME=$(gh api user -q ".login")
  git config --global user.name "${GITHUB_USERNAME}"
  git config --global user.email "${USER_EMAIL}"
  ```
- Make the first commit and push changes to the `main` and `dev` branches.

## Task 3: Create Cloud Build Triggers

Create two Cloud Build Triggers for the `main` and `dev` branches.

### Configurations:
- **Production Trigger**:
  - Event: Push to a branch
  - Connect GitHub project repo
  - Branch: `^main$`
  - Configuration File: `cloudbuild.yaml`
- **Development Trigger**:
  - Event: Push to a branch
  - Connect GitHub project repo
  - Branch: `^dev$`
  - Configuration File: `cloudbuild-dev.yaml`

## Task 4: Deploy the First Versions

Build and deploy the first versions of the production and development applications.

### Steps:
- Update `cloudbuild-dev.yaml` and `dev/deployment.yaml` for version `v1.0` in dev branch.
- Commit and push changes to the `dev` branch.
- Expose the development deployment:
  ```sh
  kubectl expose deployment development-deployment \
    --type=LoadBalancer \
    --name=dev-deployment-service \
    --port=8080 \
    --target-port=8080 \
    -n dev
  ```
- Update `cloudbuild.yaml` and `prod/deployment.yaml` for version `v1.0` in main branch.
- Commit and push changes to the `main` branch.
- Expose the production deployment:
  ```sh
  kubectl expose deployment production-deployment \
    --type=LoadBalancer \
    --name=prod-deployment-service \
    --port=8080 \
    --target-port=8080 \
    -n prod
  ```

## Task 5: Deploy the Second Versions

Build and deploy the second versions of the production and development applications.

### Steps:
- Update `main.go` and `cloudbuild-dev.yaml` for version `v2.0`.
- Commit and push changes to the `dev` branch.
- Update `main.go` and `cloudbuild.yaml` for version `v2.0`.
- Commit and push changes to the `main` branch.

## Task 6: Roll Back the Production Deployment

Roll back the production deployment to a previous version using Cloud Build history.

```sh
kubectl rollout undo deployment/production-deployment --to-revision=1 -n prod
```

### Verify the Rollback:
1. Check the image being used by the pods:
   ```sh
   kubectl describe deployment/production-deployment -n prod | grep Image
   ```
   Confirm that it is `us-east1-docker.pkg.dev/$PROJECT_ID/my-repository/cloudbuild:v1.0`.

2. Check Rollout Status:
   ```sh
   kubectl rollout status deployment/production-deployment -n prod
   ```
   This will show you the status of the rollback. It should indicate that the rollout was successful.

3. Check Pods:
   ```sh
   kubectl get pods -n prod -o wide
   ```
   Confirm that the pods are running and using the `v1.0` image.

### Rollback to the Correct Revision:
Once you've identified the revision number associated with `v1.0`, use the `kubectl rollout undo` command to roll back:

```sh
kubectl rollout undo deployment/production-deployment --to-revision=<REVISION_NUMBER> -n prod
```
Replace `<REVISION_NUMBER>` with the actual revision number.

## Conclusion

In this project, you implemented DevOps workflows in Google Cloud. You created a GKE cluster, a GitHub repository, Cloud Build Triggers, and deployed applications. You also pushed updates and rolled back the production application to a previous version.
