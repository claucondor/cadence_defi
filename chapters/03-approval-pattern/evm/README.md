# Testing ERC20 Approval Pattern - Foundry

## 🎯 Overview

This directory contains **Foundry tests** that demonstrate:
1. ✅ **ERC20 approval vulnerabilities** (infinite approvals, SWC-114, Li.Fi-style hacks)
2. ✅ **Modern solutions** (increaseAllowance, EIP-2612 Permit, Permit2)
3. ✅ **Real-world attack scenarios** (Li.Fi $9.7M, SenecaUSD $6.5M)

---

## 📁 File Structure

```
evm/
├── problema.sol                  # Vulnerable ERC20 + attack contracts
├── workaround.sol                # Solutions (Permit, Permit2, etc.)
├── test/
│   ├── ApprovalExploit.t.sol        # Attack demonstrations
│   └── ApprovalProtection.t.sol     # Solution tests
├── foundry.toml                  # Foundry config
└── setup.sh                      # Auto-setup script
```

---

## 🔨 Quick Start

### Option 1: Automated Setup
```bash
cd chapters/03-approval-pattern/evm
./setup.sh
```

### Option 2: Manual Setup
```bash
# Install dependencies
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts --no-commit

# Build
forge build

# Run tests
forge test -vv
```

---

## 🧪 Tests Overview

### Test 1: ApprovalExploit.t.sol (Attacks Work)

**Purpose**: Demonstrate real-world approval vulnerabilities

```bash
forge test --match-contract ApprovalExploit -vv
```

**Key tests**:
- ✅ `test_InfiniteApprovalAllowed()` - Shows infinite approvals are common
- ✅ `test_MaliciousDEX_DrainsApprovedFunds()` - Malicious contract steals all tokens
- ✅ `test_SWC114_RaceCondition()` - Multiple withdrawal attack (150 tokens from 100 approval)
- ✅ `test_LiFiBridgeExploit()` - Li.Fi-style bridge hack ($9.7M attack)
- ✅ `test_ApprovalNeverExpires()` - Approvals persist forever

**Expected output**: All tests PASS (attacks work on vulnerable code)

---

### Test 2: ApprovalProtection.t.sol (Solutions Work)

**Purpose**: Show how modern solutions prevent attacks

```bash
forge test --match-contract ApprovalProtection -vv
```

**Key tests**:
- ✅ `test_IncreaseAllowance_PreventsRaceCondition()` - OpenZeppelin solution
- ✅ `test_Permit_GaslessApproval()` - EIP-2612 Permit (one transaction)
- ✅ `test_Permit2Style_ExpirableApprovals()` - Auto-expiring approvals
- ✅ `test_Permit2_DirectTransfer()` - Transfer without creating allowance
- ✅ `test_SecureBridge_RejectsUnauthorizedTargets()` - Li.Fi fix

**Expected output**: All tests PASS (protections work)

---

## 🎯 Key Vulnerabilities Demonstrated

### 1. Infinite Approval Risk

```solidity
// Common in production
token.approve(uniswapRouter, type(uint256).max);  // ∞ approval
```

**Risk**: If router is hacked, ALL your tokens are stolen.

**Real examples**:
- Li.Fi Bridge (July 2024): $9.7M stolen
- SenecaUSD (Feb 2024): $6.5M stolen

### 2. SWC-114: Multiple Withdrawal Attack

```solidity
// User approves 100 tokens
token.approve(spender, 100);

// User changes mind, wants to approve 50
token.approve(spender, 50);

// ⚠️ ATTACK: Spender front-runs and spends 100 + 50 = 150 tokens!
```

### 3. Li.Fi-Style Bridge Exploit

```solidity
// Vulnerable bridge function
function bridgeAndSwap(address target, bytes calldata data) external {
    target.call(data);  // ⚠️ No validation!
}

// Attacker calls:
target = tokenAddress
data = transferFrom(victim, attacker, balance)
// Result: Drains all tokens from users with approvals
```

---

## 📊 Gas Reports

```bash
forge test --gas-report
```

**Expected gas costs**:
- `approve()`: ~46,000 gas
- `increaseAllowance()`: ~48,000 gas
- `permit()`: ~83,000 gas (includes signature verification)
- `permitTransfer()`: ~91,000 gas (direct transfer)

---

## 🔍 Coverage Report

```bash
forge coverage
```

**Expected coverage**: ~98%+ (all attack vectors tested)

---

## 🐛 Troubleshooting

### Error: "forge: command not found"

**Solution**:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Error: "Build failed"

**Solution**:
```bash
forge clean
forge install --no-commit
forge build
```

### Error: "Test fails unexpectedly"

**Solution**:
```bash
# Run with extra verbosity
forge test -vvvv

# Check specific test
forge test --match-test test_LiFiBridgeExploit -vvvv
```

---

## 📝 Code Examples

### Vulnerable Pattern (Common in 2024!)

```solidity
// User approves DEX
token.approve(dexAddress, type(uint256).max);  // ∞

// User swaps
dex.swap(tokenA, tokenB, amount);

// ⚠️ Problem: Approval persists FOREVER
// If DEX is hacked → all tokens stolen
```

### Solution 1: increaseAllowance

```solidity
// Instead of changing approval
token.increaseAllowance(spender, 50);  // Add 50
token.decreaseAllowance(spender, 30);  // Remove 30

// ✅ No race condition
```

### Solution 2: EIP-2612 Permit

```solidity
// User signs off-chain (0 gas)
bytes memory signature = signPermit(...);

// Contract uses signature (1 transaction)
token.permit(owner, spender, amount, deadline, v, r, s);
token.transferFrom(owner, recipient, amount);

// ✅ One transaction instead of two
// ✅ User doesn't pay gas for approve
```

### Solution 3: Permit2-Style

```solidity
// Approval with automatic expiry
token.approve(spender, amount, expiration);

// After expiration:
token.transferFrom(from, to, amount);  // ❌ Reverts

// ✅ Approvals expire automatically
// ✅ Less risk of forgotten approvals
```

---

## 🎓 Learning Objectives

After running these tests, you should understand:

1. **Why infinite approvals are dangerous** (Li.Fi $9.7M hack)
2. **How SWC-114 race conditions work** (150 tokens from 100 approval)
3. **EIP-2612 Permit benefits** (gasless approvals, better UX)
4. **Permit2 improvements** (expirable approvals, batch permits)
5. **Why Cadence doesn't have this problem** (no approvals needed!)

---

## 🔗 Related Resources

- [EIP-20 (ERC20)](https://eips.ethereum.org/EIPS/eip-20)
- [SWC-114: Transaction Order Dependence](https://swcregistry.io/docs/SWC-114)
- [EIP-2612 (Permit)](https://eips.ethereum.org/EIPS/eip-2612)
- [Uniswap Permit2](https://github.com/Uniswap/permit2)
- [Li.Fi Hack Post-mortem](https://twitter.com/lifinance/status/1680959932034359297)
- [Revoke.cash](https://revoke.cash/) - Revoke dangerous approvals

---

## ↩️ Back to Chapter

[← Back to Chapter 3 Overview](../README.md)
