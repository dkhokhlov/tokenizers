#!/bin/bash
# Build script for Node.js bindings
# Self-contained build script that prepares the package for publishing
# Builds the package for current host platform and strips index.js to only include current platform
# Final packages are output as .tgz files in ./target directory
# Usage: ./scripts/build-node.sh [--debug]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NODE_DIR="$REPO_ROOT/bindings/node"
TARGET_DIR="$REPO_ROOT/target"

cd "$NODE_DIR"

# Check for debug flag
DEBUG=false
if [[ "$1" == "--debug" ]]; then
  DEBUG=true
fi

# Verify required tools
if ! command -v node &> /dev/null; then
  echo "Error: node is required but not installed"
  exit 1
fi

# Ensure yarn is available (install if needed)
if ! command -v yarn &> /dev/null; then
  echo "yarn not found, attempting to install..."

  # Try to enable yarn via corepack (Node.js 16.10+)
  if command -v corepack &> /dev/null; then
    echo "Enabling yarn via corepack..."
    corepack enable
    corepack prepare yarn@3.5.1 --activate
  else
    # Fallback: install yarn via npm
    echo "Installing yarn via npm..."
    npm install -g yarn
  fi

  # Verify yarn is now available
  if ! command -v yarn &> /dev/null; then
    echo "Error: Failed to install yarn. Please install yarn manually:"
    echo "  npm install -g yarn"
    echo "  or enable corepack: corepack enable"
    exit 1
  fi
fi

# Verify yarn version matches packageManager requirement
YARN_VERSION=$(yarn --version 2>/dev/null || echo "0.0.0")
echo "Using yarn version: $YARN_VERSION"

# Detect current platform and architecture
PLATFORM=$(node -e "console.log(process.platform)")
ARCH=$(node -e "console.log(process.arch)")

# Map to napi target triple
case "$PLATFORM" in
  linux)
    case "$ARCH" in
      x64)
        TARGET="x86_64-unknown-linux-gnu"
        ;;
      arm64)
        TARGET="aarch64-unknown-linux-gnu"
        ;;
      arm)
        TARGET="armv7-unknown-linux-gnueabihf"
        ;;
      riscv64)
        TARGET="riscv64gc-unknown-linux-gnu"
        ;;
      s390x)
        TARGET="s390x-unknown-linux-gnu"
        ;;
      *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
    esac
    ;;
  darwin)
    case "$ARCH" in
      x64)
        TARGET="x86_64-apple-darwin"
        ;;
      arm64)
        TARGET="aarch64-apple-darwin"
        ;;
      *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
    esac
    ;;
  win32)
    case "$ARCH" in
      x64)
        TARGET="x86_64-pc-windows-msvc"
        ;;
      ia32)
        TARGET="i686-pc-windows-msvc"
        ;;
      arm64)
        TARGET="aarch64-pc-windows-msvc"
        ;;
      *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Unsupported platform: $PLATFORM"
    exit 1
    ;;
esac

# Read version from VERSION file (already patched in Step 0)
VERSION=$(cat "$REPO_ROOT/VERSION" | tr -d '\n')

echo "=========================================="
echo "Building @dkhokhlov/tokenizers"
echo "Version: $VERSION"
echo "Platform: $PLATFORM/$ARCH"
echo "Target: $TARGET"
echo "Mode: $([ "$DEBUG" == "true" ] && echo "debug" || echo "release")"
echo "Output: $TARGET_DIR"
echo "=========================================="

# Create target directory
mkdir -p "$TARGET_DIR"

# Step 0: Patch versions from VERSION file (before build)
echo ""
echo "Step 0: Patching versions from VERSION file..."
node scripts/patch-versions.js

# Step 1: Install dependencies
echo ""
echo "Step 1: Installing dependencies..."
# Try immutable lockfile first (yarn 3+), but allow regular install if there are issues
set +e  # Temporarily disable exit on error
yarn install --immutable 2>&1
INSTALL_STATUS=$?
set -e  # Re-enable exit on error

if [[ $INSTALL_STATUS -eq 0 ]]; then
  echo "Dependencies installed successfully with immutable lockfile"
else
  echo "Lockfile needs updates or has dependency issues, installing dependencies..."
  yarn install
fi

# Step 2: Clean previous build artifacts
echo ""
echo "Step 2: Cleaning previous build artifacts..."
rm -f index.js index.d.ts
rm -f *.node

# Step 3: Build with napi (only builds binary for current platform due to --target)
# Use npx to run napi directly, bypassing yarn/npm script execution
echo ""
echo "Step 3: Building native module with napi..."
if [[ "$DEBUG" == "true" ]]; then
  npx napi build --platform --target "$TARGET" --pipe "prettier -w"
else
  npx napi build --platform --target "$TARGET" --release --pipe "prettier -w"
fi

# Verify index.js was generated
if [[ ! -f "index.js" ]]; then
  echo "Error: index.js was not generated"
  exit 1
fi

# Step 4: Strip index.js to only include current platform
echo ""
echo "Step 4: Stripping index.js to only include current platform..."
node scripts/strip-platforms.js

