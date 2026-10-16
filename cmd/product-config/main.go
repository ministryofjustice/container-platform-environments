package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path"
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
	IsProduction bool   `yaml:"is_production"`
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
	if len(args) != 1 {
		fmt.Fprintln(stderr, "usage: product-config <repo-root> (changed paths on stdin)")
		return 2
	}

	output, err := matrixForChangedPaths(args[0], stdin)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return 1
	}
	return writeMatrix(output, stdout, stderr)
}

func matrixForChangedPaths(root string, changedPaths io.Reader) (matrixOutput, error) {
	productDirs, err := productDirectoriesFromChangedPaths(changedPaths)
	if err != nil {
		return matrixOutput{}, err
	}
	return matrixForProductDirectories(root, productDirs)
}

// productDirectoriesFromChangedPaths maps changed product manifests and resource files
// to their product directories, keeping one directory per product.
func productDirectoriesFromChangedPaths(changedPaths io.Reader) ([]string, error) {
	productDirs := make(map[string]struct{})
	scanner := bufio.NewScanner(changedPaths)
	for scanner.Scan() {
		if productDir, ok := productDirectoryForChangedPath(scanner.Text()); ok {
			productDirs[productDir] = struct{}{}
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("read changed paths: %w", err)
	}

	directories := make([]string, 0, len(productDirs))
	for dir := range productDirs {
		directories = append(directories, dir)
	}
	sort.Strings(directories)
	return directories, nil
}

func productDirectoryForChangedPath(changedPath string) (string, bool) {
	cleanPath := path.Clean(filepath.ToSlash(changedPath))
	_, ok := strings.CutPrefix(cleanPath, "namespaces/")
	if !ok {
		return "", false
	}

	if strings.HasSuffix(cleanPath, "/product.yaml") {
		productDir := path.Dir(cleanPath)
		if path.Dir(path.Dir(productDir)) == "namespaces" {
			return productDir, true
		}
	}

	productDir, resourceFile, isResourceFile := strings.Cut(cleanPath, "/resources/")
	if isResourceFile && resourceFile != "" && path.Dir(path.Dir(productDir)) == "namespaces" {
		return productDir, true
	}
	return "", false
}

// matrixForProductDirectories loads each product manifest and adds one matrix row per environment.
func matrixForProductDirectories(root string, productDirs []string) (matrixOutput, error) {
	output := matrixOutput{Include: []matrixTarget{}}
	for _, dir := range productDirs {
		manifestPath := filepath.Join(root, dir, "product.yaml")
		manifest, err := loadProduct(manifestPath)
		if err != nil {
			return matrixOutput{}, err
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
			IsProduction: environment.IsProduction,
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
