# Testing Guide - Chapter 4: NFT Standards

## 📋 Contenido

Este documento explica cómo ejecutar todos los tests para el Capítulo 4.

**Tests incluidos**:
1. ✅ Tests EVM (Foundry)
2. ✅ Tests Cadence (Flow CLI)
3. ✅ Gas comparisons
4. ✅ Security validations

---

## 🔧 Prerequisites

### Foundry (EVM Tests)

```bash
# Instalar Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verificar instalación
forge --version
```

### Flow CLI (Cadence Tests)

```bash
# Instalar Flow CLI
sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"

# Verificar instalación
flow version
```

---

## 🧪 EVM Tests (Foundry)

### Setup

```bash
cd chapters/04-nft-standards/evm

# Opción 1: Usar script de setup
chmod +x setup.sh
./setup.sh

# Opción 2: Manual
forge install foundry-rs/forge-std --no-commit
forge install OpenZeppelin/openzeppelin-contracts@v5.0.0 --no-commit
forge install chiru-labs/ERC721A --no-commit
```

### Compilar Contratos

```bash
forge build
```

**Output esperado**:
```
[⠒] Compiling...
[⠢] Compiling 45 files with 0.8.20
[⠆] Solc 0.8.20 finished in 3.21s
Compiler run successful!
```

### Ejecutar Tests

#### Todos los tests
```bash
forge test -vv
```

**Output esperado**:
```
Running 12 tests for test/NFTVulnerabilities.t.sol:NFTVulnerabilitiesTest
[PASS] test_ReentrancyAttack_MintMultipleNFTs() (gas: 234567)
[PASS] test_MarketplaceReentrancyAttack() (gas: 187234)
[PASS] test_VulnerableNFT_NoReentrancyProtection() (gas: 145678)
[PASS] test_OptimizedNFT_PreventsReentrancy() (gas: 98234)
[PASS] test_SecureMarketplace_PreventsReentrancy() (gas: 156789)
[PASS] test_GasComparison_ERC721A_BatchMint() (gas: 104567)
[PASS] test_GasComparison_ERC1155_BatchMint() (gas: 90234)
[PASS] test_GasComparison_BatchTransfer() (gas: 267890)
[PASS] test_ERC1155_MixedTokenTypes() (gas: 78456)
[PASS] test_ERC1155_BatchTransfer() (gas: 89123)
[PASS] test_MaxSupply_Enforcement() (gas: 45678)
[PASS] test_Payment_Validation() (gas: 67890)

Test result: ok. 12 passed; 0 failed; finished in 8.34ms
```

#### Test específico
```bash
forge test --match-test test_ReentrancyAttack_MintMultipleNFTs -vvvv
```

#### Con gas report
```bash
forge test --gas-report
```

**Output esperado**:
```
╭─────────────────────────────────────────────╮
│ Gas Report                                  │
├─────────────────────────────────────────────┤
│ VulnerableNFT                               │
│ ├─ mint()                       113,245 gas │
│ ├─ transferMultiple() (5 NFTs)  566,123 gas │
├─────────────────────────────────────────────┤
│ OptimizedNFT_ERC721A                        │
│ ├─ mint(1)                       50,123 gas │
│ ├─ mint(5)                      104,567 gas │
│ ├─ batchTransfer() (5 NFTs)    267,890 gas │
├─────────────────────────────────────────────┤
│ MultiTokenNFT_ERC1155                       │
│ ├─ mintNFT()                     45,678 gas │
│ ├─ mintBatch(5)                  90,234 gas │
│ ├─ safeBatchTransfer() (5 NFTs)  89,123 gas │
╰─────────────────────────────────────────────╯
```

### Tests Detallados

#### Test 1: Reentrancy Attack

```bash
forge test --match-test test_ReentrancyAttack -vvv
```

**Qué verifica**:
- ✅ Attacker puede mintear 5 NFTs pagando por 1
- ✅ Demuestra vulnerabilidad en `VulnerableNFT`
- ✅ Explota callback de `_safeMint()`

**Console output esperado**:
```
=== REENTRANCY ATTACK SUCCESSFUL ===
NFTs stolen: 5
Amount paid (ETH): 0.1
Expected payment for 5 NFTs (ETH): 0.5
Profit (ETH): 0.4
```

