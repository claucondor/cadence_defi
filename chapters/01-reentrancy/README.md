# Capítulo 1: Reentrancy Attacks

> **Duración estimada del video**: 18-20 minutos
> **Dificultad**: Principiante
> **Prerequisitos**: Ninguno (primer capítulo)

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
- [ ] Qué es un ataque de reentrancy y por qué es peligroso
- [ ] El famoso hack de The DAO ($60M) que cambió Ethereum
- [ ] Cómo los desarrolladores de Solidity previenen reentrancy
- [ ] Por qué en Cadence este problema NO EXISTE por diseño del lenguaje

### Contexto

El ataque de reentrancy es **el bug más famoso en la historia de Ethereum**. En 2016, un atacante explotó esta vulnerabilidad en The DAO, drenando $60 millones de dólares, lo que eventualmente llevó al controversial hard fork de Ethereum en ETH y ETC (Ethereum Classic).

Desde entonces, **cada desarrollador de Solidity debe ser consciente** de este patrón de ataque y activamente protegerse contra él. Es el patrón de seguridad #1 que todo auditor revisa.

---

## ❌ El Problema

### Descripción Teórica

Un **ataque de reentrancy** ocurre cuando:

1. Un contrato (Víctima) llama a una función externa en otro contrato (Atacante)
2. El Atacante aprovecha esa llamada para volver a llamar a la Víctima
3. La Víctima aún no ha actualizado su estado interno
4. El ciclo se repite, drenando fondos

**Flujo del ataque:**

```
Víctima.withdraw()
  ├─> Actualizar balance (❌ NO se hace primero)
  ├─> Enviar ETH → Atacante
  │     └─> Atacante.receive()
  │           └─> Víctima.withdraw() ← ¡REENTRANCY!
  │                 └─> Enviar ETH → Atacante (otra vez!)
  └─> Actualizar balance (demasiado tarde!)
```

### Ejemplo del Mundo Real

**Ejemplos notables:**

#### **The DAO Hack** (2016): $60 millones perdidos
- El hacker explotó la función `splitDAO` que transfería ETH antes de actualizar balances
- Se drenaron ~3.6 millones de ETH (1/3 del total del DAO)
- Resultó en el hard fork ETH/ETC

#### **Lendf.Me** (2020): $25 millones drenados
- Vulnerabilidad de reentrancy en el protocolo de lending
- El atacante drenó múltiples tokens ERC-777 (que permiten hooks)
- Fondos fueron eventualmente devueltos

#### **Cream Finance** (2021): $130 millones
- Reentrancy cross-contract más sofisticada
- Exploited en combinación con flash loans

### ¿Por qué es problemático en EVM?

**Limitaciones fundamentales de EVM/Solidity:**

1. **Orden de ejecución no forzado**: Solidity no obliga a actualizar estado antes de llamadas externas
2. **Fallback functions**: Los contratos pueden ejecutar código al recibir ETH (`receive()`, `fallback()`)
3. **msg.sender checking**: El modelo de seguridad basado en verificar `msg.sender` es frágil
4. **Estado mutable durante llamadas externas**: No hay protección del estado durante external calls

**El problema real**: El desarrollador debe **recordar** y **aplicar manualmente** el patrón correcto. Un olvido = vulnerabilidad crítica.

---

## 🔧 Solución en EVM

### Workarounds Actuales

#### Workaround 1: Checks-Effects-Interactions Pattern

**Descripción**: Patrón manual donde el desarrollador debe seguir un orden específico:

1. **Checks**: Validar condiciones
2. **Effects**: Actualizar estado interno
3. **Interactions**: Llamar contratos externos

**Ventajas**:
- ✅ No requiere dependencias externas
- ✅ Gas-efficient
- ✅ Patrón estándar bien documentado

**Desventajas**:
- ❌ Depende 100% de que el desarrollador lo recuerde
- ❌ Fácil olvidarlo en funciones complejas
- ❌ No hay enforcement del compilador
- ❌ Code reviews pueden pasarlo por alto

