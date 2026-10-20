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

func TestProductDirectoriesFromChangedPaths(t *testing.T) {
	changedPaths := strings.NewReader("namespaces/octo/sample/resources/modules/main.tf\nnamespaces/octo/sample/product.yaml\nnamespaces/hmpps/other/resources/variables.tf\nREADME.md\n")

	productDirs, err := productDirectoriesFromChangedPaths(changedPaths)
	if err != nil {
		t.Fatalf("productDirectoriesFromChangedPaths returned error: %v", err)
	}

	want := []string{"namespaces/hmpps/other", "namespaces/octo/sample"}
	if !reflect.DeepEqual(productDirs, want) {
		t.Fatalf("got product directories %v, want %v", productDirs, want)
	}
}

func TestProductDirectoryForTerraformRelevantPath(t *testing.T) {
	tests := []struct {
		path string
		want string
		ok   bool
	}{
		{path: "namespaces/octo/sample/product.yaml", want: "namespaces/octo/sample", ok: true},
		{path: "namespaces/octo/sample/resources/main.tf", want: "namespaces/octo/sample", ok: true},
		{path: "namespaces/octo/sample/resources/modules/main.tf", want: "namespaces/octo/sample", ok: true},
		{path: "README.md", ok: false},
		{path: "namespaces/octo/product.yaml", ok: false},
		{path: "namespaces/octo/sample/other/main.tf", ok: false},
	}
	for _, test := range tests {
		t.Run(test.path, func(t *testing.T) {
			got, ok := productDirectoryForTerraformRelevantPath(test.path)
			if got != test.want || ok != test.ok {
				t.Fatalf("productDirectoryForTerraformRelevantPath(%q) = (%q, %t), want (%q, %t)", test.path, got, ok, test.want, test.ok)
			}
		})
	}
}

func TestRunBuildsMatrixFromChangedProductResources(t *testing.T) {
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
  - name: quality-assurance
    cluster: container-platform-octo-nonlive
    namespace: sample-qa
    is_production: false
  - name: production
    cluster: container-platform-octo-live
    namespace: sample-production
    is_production: true
`), 0o600); err != nil {
		t.Fatal(err)
	}

	var stdout, stderr bytes.Buffer
	changedPaths := strings.NewReader("namespaces/octo/sample/resources/main.tf\nnamespaces/octo/sample/resources/versions.tf\nnamespaces/octo/sample/product.yaml\nREADME.md\n")
	if code := run([]string{root}, changedPaths, &stdout, &stderr); code != 0 {
		t.Fatalf("run returned %d: %s", code, stderr.String())
	}

	var output matrixOutput
	if err := json.Unmarshal(stdout.Bytes(), &output); err != nil {
		t.Fatalf("decode matrix JSON: %v", err)
	}
	if len(output.Include) != 2 {
		t.Fatalf("got %d targets, want 2", len(output.Include))
	}
	if bytes.Contains(stdout.Bytes(), []byte("allow_pr_deployment")) {
		t.Fatal("matrix should not include pull request deployment settings")
	}
	if got := []string{output.Include[0].Environment, output.Include[1].Environment}; !reflect.DeepEqual(got, []string{"quality-assurance", "production"}) {
		t.Fatalf("got environments %v", got)
	}
}

func TestRunEmitsEmptyMatrixWhenNoPathsMatch(t *testing.T) {
	var stdout, stderr bytes.Buffer
	if code := run([]string{t.TempDir()}, strings.NewReader("README.md\n"), &stdout, &stderr); code != 0 {
		t.Fatalf("run returned %d: %s", code, stderr.String())
	}

	var output matrixOutput
	if err := json.Unmarshal(stdout.Bytes(), &output); err != nil {
		t.Fatalf("decode matrix JSON: %v", err)
	}
	if output.Include == nil || len(output.Include) != 0 {
		t.Fatalf("got include %v, want an empty array", output.Include)
	}
}

func TestRunRequiresRepositoryRoot(t *testing.T) {
	var stdout, stderr bytes.Buffer
	if code := run(nil, strings.NewReader(""), &stdout, &stderr); code != 2 {
		t.Fatalf("run returned %d, want usage error", code)
	}
}
