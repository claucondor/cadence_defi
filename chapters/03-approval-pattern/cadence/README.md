# Testing Capability Pattern - Cadence

## 🎯 Overview

This directory demonstrates how **Cadence eliminates the need for approvals** entirely through **Capability-Based Access Control**.

**Key insight**: While Solidity evolved through bandaid solutions (SafeMath → Permit → Permit2), Cadence was designed from the start with a fundamentally better model that makes approval vulnerabilities **impossible by design**.

---

## 📁 File Structure

```
cadence/
├── CapabilityPattern.cdc         # Capability-based token contract
├── tests/
│   └── CapabilityPattern_test.cdc   # Test suite
├── flow.json                     # Flow config
└── setup.sh                      # Auto-setup script
```

---

## 🔨 Quick Start

### Option 1: Automated Setup
```bash
cd chapters/03-approval-pattern/cadence
./setup.sh
```

### Option 2: Manual Setup
```bash
# Install Flow CLI (if not installed)
sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"

# Run tests
flow test tests/CapabilityPattern_test.cdc
```

---

## 🧪 Tests Overview

### CapabilityPattern_test.cdc

**Purpose**: Demonstrate how Cadence's capability model eliminates approval problems

```bash
flow test tests/CapabilityPattern_test.cdc
```

**Tests included**:
- ✅ `testDirectTransfer()` - No approval needed for transfers
- ✅ `testDEXSwapNoApproval()` - DEX swaps work without approvals
- ✅ `testNoInfiniteApproval()` - Infinite approvals are impossible
- ✅ `testCapabilityRevocation()` - Instant revocation (when needed)
- ✅ `testNoRaceCondition()` - SWC-114 is impossible
- ✅ `testTypeSafety()` - Compiler enforces permissions

**Expected behavior**:
- All tests pass ✅
- Demonstrates fundamental safety advantages
- Shows no bandaids or workarounds needed

---

## 💡 How Capabilities Eliminate Approvals

### The Fundamental Difference

**ERC20 Model** (Global State):
```solidity
// Global mapping of permissions
mapping(address => mapping(address => uint256)) allowances;

// Anyone can check and use these permissions
function transferFrom(address from, address to, uint256 amount) {
    require(allowances[from][msg.sender] >= amount);
    // ... transfer logic
}
```

**Cadence Model** (Unforgeable References):
```cadence
// Direct ownership - no global state
let vault <- vaultRef.withdraw(amount: 100.0)

// Transfer directly - no approval needed
receiver.deposit(from: <-vault)
```

---

## 🔑 Three Ways to Access Tokens

### 1. Direct Ownership (Most Common)

```cadence
transaction {
    prepare(signer: auth(BorrowValue) &Account) {
        // You own your vault - direct access
        let vaultRef = signer.storage.borrow<&Vault>(/storage/vault)!

        // Withdraw what you need
        let payment <- vaultRef.withdraw(amount: 100.0)

        // Send it directly
        receiverCap.borrow()!.deposit(from: <-payment)
    }
}
```

**Advantages**:
- ✅ No approval step
- ✅ One transaction
- ✅ No persistent permissions

### 2. Receiver Capability (Public, Safe)

```cadence
// Anyone can deposit TO you (like a mailbox)
let receiverCap = account.capabilities.get<&{Receiver}>(/public/receiver)

// But they can't withdraw FROM you
// This is SAFE to publish publicly
```

**Use cases**:
- Receiving payments
- Accepting deposits
- Public donation addresses

### 3. Provider Capability (Private, Rare)

```cadence
// Dangerous - allows withdrawals
// Only give to VERY trusted contracts
// And make it revocable!

let providerCap = account.capabilities.storage
    .issue<&{Provider}>(/storage/vault)

// Later: revoke instantly
account.capabilities.unpublish(/private/provider)
// ✅ All references immediately invalid
```

**Use cases**:
- Payment streaming contracts
- Automated bill pay
- Delegation with limits

---

## ⚖️ Comparison: DEX Swap

### Solidity (Traditional)

```solidity
// TX 1: User approves (pays gas)
token.approve(dexAddress, type(uint256).max);  // ∞ approval

// TX 2: User swaps (pays gas)
dex.swapExactTokensForTokens(...);

// ⚠️ Approval persists FOREVER
// Must manually revoke (most users don't):

// TX 3: Revoke (pays gas again)
token.approve(dexAddress, 0);
```

**Problems**:
- 3 transactions required (approve + swap + revoke)
- Users pay gas 3 times
- Most users never revoke
- If DEX is hacked → all approvals drained

