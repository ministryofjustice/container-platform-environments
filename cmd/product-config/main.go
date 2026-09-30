package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

type productManifest struct {
	Product      string        `yaml:"product"`
	BU           string        `yaml:"bu"`
	Environments []environment `yaml:"environments"`
}

type environment struct {
	Name         string `yaml:"name"`
	Cluster      string `yaml:"cluster"`
	Namespace    string `yaml:"namespace"`
	IsProduction *bool  `yaml:"is_production"`
}

type matrixOutput struct {
	Include []matrixTarget `json:"include"`
}

type matrixTarget struct {
	Product      string `json:"product"`
	BU           string `json:"bu"`
	Environment  string `json:"environment"`
	Cluster      string `json:"cluster"`
	Namespace    string `json:"namespace"`
	IsProduction bool   `json:"is_production"`
}

func main() {
	os.Exit(run(os.Args[1:], os.Stdin, os.Stdout, os.Stderr))
}

func run(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	if len(args) != 2 || (args[0] != "validate" && args[0] != "matrix") {
		if len(args) == 2 && args[0] == "matrix-changes" {
			output, err := matrixForChangedPaths(args[1], stdin)
			if err != nil {
				fmt.Fprintln(stderr, err)
				return 1
			}
			return writeMatrix(output, stdout, stderr)
		}
		fmt.Fprintln(stderr, "usage: product-config <validate|matrix> <product.yaml> | matrix-changes <repo-root> (changed paths on stdin)")
		return 2
	}

	manifest, err := loadProduct(args[1])
	if err == nil {
		err = validateProduct(manifest)
	}
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}

	switch args[0] {
	case "validate":
		fmt.Fprintf(stdout, "valid product %s: %d environment(s)\n", manifest.Product, len(manifest.Environments))
	case "matrix":
		return writeMatrix(matrixForProduct(manifest), stdout, stderr)
	}

	return 0
}

func matrixForChangedPaths(root string, changedPaths io.Reader) (matrixOutput, error) {
	productDirs := make(map[string]struct{})
	scanner := bufio.NewScanner(changedPaths)
	for scanner.Scan() {
		parts := strings.Split(filepath.ToSlash(filepath.Clean(scanner.Text())), "/")
		isProductManifest := len(parts) == 4 && parts[3] == "product.yaml"
		isResourceFile := len(parts) >= 5 && parts[3] == "resources"
		if len(parts) >= 4 && parts[0] == "namespaces" && (isProductManifest || isResourceFile) {
			productDirs[filepath.Join(root, parts[0], parts[1], parts[2], "product.yaml")] = struct{}{}
		}
	}
	if err := scanner.Err(); err != nil {
		return matrixOutput{}, fmt.Errorf("read changed paths: %w", err)
	}
	if len(productDirs) == 0 {
		return matrixOutput{}, errors.New("no changed resource files found under namespaces/<bu>/<product>/resources/")
	}

	manifestPaths := make([]string, 0, len(productDirs))
	for path := range productDirs {
		manifestPaths = append(manifestPaths, path)
	}
	sort.Strings(manifestPaths)

	output := matrixOutput{Include: []matrixTarget{}}
	for _, path := range manifestPaths {
		manifest, err := loadProduct(path)
		if err != nil {
			return matrixOutput{}, err
		}
		if err := validateProduct(manifest); err != nil {
			return matrixOutput{}, fmt.Errorf("%s: %w", path, err)
		}
		output.Include = append(output.Include, matrixForProduct(manifest).Include...)
	}
	return output, nil
}

func matrixForProduct(manifest productManifest) matrixOutput {
	output := matrixOutput{Include: make([]matrixTarget, 0, len(manifest.Environments))}
	for _, environment := range manifest.Environments {
		output.Include = append(output.Include, matrixTarget{
			Product:      manifest.Product,
			BU:           manifest.BU,
			Environment:  environment.Name,
			Cluster:      environment.Cluster,
			Namespace:    environment.Namespace,
			IsProduction: *environment.IsProduction,
		})
	}
	return output
}

func writeMatrix(output matrixOutput, stdout, stderr io.Writer) int {
	if err := json.NewEncoder(stdout).Encode(output); err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	return 0
}

func loadProduct(path string) (productManifest, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return productManifest{}, fmt.Errorf("read %s: %w", path, err)
	}

	var manifest productManifest
	if err := yaml.Unmarshal(data, &manifest); err != nil {
		return productManifest{}, fmt.Errorf("parse %s: %w", path, err)
	}
	return manifest, nil
}

func validateProduct(manifest productManifest) error {
	if strings.TrimSpace(manifest.Product) == "" {
		return errors.New("product must be a non-empty string")
	}
	if strings.TrimSpace(manifest.BU) == "" {
		return errors.New("bu must be a non-empty string")
	}
	if len(manifest.Environments) == 0 {
		return errors.New("environments must contain at least one entry")
	}

	names := make(map[string]struct{}, len(manifest.Environments))
	targets := make(map[string]struct{}, len(manifest.Environments))
	for index, environment := range manifest.Environments {
		prefix := fmt.Sprintf("environments[%d]", index)
		if strings.TrimSpace(environment.Name) == "" {
			return fmt.Errorf("%s.name must be a non-empty string", prefix)
		}
		if strings.TrimSpace(environment.Cluster) == "" {
			return fmt.Errorf("%s.cluster must be a non-empty string", prefix)
		}
		if strings.TrimSpace(environment.Namespace) == "" {
			return fmt.Errorf("%s.namespace must be a non-empty string", prefix)
		}
		if environment.IsProduction == nil {
			return fmt.Errorf("%s.is_production must be true or false", prefix)
		}

		nameKey := strings.ToLower(environment.Name)
		if _, exists := names[nameKey]; exists {
			return fmt.Errorf("duplicate environment name %q", environment.Name)
		}
		names[nameKey] = struct{}{}

		targetKey := environment.Cluster + "/" + environment.Namespace
		if _, exists := targets[targetKey]; exists {
			return fmt.Errorf("duplicate namespace target %q", targetKey)
		}
		targets[targetKey] = struct{}{}
	}

	return nil
}
