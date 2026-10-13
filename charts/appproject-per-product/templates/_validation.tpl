{{/*
Validation for the per-product AppProject generator inputs.

bu, productDir and targetCluster are scalar parameters supplied by the
argocd_appproject_products ApplicationSet. productDir (the product DIRECTORY
name) is the single source of truth for the AppProject name — it must match the
directory segment the workload ApplicationSet uses for spec.project, or the
workload Applications reference a project that was never generated and fail
validation permanently. targetCluster drives which declared namespaces land in
destinations. A mis-wired generator that omits any of these would otherwise
render a mis-named or scope-less project silently, so fail the render early with
a clear message instead.
*/}}
{{- define "appproject-per-product.validateProduct" -}}
{{- if not .Values.bu }}
{{- fail "appproject-per-product: `bu` is required (scalar parameter from the generator). It names the AppProject and labels it." }}
{{- end }}
{{- if not .Values.productDir }}
{{- fail "appproject-per-product: `productDir` is required (scalar parameter from the generator). It is the product directory name and the single source of truth for the AppProject name — it must match the workload ApplicationSet's project reference." }}
{{- end }}
{{- if not .Values.targetCluster }}
{{- fail "appproject-per-product: `targetCluster` is required (scalar parameter from the generator). It selects which declared namespaces become this tier's destinations." }}
{{- end }}
{{- end -}}
