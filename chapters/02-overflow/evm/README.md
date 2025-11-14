# Testing Overflow Protection - Foundry

## 🎯 Overview

This directory contains **Foundry tests** that demonstrate:
1. ✅ **BeautyChain-style overflow exploit** on vulnerable Solidity <0.8 code
2. ✅ **Automatic protection** in Solidity 0.8+
3. ✅ **unchecked{}** optimization patterns

---

## 📁 File Structure

```
evm/
├── problema.sol              # Vulnerable contract (Solidity 0.7.x)
├── workaround.sol            # Protected contracts (0.8+, unchecked)
├── test/
│   ├── OverflowExploit.t.sol    # Exploit tests (attack works)
│   └── OverflowProtection.t.sol # Protection tests (attack blocked)
├── foundry.toml              # Foundry config
└── setup.sh                  # Auto-setup script
```

---

## 🔨 Quick Start

### Option 1: Automated Setup
```bash
cd chapters/02-overflow/evm
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

### Test 1: OverflowExploit.t.sol (Attack Works)

**Purpose**: Demonstrate how BeautyChain hack worked in Solidity <0.8

```bash
forge test --match-contract OverflowExploit -vv
```

**Key tests**:
- ✅ `test_BeautyChainExploit()` - Creates tokens from nothing via overflow
- ✅ `test_Overflow()` - `MAX + 1 = 0` (wraps)
- ✅ `test_Underflow()` - `0 - 1 = MAX` (wraps)

**Expected output**: All tests PASS (attack works on vulnerable code)

---

### Test 2: OverflowProtection.t.sol (Attack Blocked)

**Purpose**: Show Solidity 0.8+ automatic protection works

```bash
forge test --match-contract OverflowProtection -vv
```

**Key tests**:
- ✅ `test_Solidity8_PreventsOverflow()` - Transaction reverts
- ✅ `test_UncheckedOptimization()` - Optimization pattern works

**Expected output**: All tests PASS (protection works)

---

## 📊 Gas Reports

```bash
forge test --gas-report
```

**Expected gas costs**:
- Solidity <0.8 (no checks): ~21,000 gas
- Solidity 0.8+ (with checks): ~21,200 gas (+200)
- unchecked{}: ~21,000 gas (optimized)

---

## 🔍 Coverage Report

```bash
forge coverage
```

**Expected coverage**: ~95%+ (all vulnerable paths tested)

---

## 🐛 Troubleshooting

### Error: "forge: command not found"

**Solution**:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Error: "forge build failed"

**Solution**:
```bash
# Clean and rebuild
forge clean
forge install --no-commit
forge build
```

### Error: Tests fail unexpectedly

**Solution**:
```bash
# Ensure correct Solidity version
forge build --force
forge test -vvvv  # Extra verbosity for debugging
```

---

## 📝 Code Examples

### Vulnerable Code (problema.sol)

```solidity
// Solidity 0.7.0 - VULNERABLE
function batchTransfer(address[] memory _receivers, uint256 _value) public {
    uint cnt = _receivers.length;
    uint256 amount = uint256(cnt) * _value;  // ⚠️ OVERFLOW
    require(amount <= balances[msg.sender]);
    // ... transfers happen
}
```

**Attack vector**:
- Call with `_receivers = [addr1, addr2]` and `_value = 2^255`
- `amount = 2 * 2^255 = 2^256 = 0` (overflow!)
- Creates `2^255 * 2` tokens from nothing

### Protected Code (workaround.sol)

```solidity
// Solidity 0.8+ - PROTECTED
function batchTransfer(address[] memory _receivers, uint256 _value) public {
    uint cnt = _receivers.length;
    uint256 amount = uint256(cnt) * _value;  // ✅ Auto-reverts on overflow
    require(amount <= balances[msg.sender]);
    // ... safe transfers
}
```

### Optimized Code (workaround.sol)

```solidity
// Solidity 0.8+ with unchecked optimization
function efficientLoop(uint256 n) public {
    for (uint256 i = 0; i < n; ) {
        // ... loop body ...

        unchecked {
            i++;  // Safe: i < n guarantees no overflow
        }
    }
}
```

---

## 🎓 Learning Objectives

After running these tests, you should understand:

1. **Why BeautyChain hack worked** (wrapping arithmetic)
2. **How Solidity 0.8+ fixes it** (automatic checks)
3. **When to use unchecked{}** (safe optimizations)
4. **Gas trade-offs** (~200 gas per checked operation)

---

## 🔗 Related Resources

- [BeautyChain Hack Analysis](https://medium.com/secbit-media/a-disastrous-vulnerability-found-in-smart-contracts-of-beautychain-bec-dbf24ddbc30e)
- [Solidity 0.8.0 Breaking Changes](https://docs.soliditylang.org/en/latest/080-breaking-changes.html)
- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin SafeMath](https://docs.openzeppelin.com/contracts/2.x/api/math)

---

## ↩️ Back to Chapter

[← Back to Chapter 2 Overview](../README.md)
