#!/bin/bash

# Setup script for Cadence overflow tests
# This script installs Flow CLI and runs the test suite

set -e  # Exit on error

echo "🌊 Setting up Cadence Overflow Protection Tests..."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Flow CLI is installed
if ! command -v flow &> /dev/null; then
    echo -e "${YELLOW}Flow CLI not found. Installing...${NC}"

    # Install Flow CLI
    sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"

    echo -e "${GREEN}✅ Flow CLI installed${NC}"
else
    echo -e "${GREEN}✅ Flow CLI already installed${NC}"
fi

# Verify Flow CLI version
FLOW_VERSION=$(flow version 2>&1 | head -n 1 || echo "unknown")
echo "   Version: $FLOW_VERSION"
echo ""

# Check if we're in the right directory
if [ ! -f "OverflowSafe.cdc" ]; then
    echo -e "${RED}❌ Error: OverflowSafe.cdc not found${NC}"
    echo "   Make sure you're in chapters/02-overflow/cadence/"
    exit 1
fi

# Initialize flow.json if it doesn't exist
if [ ! -f "flow.json" ]; then
    echo -e "${YELLOW}Initializing flow.json...${NC}"
    flow init --reset
    echo -e "${GREEN}✅ flow.json created${NC}"
else
    echo -e "${GREEN}✅ flow.json exists${NC}"
fi

echo ""
echo "🧪 Running Cadence tests..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Run tests
if flow test tests/OverflowSafe_test.cdc; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo "📖 What was tested:"
    echo "   • Native overflow protection (addition)"
    echo "   • Native underflow protection (subtraction)"
    echo "   • No libraries needed (built into language)"
    echo ""
    echo "🎯 Key Insight:"
    echo "   Cadence NEVER had overflow bugs - it was designed"
    echo "   with safety from day 1, unlike Solidity which needed"
    echo "   SafeMath libraries and compiler updates."
    echo ""
    echo "📚 Next steps:"
    echo "   • Read cadence/README.md for detailed explanation"
    echo "   • Compare with evm/ code to see the difference"
    echo "   • Run 'flow test tests/OverflowSafe_test.cdc' to re-run tests"
    echo ""
else
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${RED}❌ Tests failed${NC}"
    echo ""
    echo "🐛 Troubleshooting:"
    echo "   1. Check Flow CLI version: flow version"
    echo "   2. Ensure Flow CLI v1.18.0+ is installed"
    echo "   3. Try: flow test tests/OverflowSafe_test.cdc --verbose"
    echo "   4. See cadence/README.md for more help"
    echo ""
    exit 1
fi