**Código ejemplo**:
```solidity
// Ver: evm/workaround.sol

function withdraw() public {
    // 1. CHECKS
    uint256 amount = balances[msg.sender];
    require(amount > 0, "No balance");

    // 2. EFFECTS - ¡Actualizar ANTES de enviar!
    balances[msg.sender] = 0;

    // 3. INTERACTIONS
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
}
```

#### Workaround 2: ReentrancyGuard (OpenZeppelin)

**Descripción**: Modifier que usa un "mutex lock" para bloquear llamadas recursivas.

**Ventajas**:
- ✅ Fácil de aplicar con un modifier
- ✅ Librería auditada (OpenZeppelin)
- ✅ Explícito en el código

**Desventajas**:
- ❌ Costo adicional de gas (2 SSTOREs por transacción)
- ❌ Aún requiere que el dev lo aplique manualmente
- ❌ Puede olvidarse en algunas funciones
- ❌ No protege contra reentrancy cross-contract

**Código ejemplo**:
```solidity
// Ver: evm/workaround.sol

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Vault is ReentrancyGuard {

    function withdraw() public nonReentrant { // ← Modifier protege
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");

        balances[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
```

#### Workaround 3: Pull over Push Pattern

**Descripción**: En vez de enviar fondos (push), permitir que usuarios los retiren (pull).

**Ventajas**:
- ✅ Elimina muchos casos de reentrancy
- ✅ Más seguro en general

**Desventajas**:
- ❌ Peor UX (requiere transacción adicional)
- ❌ Mayor costo de gas para usuarios
- ❌ No siempre aplicable

### Librerías y Herramientas

**Más utilizadas:**
- **OpenZeppelin ReentrancyGuard**: El estándar de facto
- **Slither**: Detector automático de vulnerabilidades
- **Mythril**: Análisis de seguridad que detecta reentrancy

---

## 📜 EIPs Relacionados

**Nota importante**: No hay un EIP específico que "solucione" reentrancy, porque es un problema fundamental del diseño de EVM. Los EIPs han mejorado aspectos relacionados:

### EIP-1153: Transient Storage

- **Status**: Final (implementado en Cancun upgrade, 2024)
- **Autor**: Alexey Akhunov, Moody Salem
- **Descripción**: Añade opcodes `TSTORE` y `TLOAD` para storage temporal que se borra al final de la transacción

**¿Qué problema soluciona?**
Reduce el costo de gas de ReentrancyGuard dramáticamente, haciendo locks temporales mucho más baratos.

**¿Por qué no soluciona todo?**
- Solo reduce costos, no elimina la necesidad de protección manual
- El desarrollador aún debe recordar aplicar el guard

### EIP-1884: Repricing for trie-size-dependent opcodes

- **Status**: Final (implementado en Istanbul, 2019)
- **Descripción**: Aumentó el costo de SLOAD, afectando patrones de gas

**Relación con reentrancy:**
Hizo más costoso ciertos patrones de ataque, pero no previene reentrancy.

---

## ✨ Solución en Cadence

### ¿Cómo Cadence resuelve esto nativamente?

**La respuesta simple**: En Cadence, **reentrancy es imposible por diseño del lenguaje**. No necesitas pensar en ello.

**¿Por qué?**

**Ventajas clave de Cadence:**

1. **Resource Ownership**: Los Resources solo pueden tener UN dueño a la vez
   - No puedes llamar métodos en un Resource que no posees
   - Cuando transfieres un Resource, ya no puedes usarlo

2. **Linear Types**: Resources deben ser usados exactamente una vez
   - El compilador fuerza que muevas o destruyas Resources
   - No puede haber "doble uso" accidental

3. **Capability-Based Security**: En vez de `msg.sender`, usas capabilities
   - Solo quien tiene la capability puede llamar ciertas funciones
   - No hay "llamadas externas arbitrarias"

### Implementación

