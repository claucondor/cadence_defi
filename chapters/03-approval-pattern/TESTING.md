# Testing Guide - Capítulo 3: ERC20 Approval Pattern

## 🎯 Enfoque Profesional

Este proyecto usa herramientas profesionales estándar de la industria:
- **Foundry** para tests de Solidity
- **Flow CLI** para tests de Cadence

Ambas son reproducibles, automatizables, y se pueden integrar en CI/CD.

---

## 🔨 Solidity Tests (Foundry)

### Setup Rápido

```bash
cd chapters/03-approval-pattern/evm
./setup.sh  # Instala todo automáticamente
```

### Qué se prueba

- ✅ **ApprovalExploit.t.sol** - Demuestra vulnerabilidades reales:
  - Infinite approvals
  - SWC-114 race condition (150 tokens de 100 approval)
  - Malicious DEX draining funds
  - Li.Fi-style bridge exploit ($9.7M attack)
  - Approvals never expire

- ✅ **ApprovalProtection.t.sol** - Soluciones modernas funcionan:
  - increaseAllowance/decreaseAllowance (OpenZeppelin)
  - EIP-2612 Permit (gasless approvals)
  - Permit2-style (expirable approvals)
  - Secure bridge (Li.Fi fix)

**📖 Ver [evm/README.md](./evm/README.md) para documentación completa**

---

## 🌊 Cadence Tests (Flow CLI)

### Setup Rápido

```bash
cd chapters/03-approval-pattern/cadence
./setup.sh  # Instala Flow CLI y ejecuta tests
```

### Qué se prueba

- ✅ **CapabilityPattern_test.cdc** - Demuestra que approvals son innecesarios:
  - Direct transfers (no approval needed)
  - DEX swaps sin approvals
  - Infinite approvals son imposibles
  - Instant capability revocation
  - No SWC-114 race conditions
  - Type-safe capabilities

**📖 Ver [cadence/README.md](./cadence/README.md) para documentación completa**

---

## ⚡ Quick Start

```bash
# Setup Solidity (Foundry)
cd evm && ./setup.sh

# Setup Cadence (Flow)
cd ../cadence && ./setup.sh
```

---

## 📚 Documentación Detallada

- **Solidity**: [evm/README.md](./evm/README.md)
  - Instalación de Foundry
  - Tests de exploits (Li.Fi, SWC-114, etc.)
  - Tests de protecciones (Permit, Permit2)
  - Gas reports
  - Troubleshooting

- **Cadence**: [cadence/README.md](./cadence/README.md)
  - Instalación de Flow CLI
  - Capability model explanation
  - Comparación con ERC20 approvals
  - Troubleshooting

---

## ✅ Verificación Rápida

```bash
# Verificar que todo funciona
cd evm && forge test -vv
cd ../cadence && flow test tests/CapabilityPattern_test.cdc
```

**Resultado esperado**: Todos los tests pasan ✅

---

## 🎓 Qué Aprenderás

### Tests de Solidity (Exploits)

1. **Infinite Approval Risk**
   - Por qué `approve(spender, MAX_UINT)` es peligroso
   - Li.Fi hack ($9.7M) - cómo funcionó
   - SenecaUSD hack ($6.5M) - qué salió mal

2. **SWC-114 Race Condition**
   - Cómo un atacante puede extraer 150 tokens de 100 aprobados
   - Front-running de cambios de approval
   - Por qué `approve(0)` antes de cambiar NO es suficiente

3. **Li.Fi-Style Exploit**
   - Bridge con `call()` sin validación
   - Cómo drenar todos los usuarios con approvals activos
   - Impacto real: $9.7M robados en Julio 2024

4. **Approval Never Expires**
   - Approvals persisten para siempre
   - Contratos hackeados años después siguen siendo peligrosos
   - Por qué la mayoría de usuarios nunca revoca

### Tests de Solidity (Soluciones)

1. **increaseAllowance/decreaseAllowance**
   - Previene race conditions
   - Más seguro que approve directo
   - Pero NO resuelve infinite approvals

2. **EIP-2612 Permit**
   - Gasless approvals con firmas off-chain
   - Una transacción vs dos
   - Usado por DAI, USDC, USDT moderno

3. **Permit2-Style**
   - Approvals con expiración automática
   - Batch permits
   - Transfer directo sin allowance
   - Usado por Uniswap

4. **Secure Bridge Pattern**
   - Whitelisting de targets
   - Validación antes de `call()`
   - Li.Fi fix implementation

### Tests de Cadence

1. **Direct Transfers**
   - No se necesitan approvals para transfers
   - Ownership directo de resources
   - Una transacción para todo

2. **DEX Swaps Sin Approvals**
   - Swap directo con resources
   - DEX no tiene acceso persistente
   - Más seguro que ERC20

3. **Capabilities > Approvals**
   - Receiver capability (público, seguro)
   - Provider capability (privado, revocable)
   - Balance capability (read-only)
   - Tipo-seguras (compilador fuerza permisos)

4. **Revocación Instantánea**
   - `unlink()` invalida todas las referencias
   - Sin gas necesario
   - Imposible usar capability revocada

---

## 📊 Comparación de Tests

