# HF Tokenizers - Node.js

Node.js bindings for the HuggingFace Tokenizers library with Rust-powered performance.

## Build Instructions

```bash
# Install dependencies
make ci

# Build release packages
make build-node

# Build debug packages (with debug symbols)
make build-node-debug

# Clean artifacts
make clean-node
```

## Output

Build artifacts are packaged as `.tgz` files in `./target/`:

- **Main package**: `dkhokhlov-tokenizers-VERSION.tgz` - JavaScript bindings with platform detection
- **Platform package**: `dkhokhlov-tokenizers-PLATFORM-VERSION.tgz` - Native binary for current platform

## Available Targets

- `make ci` - Install dependencies
- `make build-node` - Build release packages
- `make build-node-debug` - Build debug packages
- `make clean-node` - Clean build artifacts
- `make help` - Show help message