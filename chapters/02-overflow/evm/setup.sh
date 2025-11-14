#!/bin/bash

# Setup script para tests de Foundry
# Capítulo 1: Reentrancy Attacks

set -e

echo "🔨 Setting up Foundry tests for Reentrancy chapter..."
echo ""

# Check if Foundry is installed
if ! command -v forge &> /dev/null; then
    echo "❌ Foundry not found. Installing..."
    curl -L https://foundry.paradigm.xyz | bash
    source ~/.bashrc
    foundryup
else
    echo "✅ Foundry found: $(forge --version | head -n 1)"
fi

echo ""
echo "📦 Installing dependencies..."

# Install forge-std
if [ ! -d "lib/forge-std" ]; then
    echo "Installing forge-std..."
    forge install foundry-rs/forge-std --no-commit
else
    echo "✅ forge-std already installed"
fi

# Install OpenZeppelin
if [ ! -d "lib/openzeppelin-contracts" ]; then
    echo "Installing OpenZeppelin contracts..."
    forge install OpenZeppelin/openzeppelin-contracts --no-commit
else
    echo "✅ OpenZeppelin already installed"
fi

echo ""
echo "🔨 Compiling contracts..."
forge build

echo ""
echo "🧪 Running tests..."
forge test -vv

echo ""
echo "✅ Setup complete!"
echo ""
echo "You can now run:"
echo "  forge test              # Run all tests"
echo "  forge test -vvv         # Run with verbose output"
echo "  forge test --gas-report # Run with gas report"
echo ""
