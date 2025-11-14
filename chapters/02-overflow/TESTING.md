# Testing Guide - Capítulo 2: Integer Overflow/Underflow

## 🎯 Enfoque Profesional

Este proyecto usa herramientas profesionales estándar de la industria:
- **Foundry** para tests de Solidity
- **Flow CLI** para tests de Cadence

Ambas son reproducibles, automatizables, y se pueden integrar en CI/CD.

---

## 🔨 Solidity Tests (Foundry)

### Setup Rápido

```bash
cd chapters/02-overflow/evm
./setup.sh  # Instala todo automáticamente
```

### Qué se prueba

- ✅ **OverflowExploit.t.sol** - BeautyChain-style attack funciona en Solidity <0.8
- ✅ **OverflowProtection.t.sol** - Solidity 0.8+ previene el ataque automáticamente

**📖 Ver [evm/README.md](./evm/README.md) para documentación completa**

---

## 🌊 Cadence Tests (Flow CLI)

### Setup Rápido

```bash
cd chapters/02-overflow/cadence
./setup.sh  # Instala Flow CLI y ejecuta tests
```

### Qué se prueba

- ✅ **OverflowSafe_test.cdc** - Overflow/underflow son imposibles por diseño nativo

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
  - Tests de exploit (BeautyChain attack)
  - Tests de protección (Solidity 0.8+)
  - Gas reports
  - Troubleshooting

- **Cadence**: [cadence/README.md](./cadence/README.md)
  - Instalación de Flow CLI
  - Tests de seguridad nativa
  - Comparación con Solidity
  - Troubleshooting

---

## ✅ Verificación Rápida

```bash
# Verificar que todo funciona
cd evm && forge test -vv
cd ../cadence && flow test tests/OverflowSafe_test.cdc
```

**Resultado esperado**: Todos los tests pasan ✅

---

## 🎓 Qué Aprenderás

### Tests de Solidity

1. **BeautyChain Exploit**: Cómo funcionó el hack real
2. **Overflow wrapping**: `MAX + 1 = 0` en Solidity <0.8
3. **Underflow wrapping**: `0 - 1 = MAX` en Solidity <0.8
4. **Protección automática**: Solidity 0.8+ revierte automáticamente
5. **unchecked{}**: Optimización cuando sabes que es seguro

### Tests de Cadence

1. **Protección nativa**: Cadence NUNCA tuvo overflow bugs
2. **Sin bibliotecas**: No necesita SafeMath
3. **Zero overhead**: Sin costo de gas adicional
4. **Imposible por diseño**: El compilador y VM lo previenen

---

## 📊 Comparación de Tests

| Aspecto | Solidity Tests | Cadence Tests |
|---------|----------------|---------------|
| **Ataque funciona** | ✅ Sí (en <0.8) | ❌ Imposible |
| **Protección existe** | ✅ Sí (en 0.8+) | ✅ Siempre |
| **Requiere bibliotecas** | ⚠️ Sí (pre-0.8) | ❌ No |
| **Gas overhead** | ~200 gas | 0 gas |

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
# Si es viejo, reinstalar
```

---

## 🔗 Recursos Adicionales

### Documentación
- [Foundry Book](https://book.getfoundry.sh/)
- [Flow CLI Docs](https://developers.flow.com/tools/flow-cli)
- [Cadence Testing Guide](https://developers.flow.com/cadence/testing-framework)

### Hacks Reales
- [BeautyChain Analysis](https://medium.com/secbit-media/a-disastrous-vulnerability-found-in-smart-contracts-of-beautychain-bec-dbf24ddbc30e)
- [batchOverflow Bug Report](https://peckshield.medium.com/alert-new-batchoverflow-bug-in-multiple-erc20-smart-contracts-cve-2018-10299-511067db6536)

### Soluciones
- [Solidity 0.8.0 Release](https://blog.soliditylang.org/2020/12/16/solidity-0.8.0-release-announcement/)
- [OpenZeppelin SafeMath](https://docs.openzeppelin.com/contracts/2.x/api/math)

---

## 🎯 Próximos Pasos

Después de completar estos tests:

1. ✅ Entiendes cómo funcionó BeautyChain hack
2. ✅ Sabes por qué Solidity 0.8+ es necesario
3. ✅ Comprendes que Cadence nunca tuvo este problema
4. → **Siguiente**: [Capítulo 3: ERC20 Approval Pattern](../03-approval-pattern/)

---

**Actualizado**: 2025-11-14
