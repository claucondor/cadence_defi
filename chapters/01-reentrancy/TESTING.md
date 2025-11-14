# Testing Guide - Capítulo 1: Reentrancy

## 🎯 Enfoque Profesional

Este proyecto usa herramientas profesionales estándar de la industria:
- **Foundry** para tests de Solidity
- **Flow CLI** para tests de Cadence

Ambas son reproducibles, automatizables, y se pueden integrar en CI/CD.

---

## 🔨 Solidity Tests (Foundry)

### Setup Rápido

```bash
cd chapters/01-reentrancy/evm
./setup.sh  # Instala todo automáticamente
```

### Qué se prueba

- ✅ **ReentrancyExploit.t.sol** - El ataque funciona en código vulnerable
- ✅ **ReentrancyProtection.t.sol** - Las 3 soluciones previenen el ataque

**📖 Ver [evm/README.md](./evm/README.md) para documentación completa**

---

## 🌊 Cadence Tests (Flow CLI)

### Setup Rápido

```bash
cd chapters/01-reentrancy/cadence
./setup.sh  # Instala Flow CLI y ejecuta tests
```

### Qué se prueba

- ✅ **SimpleVault_test.cdc** - Reentrancy es imposible por diseño

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
  - 27 tests profesionales
  - Gas reports y coverage
  - Troubleshooting

- **Cadence**: [cadence/README.md](./cadence/README.md)
  - Instalación de Flow CLI
  - 7 tests de seguridad
  - Comparación con Solidity
  - Troubleshooting

---

## ✅ Verificación Rápida

```bash
# Verificar que todo funciona
cd evm && forge test -vv
cd ../cadence && flow test tests/SimpleVault_test.cdc
```

**Resultado esperado**: Todos los tests pasan ✅
