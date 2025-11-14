#!/bin/bash

# Setup script for ERC20 Approval Pattern tests
set -e

echo "🔨 Setting up Foundry environment for ERC20 Approval Pattern tests..."
echo ""

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ Foundry not found${NC}"
    echo ""
    echo "Installing Foundry..."
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
    echo -e "${GREEN}✅ Foundry installed${NC}"
else
    echo -e "${GREEN}✅ Foundry found${NC}"
fi

echo ""
echo "📦 Installing dependencies..."

# Install forge-std
if [ ! -d "lib/forge-std" ]; then
    forge install foundry-rs/forge-std --no-commit
    echo -e "${GREEN}✅ forge-std installed${NC}"
else
    echo -e "${GREEN}✅ forge-std already installed${NC}"
fi

# Install OpenZeppelin
if [ ! -d "lib/openzeppelin-contracts" ]; then
    forge install OpenZeppelin/openzeppelin-contracts --no-commit
    echo -e "${GREEN}✅ OpenZeppelin contracts installed${NC}"
else
    echo -e "${GREEN}✅ OpenZeppelin already installed${NC}"
fi

echo ""
echo "🏗️  Building contracts..."
forge build

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo ""
echo "🧪 Running tests..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

forge test -vv

if [ $? -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    echo "📖 What was tested:"
    echo "   Exploit tests:"
    echo "   • Infinite approval vulnerability"
    echo "   • SWC-114 race condition attack"
    echo "   • Malicious DEX draining funds"
    echo "   • Li.Fi-style bridge exploit"
    echo ""
    echo "   Protection tests:"
    echo "   • increaseAllowance/decreaseAllowance"
    echo "   • EIP-2612 Permit (gasless approvals)"
    echo "   • Permit2-style expirable approvals"
    echo "   • Secure bridge with whitelist"
    echo ""
    echo "🎯 Key Insights:"
    echo "   • ERC20 approve() has fundamental design flaws"
    echo "   • Infinite approvals enable $9.7M+ hacks (Li.Fi 2024)"
    echo "   • Modern solutions: Permit, Permit2, expirable approvals"
    echo "   • Cadence eliminates this with Capabilities (next!)"
    echo ""
    echo "📚 Next steps:"
    echo "   • Read evm/README.md for detailed explanation"
    echo "   • Compare with cadence/ to see Capabilities model"
    echo "   • Run 'forge test -vvvv' for detailed traces"
    echo ""
else
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${RED}❌ Tests failed${NC}"
    echo ""
    echo "🐛 Troubleshooting:"
    echo "   1. Run 'forge clean && forge build'"
    echo "   2. Check that all dependencies are installed"
    echo "   3. Run 'forge test -vvvv' for detailed error traces"
    echo ""
    exit 1
fi
