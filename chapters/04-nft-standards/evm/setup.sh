#!/bin/bash

# Setup script for Chapter 04: NFT Standards Evolution
# Installs Foundry dependencies

echo "📦 Installing Foundry dependencies..."

# Install forge-std
forge install foundry-rs/forge-std --no-commit

# Install OpenZeppelin contracts
forge install OpenZeppelin/openzeppelin-contracts@v5.0.0 --no-commit

# Install ERC721A
forge install chiru-labs/ERC721A --no-commit

echo "✅ Dependencies installed!"
echo ""
echo "To compile:"
echo "  forge build"
echo ""
echo "To run tests:"
echo "  forge test -vv"
echo ""
echo "To run gas comparison:"
echo "  forge test --gas-report"