# Verify index.js still exists after stripping
if [[ ! -f "index.js" ]]; then
  echo "Error: index.js was removed during platform stripping"
  exit 1
fi

# Step 5: Verify build output
echo ""
echo "Step 5: Verifying build output..."
if [[ ! -f "index.d.ts" ]]; then
  echo "Warning: index.d.ts was not generated"
fi

# Check that index.js only contains current platform
if grep -q "case 'android'\|case 'win32'\|case 'darwin'\|case 'freebsd'" index.js 2>/dev/null; then
  echo "Warning: index.js still contains other platform cases"
fi

# Step 6: Copy built .node file to platform package folder
echo ""
echo "Step 6: Copying built binary to platform package folder..."
# Determine platform package name from .node file
NODE_FILE=$(ls *.node 2>/dev/null | head -1)
if [[ -n "$NODE_FILE" ]]; then
  # Extract platform from filename: tokenizers.linux-x64-gnu.node -> linux-x64-gnu
  PLATFORM_PKG=$(echo "$NODE_FILE" | sed 's/tokenizers\.\(.*\)\.node/\1/')
  PLATFORM_DIR="npm/$PLATFORM_PKG"

  if [[ ! -d "$PLATFORM_DIR" ]]; then
    echo "Error: Platform package directory not found: $PLATFORM_DIR"
    echo "Platform package folders must exist in git"
    exit 1
  fi

  echo "  Copying $NODE_FILE to $PLATFORM_DIR/"
  cp "$NODE_FILE" "$PLATFORM_DIR/"

  # Update package.json for platform package with current version
  cat > "$PLATFORM_DIR/package.json" <<EOF
{
  "name": "@dkhokhlov/tokenizers-$PLATFORM_PKG",
  "version": "$(cat "$REPO_ROOT/VERSION" | tr -d '\n')",
  "os": ["$(echo $PLATFORM_PKG | cut -d'-' -f1)"],
  "cpu": ["$(echo $PLATFORM_PKG | cut -d'-' -f2)"],
  "main": "tokenizers.$PLATFORM_PKG.node",
  "files": [
    "tokenizers.$PLATFORM_PKG.node"
  ]
}
EOF

  echo "  ✓ Copied binary and updated package.json in platform package folder"
else
  echo "  ⚠ No .node file found, skipping platform package update"
fi

echo ""
echo "=========================================="
echo "Packaging build artifacts..."
echo "=========================================="

# Step 7: Package main package as .tgz
echo ""
echo "Step 7: Creating main package tarball..."
MAIN_PACKAGE_NAME=$(node -e "console.log(require('./package.json').name.replace('@', '').replace('/', '-'))")
MAIN_TGZ_NAME="$MAIN_PACKAGE_NAME-$VERSION.tgz"

# Use npm pack to create the tarball
npm pack --pack-destination="$TARGET_DIR"

# Rename the generated tarball to our expected name
GENERATED_TGZ=$(ls "$TARGET_DIR"/*.tgz | head -1)
if [[ -n "$GENERATED_TGZ" && "$GENERATED_TGZ" != "$TARGET_DIR/$MAIN_TGZ_NAME" ]]; then
  mv "$GENERATED_TGZ" "$TARGET_DIR/$MAIN_TGZ_NAME"
fi

echo "  ✓ Created main package: $TARGET_DIR/$MAIN_TGZ_NAME"

# Step 8: Package platform-specific package as .tgz
if [[ -n "$NODE_FILE" && -d "$PLATFORM_DIR" ]]; then
  echo ""
  echo "Step 8: Creating platform package tarball..."

  cd "$PLATFORM_DIR"
  PLATFORM_PACKAGE_NAME=$(node -e "console.log(require('./package.json').name.replace('@', '').replace('/', '-'))")
  PLATFORM_TGZ_NAME="$PLATFORM_PACKAGE_NAME-$VERSION.tgz"

  # Use npm pack to create the platform-specific tarball
  npm pack --pack-destination="$TARGET_DIR"

  # Rename the generated tarball to our expected name
  PLATFORM_GENERATED_TGZ=$(ls "$TARGET_DIR"/*$PLATFORM_PKG*.tgz 2>/dev/null | head -1)
  if [[ -n "$PLATFORM_GENERATED_TGZ" && "$PLATFORM_GENERATED_TGZ" != "$TARGET_DIR/$PLATFORM_TGZ_NAME" ]]; then
    mv "$PLATFORM_GENERATED_TGZ" "$TARGET_DIR/$PLATFORM_TGZ_NAME"
  fi

  echo "  ✓ Created platform package: $TARGET_DIR/$PLATFORM_TGZ_NAME"

  cd "$NODE_DIR"
fi

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="

# Show generated artifacts in target directory
echo ""
echo "Generated artifacts in $TARGET_DIR:"
ls -lh "$TARGET_DIR"/*.tgz 2>/dev/null | while read -r line; do
  filename=$(echo "$line" | awk '{print $9}')
  size=$(echo "$line" | awk '{print $5}')
  basename_file=$(basename "$filename")
  echo "  - $basename_file ($size)"
done

echo ""
echo "Packages are ready for distribution from $TARGET_DIR/"