### Solidity (With Permit)

```solidity
// User signs off-chain (0 gas)
bytes memory sig = signPermit(...);

// TX 1: Swap with permit (1 transaction)
dex.swapWithPermit(amount, deadline, v, r, s);

// ⚠️ Better, but approval still created temporarily
```

**Problems**:
- Still creates allowance (though in same tx)
- Complex signature UX (phishing risk)
- Requires Permit support (not all tokens have it)

### Cadence

```cadence
transaction {
    prepare(signer: auth(BorrowValue) &Account) {
        let vaultRef = signer.storage.borrow<&Vault>(/storage/vault)!

        // Withdraw + swap + deposit (ONE transaction)
        let toSwap <- vaultRef.withdraw(amount: 100.0)
        let result <- dex.swap(from: <-toSwap, minimumOut: 95.0)
        vaultRef.deposit(from: <-result)
    }
}
```

**Advantages**:
- ✅ ONE transaction total
- ✅ DEX NEVER has persistent access
- ✅ No approval to revoke
- ✅ If DEX is hacked → only affects current tx
- ✅ No signatures needed (signer is authenticated by transaction)

---

## 🛡️ Security Advantages

### 1. No Infinite Approvals

**ERC20**:
```solidity
token.approve(spender, type(uint256).max);  // ∞

// Result: Li.Fi hack ($9.7M), SenecaUSD ($6.5M)
```

**Cadence**:
```cadence
// Concept doesn't exist!
// You either own the resource or you don't
```

### 2. No SWC-114 Race Conditions

**ERC20**:
```solidity
// Approve 100
token.approve(spender, 100);

// Change to 50
token.approve(spender, 50);

// ⚠️ Spender can front-run and spend 150!
```

**Cadence**:
```cadence
// No global state to race on
// Each withdraw is direct and atomic
let payment <- vault.withdraw(amount: 50.0)
```

### 3. Instant Revocation

**ERC20**:
```solidity
// Revoke = set to zero (costs gas)
token.approve(spender, 0);  // New transaction, pays gas

// Problem: Most users never do this
```

**Cadence**:
```cadence
// Unlink capability
account.capabilities.unpublish(/private/provider)

// ✅ Instant - all references immediately invalid
// ✅ No gas needed (just unlink)
```

### 4. Type Safety

**ERC20**:
```solidity
// Spender can do ANYTHING with allowance
token.transferFrom(victim, attacker, allowance);
```

**Cadence**:
```cadence
// Capabilities are typed
Capability<&{Receiver}>   // Can ONLY deposit
Capability<&{Provider}>   // Can ONLY withdraw
Capability<&{Balance}>    // Can ONLY read

// Compiler enforces this!
```

---

## 🐛 Troubleshooting

### Error: "flow: command not found"

**Solution**:
```bash
sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"
flow version
```

### Error: "cannot find declaration Test"

**Solution**:
```bash
# Update Flow CLI to v1.18.0+
flow version

# If old, reinstall
brew upgrade flow-cli  # macOS
```

### Error: "Could not borrow capability"

**Explanation**: In production, this happens when:
- Capability was revoked
- Target resource was moved
- Wrong type specified

**This is GOOD** - it means the security model is working!

---

## 🎓 Learning Objectives

After exploring this code, you should understand:

1. **Why Cadence doesn't need approvals** (direct ownership model)
2. **How capabilities work** (unforgeable references with types)
3. **Why this is more secure** (no infinite approvals, no race conditions)
4. **Why this has better UX** (one transaction vs three)
5. **How to think differently** (resources vs balances)

---

## 🔗 Resources

- [Cadence Capabilities Guide](https://developers.flow.com/cadence/language/capabilities)
- [Resource-Oriented Programming](https://www.onflow.org/post/resource-oriented-programming)
- [Flow Access Control Best Practices](https://developers.flow.com/cadence/design-patterns)
- [Why Cadence is Different](https://www.onflow.org/post/flow-blockchain-cadence-programming-language-resources-assets)

---

## 💎 Key Insight

**ERC20 approvals exist because Solidity uses a balance model** (centralized ledger). Each "token" is just a number in a mapping.

**Cadence uses a resource model** (direct ownership). Each token is a real object you own. You don't need permission to use what you already own.

This fundamental design difference makes approval vulnerabilities **architecturally impossible** in Cadence.

---

## ↩️ Back to Chapter

[← Back to Chapter 3 Overview](../README.md)