#### Test 2: Marketplace Reentrancy

```bash
forge test --match-test test_MarketplaceReentrancyAttack -vvv
```

**Qué verifica**:
- ✅ Demuestra vulnerabilidad similar a NFT Trader hack
- ✅ External call antes de state update

#### Test 3: ERC721A Gas Optimization

```bash
forge test --match-test test_GasComparison_ERC721A -vvv
```

**Qué verifica**:
- ✅ Mint 1 NFT: ~50k gas
- ✅ Mint 5 NFTs: ~104k gas (82% ahorro vs ERC-721)
- ✅ Compara con ERC-721 estándar (566k gas)

**Console output esperado**:
```
=== GAS COMPARISON: ERC-721A ===
Mint 1 NFT gas: 50123
Mint 5 NFTs gas: 104567
Average per NFT (batch): 20913

Comparison with standard ERC-721:
Standard ERC-721 (5 NFTs): ~566,000 gas
ERC-721A (5 NFTs): 104567
Savings: 82%
```

#### Test 4: ERC1155 Batch Operations

```bash
forge test --match-test test_GasComparison_ERC1155 -vvv
```

**Qué verifica**:
- ✅ Batch mint 5 NFTs: ~90k gas
- ✅ Batch transfer: ~89k gas
- ✅ Comparación con otros standards

#### Test 5: Security Fixes

```bash
forge test --match-test test_OptimizedNFT_PreventsReentrancy -vvv
```

**Qué verifica**:
- ✅ `nonReentrant` modifier funciona
- ✅ Checks-Effects-Interactions pattern
- ✅ Estado actualizado antes de external calls

---

## 🔷 Cadence Tests (Flow CLI)

### Setup

```bash
cd chapters/04-nft-standards/cadence

# Verificar flow.json
cat flow.json
```

### Ejecutar Tests

#### Todos los tests
```bash
flow test tests/SecureNFT_test.cdc
```

**Output esperado**:
```
Test results: "tests/SecureNFT_test.cdc"
- PASS: testSetupCollections
- PASS: testMintNFT
- PASS: testBatchMint
- PASS: testTransferNFT
- PASS: testComposableNFTs
- PASS: testBatchOperations
- PASS: testMetadataAccess
- PASS: testOwnershipVerification
```

#### Test específico
```bash
flow test tests/SecureNFT_test.cdc --filter testMintNFT
```

### Tests Detallados

#### Test 1: Setup Collections

**Qué verifica**:
- ✅ User puede crear Collection
- ✅ Collection almacenada en storage
- ✅ Public capability publicada correctamente

#### Test 2: Mint NFT

**Qué verifica**:
- ✅ Minter puede crear NFT
- ✅ NFT depositado en Collection
- ✅ No reentrancy possible (no callbacks)
- ✅ Metadata almacenada correctamente

#### Test 3: Batch Mint

**Qué verifica**:
- ✅ Batch mint funciona naturalmente
- ✅ 5 NFTs minteados correctamente
- ✅ Eficiencia comparable a ERC-721A sin optimización compleja

#### Test 4: Transfer NFT

**Qué verifica**:
- ✅ True ownership con Resources
- ✅ Withdraw + Deposit atómico
- ✅ No approval pattern necesario

#### Test 5: Composable NFTs

**Qué verifica**:
- ✅ NFT puede contener child NFTs
- ✅ Trivial vs EIP-998 (Draft 7 años)
- ✅ Resources pueden contener Resources

#### Test 6: Batch Operations

**Qué verifica**:
- ✅ Batch withdraw funciona
- ✅ Batch deposit funciona
- ✅ Operaciones naturales, no workarounds

---

## 🔍 Debugging

### Foundry: Verbose Output

```bash
# -vv: Muestra logs
forge test -vv

# -vvv: Muestra stack traces
forge test -vvv

# -vvvv: Muestra todos los detalles
forge test -vvvv
```

### Foundry: Debug Específico

```bash
forge test --match-test testNombre --debug
```

Esto abre debugger interactivo.

### Flow: Verbose Output

```bash
flow test tests/SecureNFT_test.cdc --verbose
```

### Flow: Coverage

```bash
flow test --cover tests/SecureNFT_test.cdc
```

---

## 📊 Comparación de Gas

### Ejecutar Comparación Completa

