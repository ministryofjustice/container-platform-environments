{{/*
Validation for product identity.

The chart stamps container-platform/bu and container-platform/product onto
every namespace and namespaced resource it renders. Those labels are the key
the platform's BU-boundary admission policy matches on (ValidatingAdmissionPolicy
argocd-bu-namespace-boundary), so an empty value is not cosmetic: a namespace
rendered with container-platform/bu="" is denied by that policy under
failurePolicy: Fail, wedging the product's baseline sync with an opaque
admission error. Both values come from product.yaml and default to "" in
values.yaml, so fail the render early with a clear message if either is unset.
*/}}
{{- define "app-baseline.validateProduct" -}}
{{- if not .Values.bu }}
{{- fail "app-baseline: product.yaml must set `bu` (the business unit, e.g. octo). It labels every namespace and is required by the BU-boundary admission policy." }}
{{- end }}
{{- if not .Values.product }}
{{- fail "app-baseline: product.yaml must set `product` (the product name). It labels every namespace and resource this chart renders." }}
{{- end }}
{{- end -}}

{{/*
Validation for access declarations.

Enforces the live environment security model: production environments should
default to view-only access. Edit or admin on a production cluster requires
explicit justification via the `live_access_justification` field on the access
entry. Without it the chart render fails, surfacing the policy violation early
rather than after merge.
*/}}
{{- define "app-baseline.validateAccess" -}}
{{- $validRoles := list "view" "edit" "admin" }}

{{/* Build a map of cluster -> is_production from environments */}}
{{- $prodClusters := dict }}
{{- range .Values.environments }}
{{- if .is_production }}
{{- $_ := set $prodClusters .cluster "true" }}
{{- end }}
{{- end }}

{{- range $access := .Values.access }}

{{/* Validate role is one of the allowed built-ins */}}
{{- if not (has $access.role $validRoles) }}
{{- fail (printf "app-baseline: role %q is not supported. Must be one of: view, edit, admin." $access.role) }}
{{- end }}

{{/* Reject edit/admin on production clusters unless justified */}}
{{- if ne $access.role "view" }}
{{- range $cluster := $access.clusters }}
{{- if hasKey $prodClusters $cluster }}
{{- if not $access.live_access_justification }}
{{- fail (printf "app-baseline: group %q is granted %q on production cluster %q. Live environments should be view-only. If this is intentional, add `live_access_justification: \"<reason>\"` to the access entry." $access.group $access.role $cluster) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- end }}
{{- end -}}