| Aspecto | Solidity Exploits | Solidity Solutions | Cadence |
|---------|-------------------|-------------------|---------|
| **Ataques funcionan** | ✅ Sí | ❌ Bloqueados | ❌ Imposibles |
| **Infinite approvals** | ✅ Comunes | ⚠️ Posibles | ❌ No existen |
| **Race conditions** | ✅ SWC-114 | ⚠️ Con increaseAllowance | ❌ Imposibles |
| **Requiere revocación** | ✅ Sí (manual) | ✅ Sí (manual) | ❌ Automática |
| **Gas cost** | Alto (2-3 tx) | Alto (1-2 tx) | Bajo (1 tx) |
| **Hacks reales** | $16.2M+ (2024) | Menos | $0 |

---

## 🐛 Troubleshooting Común

### Solidity (Foundry)

**Error: "forge: command not found"**
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

**Error: "Build failed"**
```bash
forge clean
forge install --no-commit
forge build
```

**Error: "Test fails unexpectedly"**
```bash
forge test -vvvv  # Extra verbosity
```

### Cadence (Flow CLI)

**Error: "flow: command not found"**
```bash
sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"
flow version
```

**Error: "cannot find declaration Test"**
```bash
# Actualizar Flow CLI a v1.18.0+
flow version
```

**Error: "Could not borrow capability"**
- Esto es esperado en algunos tests
- Demuestra que las capabilities revocadas no funcionan
- Es una feature de seguridad, no un bug

---

## 🔗 Recursos Adicionales

### Documentación
- [Foundry Book](https://book.getfoundry.sh/)
- [Flow CLI Docs](https://developers.flow.com/tools/flow-cli)
- [Cadence Capabilities Guide](https://developers.flow.com/cadence/language/capabilities)

### EIPs y Estándares
- [EIP-20 (ERC20)](https://eips.ethereum.org/EIPS/eip-20)
- [EIP-2612 (Permit)](https://eips.ethereum.org/EIPS/eip-2612)
- [SWC-114 (Race Condition)](https://swcregistry.io/docs/SWC-114)
- [Uniswap Permit2](https://github.com/Uniswap/permit2)

### Hacks Analizados
- [Li.Fi Bridge Hack Analysis](https://twitter.com/lifinance/status/1680959932034359297)
- [SenecaUSD Post-mortem](https://medium.com/@SenecaUSD/seneca-usd-incident-post-mortem-aef5e5c8de57)
- [BeautyChain (BEC) Analysis](https://medium.com/secbit-media/a-disastrous-vulnerability-found-in-smart-contracts-of-beautychain-bec-dbf24ddbc30e)

### Herramientas
- [Revoke.cash](https://revoke.cash/) - Revocar approvals peligrosos
- [Etherscan Token Approvals](https://etherscan.io/tokenapprovalchecker)
- [Rabby Wallet](https://rabby.io/) - Alertas de infinite approvals

---

## 🎯 Flujo de Testing Recomendado

### 1. Entender el Problema (30 min)

```bash
# Primero, ve cómo funcionan los ataques
cd evm
forge test --match-contract ApprovalExploit -vv

# Lee los logs, entiende cada ataque:
# - Infinite approvals
# - SWC-114 race condition
# - Li.Fi exploit
```

### 2. Ver las Soluciones (20 min)

```bash
# Ahora ve cómo Solidity intenta resolverlo
forge test --match-contract ApprovalProtection -vv

# Observa que son "parches" sobre el problema original
```

### 3. Comparar con Cadence (15 min)

```bash
# Finalmente, ve cómo Cadence lo resuelve fundamentalmente
cd ../cadence
flow test tests/CapabilityPattern_test.cdc

# Nota cómo NO hay approvals - el problema no existe
```

### 4. Leer Documentación (30 min)

```bash
# Lee las comparaciones lado a lado
cat comparativa.md

# Lee las explicaciones detalladas
cat evm/README.md
cat cadence/README.md
```

**Tiempo total**: ~1.5 horas para entender completamente el patrón.

---

## 💡 Insights Clave

### ERC20 Approvals (Solidity)

**El problema fundamental**:
```solidity
// Balance model = números en un mapping
mapping(address => uint256) balances;

// Para que B mueva tokens de A:
// 1. A aprueba a B
// 2. B llama transferFrom(A, destino, amount)

// ⚠️ Esta "aprobación" es permanente hasta que A la revoque
```

### Capabilities (Cadence)

**La solución arquitectural**:
```cadence
// Resource model = ownership directo
let myVault: @Vault <- ...

// Para que B reciba tokens de A:
// 1. A retira los tokens
// 2. A los envía directamente a B

// ✅ B NUNCA tiene acceso a los fondos de A
// ✅ No hay "aprobación" que pueda ser explotada
```

---

## 🎯 Próximos Pasos

Después de completar estos tests:

1. ✅ Entiendes por qué ERC20 approvals son peligrosos
2. ✅ Conoces los hacks reales (Li.Fi $9.7M, etc.)
3. ✅ Sabes qué soluciones existen (Permit, Permit2)
4. ✅ Comprendes que Cadence elimina el problema fundamentalmente
5. → **Siguiente**: Implementa revocación de approvals en tus dApps

---

**Actualizado**: 2025-11-14
**Estado**: Capítulo 3 completo y testeado ✅