```cadence
// Ver: cadence/solucion.cdc

pub contract Vault {

    pub resource VaultResource {
        pub var balance: UFix64

        init() {
            self.balance = 0.0
        }

        // Solo el DUEÑO del Resource puede llamar withdraw
        pub fun withdraw(amount: UFix64): @FlowToken.Vault {
            pre {
                self.balance >= amount: "Insufficient balance"
            }

            self.balance = self.balance - amount

            // Crear un nuevo vault con los fondos
            // El Resource se MUEVE, no se copia
            return <- FlowToken.createVault(amount: amount)
        }
    }

    // Crear un vault para una cuenta
    pub fun createVault(): @VaultResource {
        return <- create VaultResource()
    }
}
```

**Uso desde una transacción:**

```cadence
import Vault from 0x01
import FlowToken from 0x02

transaction(amount: UFix64) {

    let vaultRef: &Vault.VaultResource

    prepare(signer: AuthAccount) {
        // Obtener referencia al vault del usuario
        self.vaultRef = signer.borrow<&Vault.VaultResource>(from: /storage/vault)
            ?? panic("Vault not found")
    }

    execute {
        // Withdraw devuelve un Resource que DEBE ser manejado
        let withdrawn <- self.vaultRef.withdraw(amount: amount)

        // Si no lo depositas en otro lado, el compilador ERROR
        // No se puede "olvidar" manejar el Resource
        destroy withdrawn // o depositar en otro vault
    }
}
```

### ¿Por qué esto es mejor?

- ✅ **Imposible olvidarse**: El compilador FUERZA que manejes Resources correctamente
  - Si no usas el valor retornado de `withdraw()`, el código ni compila
  - No hay forma de "olvidarse" de actualizar el balance

- ✅ **Sin workarounds necesarios**: No necesitas ReentrancyGuard, ni recordar CEI pattern
  - El lenguaje te protege automáticamente
  - Menos código = menos bugs

- ✅ **Ownership claro**: Solo el dueño del Resource puede llamar sus métodos
  - No hay `msg.sender` confuso
  - La capability ES la autorización

- ✅ **Zero-cost abstraction**: Esta seguridad no tiene costo adicional de runtime
  - Todo se verifica en compile-time
  - No hay "mutex" gastando gas

---

## ⚖️ Comparación

| Aspecto | EVM (Solidity) | Cadence (Flow) |
|---------|----------------|----------------|
| **Complejidad** | Desarrollador debe recordar aplicar protecciones manualmente | Protección automática por diseño del lenguaje |
| **Seguridad** | Vulnerable por defecto, seguro solo si aplicas patrones | Seguro por defecto, imposible tener reentrancy |
| **Gas/Costos** | ReentrancyGuard cuesta ~2,500 gas extra por transacción | Zero overhead, protección en compile-time |
| **Developer Experience** | Requiere conocimiento profundo de seguridad | Solo escribe código natural |
| **Auditabilidad** | Auditor debe verificar cada función | Garantizado por el type system |

### Tabla Resumen: Características del Patrón

| Característica | EVM | Cadence |
|----------------|-----|---------|
| Requiere librería externa | ⚠️ Recomendado (OpenZeppelin) | ✅ No (nativo) |
| Vulnerable por defecto | ❌ Sí | ✅ No |
| Fácil de auditar | ⚠️ Requiere experiencia | ✅ Type system lo garantiza |
| Costo de protección | ❌ ~2,500 gas | ✅ Gratis |
| Puede olvidarse | ❌ Sí, muy común | ✅ Imposible |

---

## 💻 Demo Práctica

### Setup

```bash
# Clonar el repositorio
git clone [URL]
cd cadence_defi/chapters/01-reentrancy

# Para probar los ejemplos de Solidity
cd evm
# (Requiere Foundry o Hardhat)

# Para probar Cadence
cd cadence
flow test
```

### Paso 1: Código Vulnerable (EVM)

Ver `evm/problema.sol` - Un contrato simple con vulnerabilidad de reentrancy.

**Exploit**: El atacante puede drenar todo el ETH del contrato.

### Paso 2: Workarounds (EVM)

Ver `evm/workaround.sol` - Tres soluciones:
1. CEI Pattern
2. ReentrancyGuard
3. Pull Payment

**Resultado**: Protegido, pero requiere disciplina del desarrollador.

