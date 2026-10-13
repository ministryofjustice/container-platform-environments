#!/usr/bin/env bash
#
# check-namespace-routing.sh — pre-merge guard for namespace routing.
#
# Depends only on python3 + pyyaml (both preinstalled on ubuntu-latest).
# yq is intentionally NOT used — it is not on the runner image and has no
# repo precedent, so python3 + pyyaml keeps this zero-install and deterministic.
#
# Two checks, emitting GitHub Actions ::error annotations on failure:
#   1. product == directory: each namespaces/<bu>/<product>/product.yaml must
#      carry product: equal to its own directory name.
#   2. values routing namespace is declared: each deployment values file's
#      top-level namespace: must be one of the namespaces declared across the
#      sibling product.yaml environments[].namespace set.
#
# Exits 0 when everything is consistent, 1 otherwise.

set -o pipefail

fail=0

# Check 1 — product key must equal its product directory name.
for py in $(git ls-files 'namespaces/*/*/product.yaml'); do
  dir=$(basename "$(dirname "$py")")
  key=$(python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])) or {}; print(d.get("product",""))' "$py")
  if [ "$key" != "$dir" ]; then
    echo "::error file=$py::product key '$key' must equal product directory name '$dir'"
    fail=1
  fi
done

# Check 2 — each values file's top-level namespace must be declared in product.yaml.
for vf in $(git ls-files 'namespaces/*/*/*/deployment/values/*/*.yaml'); do
  product_dir=$(echo "$vf" | sed -E 's#(namespaces/[^/]+/[^/]+)/.*#\1#')
  product_yaml="$product_dir/product.yaml"

  if [ ! -f "$product_yaml" ]; then
    echo "::error file=$vf::no product.yaml at $product_dir"
    fail=1
    continue
  fi

  declared=$(python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])) or {}; [print(e.get("namespace","")) for e in (d.get("environments") or [])]' "$product_yaml" | sort -u)
  routed=$(python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])) or {}; print(d.get("namespace",""))' "$vf")

  if [ -z "$routed" ]; then
    echo "::error file=$vf::missing top-level 'namespace:'"
    fail=1
    continue
  fi

  if ! grep -qxF "$routed" <<<"$declared"; then
    allowed=$(echo "$declared" | paste -sd ' ' -)
    echo "::error file=$vf::namespace '$routed' not declared in $product_yaml (allowed: $allowed)"
    fail=1
  fi
done

exit $fail
