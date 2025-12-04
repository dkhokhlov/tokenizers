#!/bin/bash
# Clean script for Node.js bindings
# Removes all build artifacts and generated files
# Usage: ./scripts/clean-node.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NODE_DIR="$REPO_ROOT/bindings/node"
TARGET_DIR="$REPO_ROOT/target"

cd "$NODE_DIR"

echo "=========================================="
echo "Cleaning @dkhokhlov/tokenizers build artifacts"
echo "=========================================="

# Remove generated JavaScript and TypeScript files
echo "Removing generated files..."
rm -f index.js
rm -f index.d.ts

# Remove native binary files (root and npm/ directories)
echo "Removing native binaries..."
rm -f *.node
find . -name "*.node" -type f -delete 2>/dev/null || true

# Remove build artifacts
echo "Removing build artifacts..."
rm -rf target/
rm -rf dist/
rm -rf build/

# Clean target directory (remove .tgz files)
if [[ -d "$TARGET_DIR" ]]; then
  echo "Cleaning target directory..."
  rm -f "$TARGET_DIR"/*.tgz
  # Remove target directory if it's empty
  rmdir "$TARGET_DIR" 2>/dev/null || true
fi

# Remove node_modules (optional - uncomment if needed)
# echo "Removing node_modules..."
# rm -rf node_modules/

# Remove yarn cache (optional - uncomment if needed)
# echo "Clearing yarn cache..."
# yarn cache clean

echo ""
echo "Clean complete!"
echo "All build artifacts have been removed."