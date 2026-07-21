# Identity

This folder contains the Terraform configuration that manages identity and access for the Container Platform environments.

It does two things:

1. Creates AWS IAM Identity Center permission sets and account assignments for product teams.
2. Creates EKS access entries so those permission set roles can reach the correct clusters and Kubernetes groups.

## Architecture

The solution is described in the container platform identity architecture diagram:

![Container Platform Identity architecture](https://github.com/ministryofjustice/cloud-platform/blob/main/architecture/container-platform/diagrams/container-platform-Identity.png?raw=true)

Product manifests in `../namespaces/<bu>/<product>/product.yaml` declare access groups and target clusters. Terraform derives the unique teams and cluster combinations, then creates the matching permission sets and EKS access entries.

The example product below is typical of the inputs this code consumes:

```yaml
product: helloworld
bu: octo
owner:
  team: cloud-platform
  slack: "#cloud-platform"

environments:
  - name: dev
    cluster: container-platform-octo-nonlive
    namespace: helloworld-dev
    is_production: false

access:
  - group: cloud-platform-engineers
    role: edit
    clusters:
      - container-platform-octo-nonlive
      - container-platform-octo-live
```

## How it works

### Input discovery

Terraform scans `../namespaces/**/product.yaml` and decodes each manifest. Each manifest is expected to have a top-level `product` field and an `access` list.

From that data it derives:

- All unique access groups across all products (`local.namespace_access_teams`)
- All team-cluster combinations that need access (`local.namespace_team_cluster_keys`)
- The permission set name for each team, using the `cp-` prefix and normalising spaces, underscores, and dots to hyphens

### Permission sets and assignments

For every access group referenced by a product manifest, Terraform creates an IAM Identity Center permission set with:

- An inline policy that allows `eks:AccessKubernetesApi`, `eks:Describe*`, `eks:Get*`, and `eks:List*`
- Account assignments for the AWS accounts backing the clusters the team is allowed to reach

The shared `cp-user-eks-readonly` permission set is also assigned to `cloud-platform-engineers` across all clusters, so CP engineers can access any cluster using the same read-only permissions.

### EKS access entries

For each provisioned account assignment, Terraform creates an EKS access entry in the corresponding cluster account. The access entry resolves the `AWSReservedSSO` role created for the permission set and maps it to a Kubernetes group matching the team name.

This only provides authentication to the cluster. Kubernetes RBAC (RoleBindings) is managed separately by the `app-baseline` Helm chart, which creates RoleBindings per access group per namespace based on the `role` field in `product.yaml`.

### Identity and AWS providers

The configuration assumes different AWS roles depending on the operation:
- **Plan**: `github-actions-container-platform-identity-plan` (read-only)
- **Apply**: `github-actions-container-platform-identity-apply` (SSO admin)

It reads the `environment_management` secret from the Modernisation Platform account to resolve account IDs for target environments.

## Prerequisites

Before running Terraform, the following must already exist:

- The `environment_management` secret with account IDs for the relevant clusters
- The AWS SSO/Identity Center instance in the target management account
- The `ContainerPlatformEKSAccess` role in each spoke cluster account
- Product manifests under `../namespaces/<bu>/<product>/product.yaml` with valid `product`, `access`, and `clusters` fields
