package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestMatrixIncludesManifestEnvironments(t *testing.T) {
	manifestPath := writeManifest(t, `
product: sample
bu: octo
owner:
  team: sample-team
access: []
environments: [{name: quality-assurance, cluster: container-platform-octo-nonlive, namespace: sample-qa, is_production: false, allow_pr_deployment: true}, {name: production, cluster: container-platform-octo-live, namespace: sample-production, is_production: true, allow_pr_deployment: false}]
`)

	var stdout, stderr bytes.Buffer
	if code := run([]string{"matrix", manifestPath}, strings.NewReader(""), &stdout, &stderr); code != 0 {
		t.Fatalf("run returned %d: %s", code, stderr.String())
	}

	var output matrixOutput
	if err := json.Unmarshal(stdout.Bytes(), &output); err != nil {
		t.Fatalf("decode matrix JSON: %v", err)
	}
	if len(output.Include) != 2 {
		t.Fatalf("got %d targets, want 2", len(output.Include))
	}
	if !output.Include[0].AllowPRDeployment || output.Include[1].AllowPRDeployment {
		t.Fatal("matrix targets should preserve each environment's pull request deployment setting")
	}
	if got := []string{output.Include[0].Environment, output.Include[1].Environment}; !reflect.DeepEqual(got, []string{"quality-assurance", "production"}) {
		t.Fatalf("got environments %v", got)
	}
}

func TestValidateRejectsDuplicateEnvironmentNames(t *testing.T) {
	manifestPath := writeManifest(t, `
product: sample
bu: octo
environments:
  - name: Dev
    cluster: container-platform-octo-nonlive
    namespace: sample-dev
    is_production: false
  - name: dev
    cluster: container-platform-octo-nonlive
    namespace: sample-dev-lower
    is_production: false
`)

	var stdout, stderr bytes.Buffer
	if code := run([]string{"validate", manifestPath}, strings.NewReader(""), &stdout, &stderr); code == 0 {
		t.Fatal("validate succeeded for duplicate environment names")
	}
}

func TestMatrixChangesFindsProductFromResourcePaths(t *testing.T) {
	root := t.TempDir()
	productDir := filepath.Join(root, "namespaces", "octo", "sample")
	if err := os.MkdirAll(filepath.Join(productDir, "resources"), 0o700); err != nil {
		t.Fatal(err)
	}
	manifestPath := filepath.Join(productDir, "product.yaml")
	if err := os.WriteFile(manifestPath, []byte(`
product: sample
bu: octo
environments:
  - name: dev
    cluster: container-platform-octo-nonlive
    namespace: sample-dev
    is_production: false
  - name: prod
    cluster: container-platform-octo-live
    namespace: sample-prod
    is_production: true
`), 0o600); err != nil {
		t.Fatal(err)
	}

	changedPaths := strings.NewReader("namespaces/octo/sample/resources/main.tf\nnamespaces/octo/sample/resources/versions.tf\nnamespaces/octo/sample/product.yaml\nREADME.md\n")
	var stdout, stderr bytes.Buffer
	if code := run([]string{"matrix-changes", root}, changedPaths, &stdout, &stderr); code != 0 {
		t.Fatalf("run returned %d: %s", code, stderr.String())
	}

	var output matrixOutput
	if err := json.Unmarshal(stdout.Bytes(), &output); err != nil {
		t.Fatalf("decode matrix JSON: %v", err)
	}
	if len(output.Include) != 2 {
		t.Fatalf("got %d targets, want 2", len(output.Include))
	}
	if output.Include[0].AllowPRDeployment || output.Include[1].AllowPRDeployment {
		t.Fatal("matrix targets should disallow pull request deployments by default")
	}
	if got := []string{output.Include[0].Environment, output.Include[1].Environment}; !reflect.DeepEqual(got, []string{"dev", "prod"}) {
		t.Fatalf("got environments %v", got)
	}
}

func writeManifest(t *testing.T, content string) string {
	t.Helper()

	path := filepath.Join(t.TempDir(), "product.yaml")
	if err := os.WriteFile(path, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}
