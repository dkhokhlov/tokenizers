# Makefile for @dkhokhlov/tokenizers
# Builds Node.js bindings and packages them as .tgz files in ./target directory

.PHONY: help build-node build-node-debug clean-node clean-all build ci

# Default target
all: build-node

# Help target
help:
	@echo "Available targets:"
	@echo "  ci              - Install dependencies (yarn install --immutable)"
	@echo "  build-node      - Build Node.js bindings (release mode)"
	@echo "  build-node-debug - Build Node.js bindings (debug mode)"
	@echo "  clean-node      - Clean Node.js build artifacts"
	@echo "  clean-all       - Clean all build artifacts (alias for clean-node)"
	@echo "  help            - Show this help message"
	@echo ""
	@echo "Build outputs:"
	@echo "  - Main package: ./target/dkhokhlov-tokenizers-VERSION.tgz"
	@echo "  - Platform package: ./target/dkhokhlov-tokenizers-PLATFORM-VERSION.tgz"
	@echo ""
	@echo "Examples:"
	@echo "  make ci               # Install dependencies"
	@echo "  make build-node       # Build release packages"
	@echo "  make build-node-debug # Build debug packages"
	@echo "  make clean-node       # Clean all build artifacts"

# Build Node.js bindings (release mode)
build-node:
	@echo "Building Node.js bindings (release mode)..."
	@./scripts/build-node.sh

# Build Node.js bindings (debug mode)
build-node-debug:
	@echo "Building Node.js bindings (debug mode)..."
	@./scripts/build-node.sh --debug

# Alias for build-node
build: build-node

# Clean Node.js build artifacts
clean-node:
	@echo "Cleaning Node.js build artifacts..."
	@./scripts/clean-node.sh

# Clean all build artifacts (currently same as clean-node)
clean-all: clean-node

# Install dependencies
ci:
	@echo "Installing dependencies..."
	@cd bindings/node && yarn install --immutable

# Default clean target
clean: clean-node