### Paso 3: Solución Cadence

Ver `cadence/solucion.cdc` - Implementación natural en Cadence.

**Resultado**: Imposible tener reentrancy, el compilador lo previene.

---

## 📚 Recursos Adicionales

### Documentación Oficial
- [Cadence Resources](https://developers.flow.com/cadence/language/resources)
- [OpenZeppelin ReentrancyGuard](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard)
- [Solidity Security Considerations](https://docs.soliditylang.org/en/latest/security-considerations.html#re-entrancy)

### Artículos y Blogs
- [The DAO Hack Explained](https://www.gemini.com/cryptopedia/the-dao-hack-makerdao) - Gemini
- [Reentrancy After Istanbul](https://blog.openzeppelin.com/reentrancy-after-istanbul/) - OpenZeppelin, 2020
- [Resource-Oriented Programming](https://medium.com/dapperlabs/resource-oriented-programming-bee4d69c8f8e) - Dapper Labs

### Papers Académicos
- [A survey of attacks on Ethereum smart contracts](https://eprint.iacr.org/2016/1007.pdf) - Atzei et al., 2017

### Herramientas
- [Slither](https://github.com/crytic/slither) - Detector automático
- [Flow Playground](https://play.flow.com/) - Prueba Cadence en el browser

---

## 🎬 Guión para Video

### Introducción (2 min)
- **Hook**: "¿Sabías que un solo bug drenó $60 millones y dividió Ethereum en dos blockchains?"
- Presentar The DAO hack
- Preview: "Hoy verás por qué en Cadence esto es imposible"

### Desarrollo (14 min)
- **Parte 1**: El problema (4 min)
  - Explicar reentrancy con diagrama
  - Mostrar código vulnerable
  - Explicar por qué EVM lo permite

- **Parte 2**: Soluciones EVM (5 min)
  - CEI pattern (manual)
  - ReentrancyGuard (OpenZeppelin)
  - Costos y limitaciones

- **Parte 3**: Solución Cadence (5 min)
  - Resources y ownership
  - Por qué es imposible por diseño
  - Ventajas del type system

### Demo (3 min)
- Mostrar exploit en Solidity
- Mostrar prevención con guard
- Mostrar código Cadence que ni compila si está mal

### Conclusión (1 min)
- Recap: Solidity requiere disciplina, Cadence te protege
- Call to action: Prueba el código en Flow Playground
- Preview Capítulo 2: Integer Overflow

---

## ✅ Checklist para el Video

Antes de grabar:
- [x] README completado
- [x] Código EVM funcional
- [ ] Código Cadence funcional y testeado
- [ ] Tests pasando
- [x] Comparativa completa
- [x] Referencias verificadas

---

## 🤔 Preguntas Frecuentes

**P: ¿Realmente NO existe reentrancy en Cadence?**
R: Correcto. Por el diseño de Resources como linear types, es imposible que un Resource sea usado dos veces en la misma transacción. El compilador lo previene.

**P: ¿Qué pasa si necesito llamar múltiples contratos?**
R: Puedes hacerlo, pero cada Resource solo puede estar en un lugar a la vez. No puedes "llamar de vuelta" a un Resource que ya moviste.

**P: ¿Hay algún costo de gas extra por esta seguridad?**
R: No. Es seguridad en compile-time, no runtime. Zero overhead.

**P: ¿Es ReentrancyGuard suficiente en Solidity?**
R: Para reentrancy single-contract, sí. Pero no protege contra reentrancy cross-contract ni ataques read-only reentrancy. Además, debes recordar usarlo en TODAS las funciones vulnerables.

---

## 🔗 Enlaces Rápidos

- [← No hay capítulo anterior](../../INDEX.md)
- [↑ Índice General](../../INDEX.md)
- [→ Siguiente Capítulo: Integer Overflow](../02-overflow/)

---

**Tags**: `#Reentrancy` `#TheDaoHack` `#Solidity` `#Cadence` `#SmartContractSecurity`

**Fecha de creación**: 2025-11-14
**Última actualización**: 2025-11-14
**Estado**: 🟡 En Progreso
