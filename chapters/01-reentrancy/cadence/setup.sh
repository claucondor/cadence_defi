#!/bin/bash

# Setup script para tests de Cadence
# Capítulo 1: Reentrancy Prevention

set -e

echo "🌊 Setting up Flow/Cadence tests for Reentrancy chapter..."
echo ""

# Check if Flow CLI is installed
if ! command -v flow &> /dev/null; then
    echo "❌ Flow CLI not found. Installing..."
    sh -ci "$(curl -fsSL https://storage.googleapis.com/flow-cli/install.sh)"

    # Add to PATH
    export PATH="$HOME/.local/bin:$PATH"
else
    echo "✅ Flow CLI found: $(flow version | head -n 1)"
fi

# Check version
FLOW_VERSION=$(flow version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
echo "Current version: $FLOW_VERSION"

echo ""
echo "📝 Note: Flow CLI v1.18.0+ is recommended for testing"
echo "   If you have an older version, update with: flow version --check-updates"
echo ""

echo "🧪 Running Cadence tests..."
echo ""

# Run tests
if flow test tests/SimpleVault_test.cdc 2>&1 | grep -q "error"; then
    echo ""
    echo "⚠️  Tests encountered issues. This may be due to:"
    echo "   1. Flow CLI version (upgrade to v1.18.0+)"
    echo "   2. Configuration issues"
    echo ""
    echo "💡 Alternative: Use Flow Playground (online, no installation needed)"
    echo "   https://play.flow.com/"
    echo ""
    echo "   Just copy SimpleVault.cdc and run it in the browser!"
    exit 1
else
    echo ""
    echo "✅ Setup complete!"
    echo ""
    echo "You can now run:"
    echo "  flow test tests/SimpleVault_test.cdc          # Run all tests"
    echo "  flow test --verbose tests/SimpleVault_test.cdc # Verbose output"
    echo ""
    echo "Or use Flow Playground (no installation):"
    echo "  https://play.flow.com/"
    echo ""
fi