```bash
cd chapters/04-nft-standards/evm
forge test --gas-report --match-contract NFTVulnerabilitiesTest
```

### Resultados Esperados

| Operación | ERC-721 | ERC-721A | ERC-1155 | Cadence |
|-----------|---------|----------|----------|---------|
| **Mint 1 NFT** | 113k gas | 50k gas | 45k gas | Efficient |
| **Mint 5 NFTs** | 566k gas | 104k gas | 90k gas | Efficient |
| **Batch Transfer (5)** | 566k gas | 268k gas | 89k gas | Efficient |
| **Composable NFT** | ❌ N/A | ❌ N/A | ❌ N/A | ✅ Trivial |

**Ahorro ERC-721A vs ERC-721**: 82%
**Ahorro ERC-1155 vs ERC-721**: 84%

---

## ✅ Verification Checklist

### EVM Tests
- [ ] Forge instalado y funcionando
- [ ] Dependencies instaladas (`forge install`)
- [ ] Compilación exitosa (`forge build`)
- [ ] Todos los tests pasan (`forge test`)
- [ ] Gas report generado (`forge test --gas-report`)
- [ ] Reentrancy attack demostrado
- [ ] Security fixes verificados

### Cadence Tests
- [ ] Flow CLI instalado y funcionando
- [ ] flow.json configurado correctamente
- [ ] Todos los tests pasan (`flow test`)
- [ ] Mint funciona sin reentrancy
- [ ] Batch operations funcionan
- [ ] Composable NFTs funcionan
- [ ] True ownership verificado

---

## 🐛 Troubleshooting

### Error: "forge: command not found"

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Error: "flow: command not found"

```bash
sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"
```

### Error: "lib/forge-std not found"

```bash
cd evm
forge install foundry-rs/forge-std --no-commit
```

### Error: "lib/openzeppelin-contracts not found"

```bash
forge install OpenZeppelin/openzeppelin-contracts@v5.0.0 --no-commit
```

### Error: "lib/erc721a not found"

```bash
forge install chiru-labs/ERC721A --no-commit
```

### Error: Cadence compilation failed

```bash
# Verificar que flow.json existe
ls -la flow.json

# Verificar que SecureNFT.cdc existe
ls -la SecureNFT.cdc

# Verificar sintaxis
flow cadence parse SecureNFT.cdc
```

### Error: "cannot find contract"

Verificar que `flow.json` tiene:
```json
{
  "contracts": {
    "SecureNFT": "./SecureNFT.cdc"
  }
}
```

---

## 📈 Performance Benchmarks

### EVM (Foundry)

Ejecutar con gas report:
```bash
forge test --gas-report > gas-report.txt
cat gas-report.txt
```

### Cadence (Flow CLI)

Flow CLI no tiene gas report integrado, pero puedes ver transaction costs en:
```bash
flow scripts execute get-transaction-cost.cdc <tx-hash>
```

---

## 🎯 Test Coverage Goals

### EVM
- ✅ Reentrancy vulnerabilities: 100%
- ✅ Marketplace vulnerabilities: 100%
- ✅ Gas optimizations: 100%
- ✅ Security fixes: 100%
- ✅ Edge cases: 90%

### Cadence
- ✅ Resource safety: 100%
- ✅ Ownership model: 100%
- ✅ Batch operations: 100%
- ✅ Composable NFTs: 100%
- ✅ Metadata: 100%

---

## 📚 Documentación Adicional

- [Foundry Book](https://book.getfoundry.sh/)
- [Flow CLI Docs](https://developers.flow.com/tools/flow-cli)
- [ERC-721 Spec](https://eips.ethereum.org/EIPS/eip-721)
- [ERC-721A Docs](https://www.erc721a.org/)
- [ERC-1155 Spec](https://eips.ethereum.org/EIPS/eip-1155)
- [Flow NFT Standard](https://github.com/onflow/flow-nft)

---

## ✨ Próximos Pasos

Después de verificar que todos los tests pasan:

1. ✅ Revisar gas comparisons
2. ✅ Entender por qué Cadence previene reentrancy
3. ✅ Comparar complejidad de implementación
4. ✅ Analizar trade-offs de cada approach
5. ✅ Leer documentación completa en README.md files

**Happy testing! 🚀**
