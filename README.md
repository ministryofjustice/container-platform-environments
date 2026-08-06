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
- **RoleBindings** per access group per namespace (binding built-in ClusterRoles: `view`, `edit`, `admin`)

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
  - group: github-my-team
    role: edit
    clusters:
      - container-platform-octo-nonlive
  - group: github-my-team
    role: view
    clusters:
      - container-platform-octo-live
```

2. Merge to `main`. The baseline ApplicationSet picks it up and creates namespaces, NetworkPolicies, and RoleBindings automatically.

## RBAC Permissions Model

Access to namespaces is managed through the `access` section in `product.yaml`. The chart binds groups to one of three built-in Kubernetes ClusterRoles per namespace.

### Permission levels

| Role | Grants | Secrets access | Typical use |
|------|--------|----------------|-------------|
| `view` | Read-only access to most objects | No | Live environments, stakeholders, on-call |
| `edit` | Read/write access to most objects | Yes | Development, debugging in non-live |
| `admin` | Edit + create Roles/RoleBindings | Yes | Namespace owners, platform engineers |

### Live vs non-live environments

| Environment | Default access | Rationale |
|-------------|---------------|-----------|
| Non-live | `edit` or `admin` | Developers need flexibility for development workflows |
| Live | `view` only | Workloads deploy via Argo CD; direct mutation is discouraged |

The chart **enforces** this: granting `edit` or `admin` on a production cluster (`is_production: true`) requires an explicit `live_access_justification` field on the access entry. Without it, the render fails.

```yaml
# This will fail:
access:
  - group: github-my-team
    role: edit
    clusters:
      - container-platform-octo-live   # is_production: true

# This passes (justification provided):
access:
  - group: github-my-team
    role: admin
    clusters:
      - container-platform-octo-live
    live_access_justification: "Platform engineers require admin for incident response"
```

### Group naming convention

Groups use the format `github-<org>-<team>`, matching the GitHub team structure:

| GitHub team | Group name in `product.yaml` |
|-------------|------------------------------|
| `ministryofjustice/laa-developers` | `github-laa-developers` |
| `ministryofjustice/hmpps-dev-team` | `github-hmpps-dev-team` |
| `ministryofjustice/cloud-platform` | `github-cloud-platform` |

The `group` field must match the Kubernetes group name mapped by the EKS access entry (managed in `identity/terraform/`).

### Validation

The chart validates access declarations at render time:

| Check | Behaviour |
|-------|-----------|
| Role must be `view`, `edit`, or `admin` | Render fails with actionable error |
| `edit`/`admin` on a production cluster | Render fails unless `live_access_justification` is provided |

## Adding a Service Deployment

1. Create a Helm chart at `namespaces/<bu>/<product>/<service>/deployment/`
2. Add per-environment values at `deployment/values/nonlive/dev.yaml` (and/or `staging.yaml`, `prod.yaml`)
3. Each values file must include a `namespace` key matching the namespace declared in `product.yaml`
4. Merge to `main`. The workload ApplicationSet creates an ArgoCD Application per values file.

## Testing

The `app-baseline` chart has unit tests using [helm-unittest](https://github.com/helm-unittest/helm-unittest). These validate template rendering and policy enforcement without requiring a deployed cluster.

### Running tests locally

```bash
# Install the plugin (one-time)
helm plugin install https://github.com/helm-unittest/helm-unittest.git

# Run the tests
helm unittest ./charts/app-baseline
```

### Test structure

```
charts/app-baseline/tests/
├── fixtures/
│   └── helloworld-nonlive.yaml   # Shared test values
├── rolebinding_test.yaml          # RoleBinding rendering correctness
└── validation_test.yaml           # Access policy enforcement
```

### What's tested

| Suite | Covers |
|-------|--------|
| `validation_test.yaml` | Invalid role names rejected, live=view-only enforced, justification escape hatch works |
| `rolebinding_test.yaml` | Correct binding name, namespace targeting, ClusterRole ref, group subject, labels, empty-input handling |

### Adding new tests

Test files go in `charts/app-baseline/tests/` with the suffix `_test.yaml`. Each test provides values via `set:` and asserts on the rendered output. To test failure cases, use `failedTemplate` with the expected error message. See existing tests for examples.

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
