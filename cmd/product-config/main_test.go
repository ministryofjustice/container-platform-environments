package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestMatrixIncludesManifestEnvironments(t *testing.T) {
	manifestPath := writeManifest(t, `
product: sample
bu: octo
owner:
  team: sample-team
access: []
environments:
  - name: quality-assurance
    cluster: container-platform-octo-nonlive
    namespace: sample-qa
    is_production: false
  - name: production
    cluster: container-platform-octo-live
    namespace: sample-production
    is_production: true
`)

	var stdout, stderr bytes.Buffer
	if code := run([]string{"matrix", manifestPath}, &stdout, &stderr); code != 0 {
		t.Fatalf("run returned %d: %s", code, stderr.String())
	}

	var output matrixOutput
	if err := json.Unmarshal(stdout.Bytes(), &output); err != nil {
		t.Fatalf("decode matrix JSON: %v", err)
	}
	if len(output.Include) != 2 {
		t.Fatalf("got %d targets, want 2", len(output.Include))
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
	if code := run([]string{"validate", manifestPath}, &stdout, &stderr); code == 0 {
		t.Fatal("validate succeeded for duplicate environment names")
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
