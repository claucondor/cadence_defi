# Cadence DeFi Project

A decentralized finance (DeFi) project built on Flow blockchain using Cadence smart contracts.

## Overview

This project implements DeFi protocols and smart contracts using the Cadence programming language for the Flow blockchain.

## Project Structure

```
cadence_defi/
├── contracts/      # Cadence smart contracts
├── scripts/        # Read-only Cadence scripts
├── transactions/   # Cadence transactions
└── tests/          # Contract tests
```

## Getting Started

### Prerequisites

- Flow CLI installed
- Node.js (v16+)
- Flow emulator

### Installation

```bash
# Install Flow CLI
sh -ci "$(curl -fsSL https://storage.googleapis.com/flow-cli/install.sh)"

# Install dependencies
npm install
```

### Development

```bash
# Start Flow emulator
flow emulator

# Deploy contracts
flow project deploy

# Run tests
npm test
```

## License

MIT
