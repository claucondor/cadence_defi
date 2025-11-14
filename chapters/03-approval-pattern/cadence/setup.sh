#!/bin/bash

# Setup script for Cadence Capability Pattern tests
set -e

echo "🌊 Setting up Cadence Capability Pattern Tests..."
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if Flow CLI is installed
if ! command -v flow &> /dev/null; then
    echo -e "${YELLOW}Flow CLI not found. Installing...${NC}"
    sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"
    echo -e "${GREEN}✅ Flow CLI installed${NC}"
else
    echo -e "${GREEN}✅ Flow CLI already installed${NC}"
fi

FLOW_VERSION=$(flow version 2>&1 | head -n 1 || echo "unknown")
echo "   Version: $FLOW_VERSION"
echo ""

# Check files exist
if [ ! -f "CapabilityPattern.cdc" ]; then
    echo -e "${RED}❌ Error: CapabilityPattern.cdc not found${NC}"
    exit 1
fi

# Initialize flow.json if needed
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

if flow test tests/CapabilityPattern_test.cdc; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo "📖 What was tested:"
    echo "   • Direct transfers (no approval needed)"
    echo "   • DEX swaps without approvals"
    echo "   • Infinite approvals are impossible"
    echo "   • Instant capability revocation"
    echo "   • No SWC-114 race conditions"
    echo "   • Type-safe capabilities"
    echo ""
    echo "🎯 Key Insights:"
    echo "   • Cadence NEVER had approval vulnerabilities"
    echo "   • Resources eliminate need for approvals"
    echo "   • Capabilities > Allowances (more secure, better UX)"
    echo "   • One transaction vs three (approve + swap + revoke)"
    echo ""
    echo "⚖️ Comparison with ERC20:"
    echo "   ERC20: Infinite approvals → \$9.7M Li.Fi hack (2024)"
    echo "   Cadence: No approvals → \$0 stolen (impossible by design)"
    echo ""
    echo "📚 Next steps:"
    echo "   • Read cadence/README.md for detailed explanation"
    echo "   • Compare with evm/ tests to see the difference"
    echo "   • Check comparativa.md for side-by-side comparison"
    echo ""
else
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${RED}❌ Tests failed${NC}"
    echo ""
    echo "🐛 Troubleshooting:"
    echo "   1. Check Flow CLI version: flow version (need v1.18.0+)"
    echo "   2. Try: flow test tests/CapabilityPattern_test.cdc --verbose"
    echo "   3. See cadence/README.md for more help"
    echo ""
    exit 1
fi
