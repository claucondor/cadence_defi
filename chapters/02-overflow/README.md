# Capítulo 2: Integer Overflow & Underflow

> **Duración estimada del video**: 20 minutos
> **Dificultad**: Principiante
> **Prerequisitos**: Ninguno

---

## 📋 Índice

1. [Introducción](#introducción)
2. [El Problema](#el-problema)
3. [Solución en EVM](#solución-en-evm)
4. [EIPs Relacionados](#eips-relacionados)
5. [Solución en Cadence](#solución-en-cadence)
6. [Comparación](#comparación)
7. [Demo Práctica](#demo-práctica)
8. [Recursos Adicionales](#recursos-adicionales)

---

## 🎯 Introducción

### ¿Qué aprenderás?

En este capítulo aprenderás:
- [ ] Qué son integer overflow y underflow
- [ ] El famoso BeautyChain (BEC) hack que perdió $1 billón en tokens
- [ ] Cómo Solidity 0.8+ previene estos ataques automáticamente
- [ ] Por qué en Cadence este problema NUNCA existió

### Contexto

En 2018, el token BeautyChain (BEC) fue hackeado mediante un ataque de **integer overflow** en la función `batchTransfer()`. Los atacantes crearon **10^58 tokens** de la nada (un número astronómico), lo que colapsó el precio del token a cero.

Este hack, junto con muchos otros similares, llevó a que Solidity 0.8.0 (lanzado en 2020) incluyera **protección automática** contra overflow/underflow.

---

## ❌ El Problema

### Descripción Teórica

**Integer Overflow** ocurre cuando una operación aritmética produce un resultado mayor al máximo valor que puede almacenar el tipo de dato:

```
uint8 max = 255
uint8 result = max + 1  // Overflow: 255 + 1 = 0 (wrapped around)
```

**Integer Underflow** ocurre cuando una operación produce un resultado menor al mínimo:

```
uint8 min = 0
uint8 result = min - 1  // Underflow: 0 - 1 = 255 (wrapped around)
```

### Ejemplo del Mundo Real

#### **BeautyChain (BEC) Hack** (Abril 2018): $1 billón en tokens creados

**El exploit:**
```solidity
// Código vulnerable (Solidity 0.4.x)
function batchTransfer(address[] _receivers, uint256 _value) public {
    uint cnt = _receivers.length;
    uint256 amount = uint256(cnt) * _value;  // ⚠️ OVERFLOW AQUÍ
    require(amount <= balances[msg.sender]);

    for (uint i = 0; i < cnt; i++) {
        balances[_receivers[i]] += _value;
    }
    balances[msg.sender] -= amount;
}
```

**El ataque:**
- Atacante llama `batchTransfer(["0x123...", "0x456..."], 2^255)`
- `cnt = 2`, `_value = 2^255`
- `amount = 2 * 2^255 = 2^256 = 0` ← **OVERFLOW**
- `require(0 <= balances[msg.sender])` ✅ Pasa
- Se transfieren `2^255` tokens a cada dirección
- Total creado: `2 * 2^255 = 2^256` tokens de la nada

**Resultado:** OKEx exchange cerró trading de BEC, precio colapsó a $0.

#### **Otros hacks notables:**

- **PoWHC** (2018): $866,000 perdidos por overflow en cálculo de dividendos
- **SmartMesh (SMT)** (2018): Similar a BEC, batchOverflow
- **Múltiples tokens ERC20** (2018): >12 contratos con mismo bug

### ¿Por qué es problemático en EVM?

**Limitaciones fundamentales del EVM:**

1. **Opcodes no tienen overflow detection**: Los opcodes `ADD`, `SUB`, `MUL`, `EXP` simplemente "envuelven" el resultado sin indicar error

2. **No hay overflow flag**: A diferencia de CPUs reales que tienen "carry" y "overflow" flags, el EVM no provee ninguna indicación

3. **Wrapping behavior**: El valor simplemente se envuelve:
   - `uint8: 255 + 1 = 0`
   - `uint8: 0 - 1 = 255`
   - `uint256: MAX + 1 = 0`

4. **El desarrollador debe protegerse manualmente** (pre-Solidity 0.8)

---

## 🔧 Solución en EVM

### Workaround 1: SafeMath Library (Pre-Solidity 0.8)

**Descripción**: Librería de OpenZeppelin que hace las operaciones aritméticas con checks

**Ejemplo:**
```solidity
// Pre-0.8 Solidity
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SafeToken {
    using SafeMath for uint256;

    function transfer(uint256 amount) public {
        balance = balance.sub(amount);  // Revierte si underflow
        otherBalance = otherBalance.add(amount);  // Revierte si overflow
    }
}
```

**Ventajas**:
- ✅ Probado en batalla (usado por miles de contratos)
- ✅ Previene overflow/underflow efectivamente

**Desventajas**:
- ❌ Overhead de gas (~200-300 gas por operación)
- ❌ Sintaxis menos clara (`.add()` vs `+`)
- ❌ Fácil olvidarlo en alguna operación

---

### Workaround 2: Solidity 0.8+ Built-in Checks

**Descripción**: Desde Solidity 0.8.0, **todas** las operaciones aritméticas tienen checks automáticos

**Ejemplo:**
```solidity
// Solidity 0.8+
pragma solidity ^0.8.0;

contract SafeByDefault {
    uint256 public balance;

    function transfer(uint256 amount) public {
        balance = balance - amount;  // Revierte automáticamente si underflow
        otherBalance = otherBalance + amount;  // Revierte si overflow
    }
}
```

**Ventajas**:
- ✅ Seguro por defecto
- ✅ No requiere imports ni librerías
- ✅ Sintaxis natural (`+`, `-`, `*`)
- ✅ El compilador lo fuerza

**Desventajas**:
- ❌ ~200 gas overhead (mismo que SafeMath)
- ❌ No puedes "olvidarlo" pero a veces quieres overflow intencional

---

### Workaround 3: unchecked{} para Optimización

**Descripción**: En Solidity 0.8+, puedes usar `unchecked{}` para operaciones donde SABES que no hay overflow

**Ejemplo:**
```solidity
// Solidity 0.8+
function optimizedLoop(uint256 n) public {
    uint256 sum = 0;

    for (uint256 i = 0; i < n; ) {
        sum += i;

        unchecked {
            i++;  // i nunca overflow porque n es el límite
        }
    }
}
```

**Cuándo usar:**
- ✅ Contadores de loops que no pueden overflow
- ✅ Operaciones donde matemáticamente es imposible overflow
- ✅ Código crítico de gas

**Cuándo NO usar:**
- ❌ Cálculos con input de usuarios
- ❌ Transfers de tokens
- ❌ Cualquier operación con riesgo real

---

## 📜 EIPs Relacionados

### EIP-1051: Overflow checking for the EVM

- **Status**: Stagnant
- **Propuesta**: Añadir flags `ovf` (overflow) y `sovf` (signed overflow) al EVM state
- **Descripción**: Replicaría funcionalidad de CPUs reales con carry/overflow flags

**¿Por qué no se implementó?**
- Requiere cambios a nivel de protocolo EVM
- Solidity 0.8+ resolvió el problema a nivel de compilador
- Backward compatibility issues

### Solidity 0.8.0 Breaking Changes (2020)

- **Cambio principal**: Arithmetic operations revert on underflow and overflow
- **Impacto**: SafeMath ya no es necesario
- **Migración**: Código legacy debe actualizar a 0.8+ o seguir usando SafeMath

---

## ✨ Solución en Cadence

### ¿Cómo Cadence resuelve esto nativamente?

**Cadence NUNCA tuvo este problema** porque fue diseñado desde el inicio con protección nativa.

**Características clave:**

1. **Saturating math**: Las operaciones "saturan" en el límite en vez de envolver
2. **Built-in desde día 1**: No fue un "fix" posterior, siempre estuvo
3. **Zero overhead**: Optimizado a nivel de runtime

**Ejemplo:**
```cadence
// Cadence
pub fun transfer(amount: UFix64) {
    // Si amount > self.balance, esto REVIERTE automáticamente
    self.balance = self.balance - amount

    // Si overflow, también REVIERTE
    receiver.balance = receiver.balance + amount
}
```

### Comparación directa

| Operación | Solidity <0.8 | Solidity 0.8+ | Cadence |
|-----------|---------------|---------------|---------|
| `255 + 1` (uint8) | `0` (wraps) | Reverts | Reverts |
| `0 - 1` (uint8) | `255` (wraps) | Reverts | Reverts |
| Protección | Manual (SafeMath) | Automática | Siempre nativa |
| Gas overhead | ~300 gas | ~200 gas | 0 (nativo) |

---

## ⚖️ Comparación

| Aspecto | Solidity <0.8 | Solidity 0.8+ | Cadence |
|---------|---------------|---------------|---------|
| **Vulnerable por defecto** | ✅ Sí | ❌ No | ❌ Nunca |
| **Requiere SafeMath** | ✅ Sí | ❌ No | ❌ No |
| **Gas overhead** | ~300 | ~200 | 0 |
| **Puede olvidarse** | ✅ Sí | ❌ Imposible | ❌ Imposible |
| **unchecked{} disponible** | N/A | ✅ Sí | N/A |

---

## 💻 Demo Práctica

Ver archivos en:
- `evm/problema.sol` - Código vulnerable (0.7.x)
- `evm/workaround.sol` - Tres soluciones
- `cadence/OverflowSafe.cdc` - Implementación Cadence

Tests:
```bash
# Solidity
cd evm && forge test -vv

# Cadence
cd cadence && flow test tests/OverflowSafe_test.cdc
```

---

## 📚 Recursos Adicionales

### Documentación Oficial
- [Solidity 0.8.0 Breaking Changes](https://docs.soliditylang.org/en/latest/080-breaking-changes.html)
- [Cadence Arithmetic](https://developers.flow.com/cadence/language)

### Análisis de Hacks
- [BeautyChain BEC Analysis](https://medium.com/secbit-media/a-disastrous-vulnerability-found-in-smart-contracts-of-beautychain-bec-dbf24ddbc30e)
- [batchOverflow Bug](https://peckshield.medium.com/alert-new-batchoverflow-bug-in-multiple-erc20-smart-contracts-cve-2018-10299-511067db6536)

### Papers
- [Integer Overflow Detection](https://arxiv.org/pdf/1907.00903)

---

## 🔗 Enlaces Rápidos

- [← Capítulo Anterior: Reentrancy](../01-reentrancy/)
- [↑ Índice General](../../INDEX.md)
- [→ Siguiente Capítulo: ERC20 Approval](../03-approval-pattern/)

---

**Tags**: `#IntegerOverflow` `#BeautyChain` `#SafeMath` `#Solidity08`

**Fecha de creación**: 2025-11-14
**Última actualización**: 2025-11-14
**Estado**: 🟢 Completo
