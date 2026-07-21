# Container Platform Environments

[![Ministry of Justice Repository Compliance Badge](https://github-community.service.justice.gov.uk/repository-standards/api/container-platform-environments/badge)](https://github-community.service.justice.gov.uk/repository-standards/container-platform-environments)

This repository is the source of truth for workload namespaces and deployments on the Container Platform (CP3). ArgoCD on the hub cluster watches this repo and automatically provisions namespace baselines and syncs application manifests to spoke clusters.

## Repository Structure

```
container-platform-environments/
├── charts/
│   └── app-baseline/              # Helm chart: Namespace + NetworkPolicy + RoleBindings
├── namespaces/
│   └── <bu>/                      # One directory per Business Unit
│       └── <product>/             # One directory per product
│           ├── product.yaml       # Product declaration (environments, access, ownership)
│           ├── resources/         # Terraform-managed AWS resources (future)
│           └── <service>/         # One directory per service/component
│               └── deployment/    # Helm chart for the service
│                   ├── Chart.yaml
│                   ├── templates/
│                   ├── values.yaml
│                   └── values/
│                       ├── nonlive/   # Per-environment overrides (dev.yaml, staging.yaml)
│                       └── live/      # Per-environment overrides (prod.yaml)
├── identity/
│   └── terraform/                 # SSO permission sets and EKS access entries
└── scripts/
```

## How It Works

Two separate ArgoCD ApplicationSets consume this repo per BU per cluster tier (nonlive/live):

### 1. Baseline ApplicationSet (namespace provisioning)

Watches `namespaces/<bu>/*/product.yaml` using a git-file-generator. For each product it finds, it renders `charts/app-baseline` with the product's environments, access groups, and metadata. This creates:

- **Namespace** per environment on the target cluster (with standard labels)
- **Default-deny NetworkPolicy** per namespace
- **RoleBindings** per access group per namespace

Runs under the `platform-<env>` AppProject which has permission to create cluster-scoped resources (Namespaces).

### 2. Workload ApplicationSet (application deployment)

Watches `namespaces/<bu>/*/*/deployment/values/<tier>/*.yaml` using a git-file-generator. Each values file (e.g., `dev.yaml`, `prod.yaml`) produces an ArgoCD Application that renders the service's Helm chart with that environment's overrides.

Runs under the `<bu>-<env>` AppProject which is restricted to namespaced workload resources only.

## Key Design Decisions

### Why `CreateNamespace=false`

Both ApplicationSets set `CreateNamespace=false` in their sync options. Namespaces are created exclusively by the baseline ApplicationSet via the `app-baseline` chart, not by workload syncs. This ensures:

- Every namespace has mandatory labels, NetworkPolicy, and RoleBindings before any workload lands
- BU workload AppProjects cannot create Namespaces (enforced by `clusterResourceBlacklist`)
- A product cannot deploy without first declaring itself in `product.yaml`

If a workload sync targets a namespace that doesn't exist, ArgoCD reports it as degraded until the baseline creates it — this is intentional.

### BU isolation via AppProjects

Each BU gets separate nonlive and live AppProjects. These enforce:
- **sourceRepos**: Only this repository
- **destinations**: Only that BU's spoke cluster
- **namespaceResourceWhitelist**: Workload resources only (Deployments, Services, ConfigMaps, etc.)
- **clusterResourceBlacklist**: Cannot create Namespace, ClusterRole, ClusterRoleBinding, or CRDs

### Sync behaviour

| Tier | Auto-sync | Prune | Self-heal |
|------|-----------|-------|-----------|
| nonlive (baselines) | Yes | Yes | Yes |
| nonlive (workloads) | Yes | Yes | Yes |
| live (baselines) | Yes | Yes | Yes |
| live (workloads) | No (manual sync required) | — | — |

## Adding a New Product

1. Create `namespaces/<bu>/<product>/product.yaml`:

```yaml
product: my-product
bu: octo
owner:
  team: my-team
  slack: "#my-team-channel"
  source: https://github.com/ministryofjustice/container-platform-environments

environments:
  - name: dev
    cluster: container-platform-octo-nonlive
    namespace: my-product-dev
    is_production: false
  - name: prod
    cluster: container-platform-octo-live
    namespace: my-product-prod
    is_production: true

access:
  - group: my-team
    role: edit
    clusters:
      - container-platform-octo-nonlive
      - container-platform-octo-live
```

2. Merge to `main`. The baseline ApplicationSet picks it up and creates namespaces, NetworkPolicies, and RoleBindings automatically.

## Adding a Service Deployment

1. Create a Helm chart at `namespaces/<bu>/<product>/<service>/deployment/`
2. Add per-environment values at `deployment/values/nonlive/dev.yaml` (and/or `staging.yaml`, `prod.yaml`)
3. Each values file must include a `namespace` key matching the namespace declared in `product.yaml`
4. Merge to `main`. The workload ApplicationSet creates an ArgoCD Application per values file.

## Identity (SSO and EKS Access)

The `identity/terraform/` directory manages AWS IAM Identity Center permission sets and EKS access entries. It reads all `product.yaml` files and:

- Creates an SSO permission set per unique access group (e.g., `cp-my-team`)
- Creates EKS access entries linking the SSO group to the declared clusters
- Assigns read-only AWS + EKS viewer permissions

Deployed via separate GitHub Actions workflows (`identity-plan.yml` / `identity-apply.yml`).

## References

- [ADR-002: GitOps Fleet Management](https://github.com/ministryofjustice/cloud-platform-eks-modernisation) — Hub-and-spoke ArgoCD model
- [ADR-015: GitOps Repository Structure](https://github.com/ministryofjustice/cloud-platform-eks-modernisation) — Per-BU repo layout decision
- [US-015b: Spoke Registration and GitOps Configuration](https://github.com/ministryofjustice/cloud-platform/issues/8270)
