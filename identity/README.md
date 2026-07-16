# Identity

This folder contains the Terraform configuration that manages identity and access for the Container Platform environments.

It does two things:

1. Creates AWS IAM Identity Center permission sets and account assignments for namespace teams.
2. Creates EKS access entries so those permission set roles can reach the right clusters and Kubernetes groups.

## Architecture

The solution is described in the container platform identity architecture diagram:

![Container Platform Identity architecture](https://github.com/ministryofjustice/cloud-platform/blob/main/architecture/container-platform/diagrams/container-platform-Identity.png?raw=true)

At a high level, namespace manifests in `../namespaces/**/namespace.yaml` define access, Terraform derives the teams and clusters that need it, and then the configuration creates the matching permission sets and EKS access entries.

The example namespace below is typical of the inputs this code consumes:

```yaml
name: example-app
namespaces:
  - name: example-app-dev
    access:
      - cloud-platform-engineers
      - cloud-platform
    cluster: container-platform-octo-nonlive
```

## How it works

### Input discovery

Terraform scans `../namespaces/**/namespace.yaml` and decodes each manifest. Each manifest is expected to have a top-level `name` field and a `namespaces` list.

From that data it derives:

- all unique namespace access teams
- all unique cluster names
- all team and cluster combinations that need access
- the permission set name for each team, using the `cp-` prefix and normalising spaces, underscores, and dots to hyphens

### Permission sets and assignments

For every team referenced by a namespace manifest, Terraform creates an IAM Identity Center permission set with:

- `ReadOnlyAccess` as the AWS managed policy
- an inline policy that allows `eks:AccessKubernetesApi`, `eks:Describe*`, `eks:Get*`, and `eks:List*`
- account assignments for the AWS account or accounts that back the clusters the team is allowed to reach

The shared `cp-user-eks-readonly` permission set is also assigned to `cloud-platform-engineers`, so cp engineers can access any cluster using the same permissions as a user.

### EKS access entries

For each provisioned account assignment, Terraform then creates an EKS access entry in the corresponding cluster account. The access entry resolves the AWSReservedSSO role created for the permission set and maps it to the Kubernetes group from the namespace manifest.

This only provides authentication to the cluster. Further Kubernetes RBAC must still be configured to grant additional permissions for teams.

## Identity and AWS providers

The configuration assumes different AWS roles depending on the operation and reads the `environment_management` secret from the Modernisation Platform account to resolve account IDs for the target environments.

## Prerequisites

Before running Terraform, the following must already exist:

- the `environment_management` secret with account IDs for the relevant clusters
- the AWS SSO/Identity Center instance in the target root account
- the `ContainerPlatformEKSAccess` role in the octo cluster accounts
- namespace manifests under `../namespaces` with valid `name`, `namespaces`, `access`, and `cluster` fields