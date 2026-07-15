# Container Platform Environments — OCTO

[![Ministry of Justice Repository Compliance Badge](https://github-community.service.justice.gov.uk/repository-standards/api/container-platform-environments/badge)](https://github-community.service.justice.gov.uk/repository-standards/container-platform-environments)

This repository contains workload deployment configuration for the **OCTO** Business Unit on the Container Platform (CP3). It is the source of truth for ArgoCD ApplicationSets that deploy workloads to OCTO's spoke clusters.

## Repository Structure (ADR-015)

```
container-platform-environments/
├── _bu-config.yaml                 # BU metadata and access config
├── hello-world/                    # One directory per application
│   ├── app.yaml                    # Application metadata (team, slack, source)
│   ├── namespaces.yaml             # Namespace declarations
│   └── deployment/
│       ├── nonlive/                # K8s manifests → synced to octo-nonlive cluster
│       │   ├── deployment.yaml
│       │   └── service.yaml
│       └── live/                   # K8s manifests → synced to octo-live cluster
│           ├── deployment.yaml
│           └── service.yaml
├── namespaces/                     # (Legacy) Early namespace onboarding PoC
│   └── octo/
└── identity/                       # (Legacy) Identity configuration PoC
```

## How ArgoCD Uses This Repo

The hub cluster's ApplicationSet watches this repo using a **git-directory-generator** with path pattern `*/deployment/<environment>`. When a new app directory appears (e.g., `my-app/deployment/nonlive/`), ArgoCD automatically:

1. Creates an Application named `octo-my-app-nonlive`
2. Syncs the K8s manifests from that directory to the OCTO non-live spoke cluster
3. Creates the namespace automatically (`CreateNamespace=true`)

Non-live environments use **auto-sync** (changes to `main` deploy immediately). Live environments require **manual sync** (explicit approval in ArgoCD UI).

## Adding a New Application

1. Create a directory at the repo root: `my-app/`
2. Add `app.yaml` with team metadata
3. Add `namespaces.yaml` with namespace declarations
4. Add `deployment/nonlive/` with your K8s manifests (Deployment, Service, etc.)
5. Merge to `main` — ArgoCD picks it up automatically

## AppProject Restrictions

This repo is the **only** source ArgoCD will accept for OCTO workloads. The `octo-nonlive` AppProject enforces:
- `sourceRepos`: Only this repository
- `destinations`: Only the OCTO non-live cluster ARN
- `clusterResourceBlacklist`: Cannot create Namespace, ClusterRole, ClusterRoleBinding, or CRDs directly

## Legacy Structure

The `namespaces/` and `identity/` directories are from an earlier PoC exploring namespace onboarding patterns. They use a custom YAML format (not K8s manifests) and are not consumed by ArgoCD. These will be migrated or removed as the platform matures.

## References

- [ADR-002: GitOps Fleet Management](https://github.com/ministryofjustice/cloud-platform-eks-modernisation) — Hub-and-spoke ArgoCD model
- [ADR-015: GitOps Repository Structure](https://github.com/ministryofjustice/cloud-platform-eks-modernisation) — Per-BU repo layout decision
- [US-015b: Spoke Registration and GitOps Configuration](https://github.com/ministryofjustice/cloud-platform/issues/8270)
