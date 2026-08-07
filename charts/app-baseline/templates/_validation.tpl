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
