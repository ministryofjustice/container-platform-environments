package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
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
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}

func run(args []string, stdout, stderr io.Writer) int {
	if len(args) != 2 || (args[0] != "validate" && args[0] != "matrix") {
		fmt.Fprintln(stderr, "usage: product-config <validate|matrix> <product.yaml>")
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
		if err := json.NewEncoder(stdout).Encode(output); err != nil {
			fmt.Fprintln(stderr, err)
			return 1
		}
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
