# Comparativa: ERC20 Approvals vs Cadence Capabilities

## 🎯 Resumen Ejecutivo

| Aspecto | ERC20 Approve | EIP-2612 Permit | Permit2 | Cadence Capabilities |
|---------|---------------|-----------------|---------|----------------------|
| **Requiere approval** | ✅ Sí (2 tx) | ✅ Sí (1 tx) | ✅ Sí (1 tx) | ❌ No (1 tx) |
| **Infinite approvals** | ✅ Común | ✅ Posible | ⚠️ Con expiry | ❌ Imposible |
| **Race conditions (SWC-114)** | ✅ Sí | ⚠️ Menos | ❌ No | ❌ Imposible |
| **Revocación** | Manual (gas) | Manual (gas) | Manual (gas) | Automática |
| **Hacks en 2024** | $9.7M+ | - | - | $0 |
| **Transacciones requeridas** | 2-3 | 1 | 1 | 1 |
| **Tipo de seguridad** | Runtime | Runtime + Sig | Runtime + Expiry | Compile-time |

---

## 📊 Evolución Histórica

### Solidity: 10 Años de Bandaids

```
2015 ──────> 2018 ──────> 2020 ──────> 2022 ──────> 2024
  │            │            │            │            │
  ▼            ▼            ▼            ▼            ▼
ERC20       BeautyChain   EIP-2612     Permit2     Li.Fi hack
approve()    $1B hack      Permit     (Uniswap)      $9.7M
vulnerable   → SafeMath   1 tx still   expirable   still
                          vulnerable   approvals   happening
```

**Problemas fundamentales**:
- Diseño original (2015) tenía fallas
- Cada "solución" es un parche sobre el anterior
- Vulnerabilidades persisten en código legacy
- Infinite approvals siguen siendo norma

### Cadence: Seguro Desde el Inicio

```
2019 ──────────────────────────────────> 2025
  │                                        │
  ▼                                        ▼
Lanzamiento con                       Sigue siendo
capabilities nativas                  el modelo correcto
(no approvals)                        (sin cambios necesarios)
```

**Ventajas arquitecturales**:
- Diseñado aprendiendo de errores de EVM
- No necesita parches (fundamentalmente correcto)
- $0 robados en hacks de approvals
- Imposible por diseño

---

## 💻 Código Lado a Lado

### Ejemplo 1: Transfer Simple

<table>
<tr>
<th>ERC20 Tradicional (2015-2024)</th>
<th>EIP-2612 Permit (2020+)</th>
<th>Cadence (2019+)</th>
</tr>
<tr>
<td>

```solidity
// TX 1: Approve (Alice paga gas)
token.approve(
    spender,
    type(uint256).max  // ∞
);

// TX 2: Transfer (Alice paga gas)
spender.doSomething();

// ⚠️ Approval persiste PARA SIEMPRE
// Para revocar (opcional):

// TX 3: Revoke (Alice paga gas)
token.approve(spender, 0);
```

**Total**: 3 transacciones
**Gas**: ~138k gas (46k × 3)
**Seguridad**: ❌ Vulnerable

</td>
<td>

```solidity
// Off-chain: Alice firma
bytes memory sig =
    signPermit(...);

// TX 1: Spender usa firma
token.permit(
    alice, spender,
    amount, deadline,
    v, r, s
);
token.transferFrom(
    alice, recipient,
    amount
);
```

**Total**: 1 transacción
**Gas**: ~174k gas
**Seguridad**: ⚠️ Mejor pero no perfecto

</td>
<td>

```cadence
transaction {
    prepare(
        signer: auth(BorrowValue)
            &Account
    ) {
        let vault = signer
            .storage
            .borrow<&Vault>(
                /storage/vault
            )!

        let payment <- vault
            .withdraw(
                amount: 100.0
            )

        recipient.deposit(
            from: <-payment
        )
    }
}
```

**Total**: 1 transacción
**Gas**: ~50k gas
**Seguridad**: ✅ Imposible hackear

</td>
</tr>
</table>

---

### Ejemplo 2: DEX Swap

<table>
<tr>
<th>Uniswap V2 (ERC20)</th>
<th>Uniswap con Permit2</th>
<th>Increment DEX (Cadence)</th>
</tr>
<tr>
<td>

```solidity
// Frontend típico:
// Paso 1: Approve
await tokenA.approve(
    routerAddress,
    ethers.MaxUint256
);

// Paso 2: Swap
await router.swapExactTokensForTokens(
    amountIn,
    amountOutMin,
    path,
    to,
    deadline
);

// ⚠️ Router tiene acceso
//    perpetuo a todos tus tokens
```

**UX**: 2 transacciones
**Riesgo**: Infinite approval persiste
**Si router hackeado**: Todos pierden

</td>
<td>

```solidity
// Usuario firma Permit2 off-chain
const signature = await signer
    .signTypedData(...);

// Una transacción:
await router.swapWithPermit2(
    amountIn,
    amountOutMin,
    path,
    to,
    deadline,
    signature
);

// ⚠️ Mejor, pero requiere:
// - Permit2 deployment
// - Aprobación inicial a Permit2
// - Complejidad de firmas
```

**UX**: 1 transacción
**Riesgo**: Aprobación a Permit2 central
**Si Permit2 hackeado**: Todos pierden

</td>
<td>

```cadence
transaction {
    prepare(signer: ...) {
        let vaultRef = signer
            .storage
            .borrow<&Vault>(...)!

        // Retirar
        let toSwap <- vaultRef
            .withdraw(
                amount: 100.0
            )

        // Swap
        let result <- dex.swap(
            from: <-toSwap,
            minimumOut: 95.0
        )

        // Depositar resultado
        vaultRef.deposit(
            from: <-result
        )
    }
}
```

**UX**: 1 transacción
**Riesgo**: Zero (DEX solo accede durante tx)
**Si DEX hackeado**: Solo afecta la tx actual

</td>
</tr>
</table>

---

## 🔓 Análisis de Vulnerabilidades

### Vulnerabilidad 1: Infinite Approvals

**ERC20**:
```solidity
// 99% de dApps piden esto por UX
token.approve(contract, type(uint256).max);

// Resultado: $16.2M robados en 2024
// - Li.Fi: $9.7M (Julio)
// - SenecaUSD: $6.5M (Febrero)
```

**Cadence**:
```cadence
// Concepto no existe!
// No puedes "aprobar" infinitamente algo que ya posees
```

---

### Vulnerabilidad 2: SWC-114 Race Condition

**ERC20**:
```solidity
// Estado inicial
mapping(alice => mapping(spender => 100));

// Alice cambia a 50
token.approve(spender, 50);

// ⚠️ Spender ve esto en mempool y front-runs:
// 1. Gasta los 100 (antes del cambio)
// 2. Cambio a 50 se ejecuta
// 3. Ahora tiene otros 50 disponibles
// Total: 150 tokens extraídos!
```

**Cadence**:
```cadence
// No hay estado global que cambiar
let payment1 <- vault.withdraw(amount: 100.0)  // Atómico
let payment2 <- vault.withdraw(amount: 50.0)   // Atómico

// Cada withdraw es independiente y directo
// No hay forma de "front-run" porque no hay race
```

---

### Vulnerabilidad 3: Li.Fi-Style Bridge Exploit

**ERC20**:
```solidity
// Bridge vulnerable
function bridgeAndSwap(address target, bytes data) external {
    target.call(data);  // ⚠️ No valida target!
}

// Atacante:
bridgeAndSwap(
    tokenAddress,
    abi.encodeCall(token.transferFrom, (victim, attacker, balance))
);

// Resultado: Drena TODOS los tokens de víctimas con approvals
```

**Cadence**:
```cadence
// Bridge toma tokens directamente en la transacción
access(all) fun bridge(from: @Vault, chainId: UInt64): @Receipt {
    // Bridge recibe los tokens DIRECTAMENTE
    // No puede drenar fondos de usuarios porque no tiene acceso

    self.lockTokens(from: <-from, chainId: chainId)
    return <- createReceipt(...)
}

// ✅ Bridge NUNCA tiene acceso a fondos de usuarios
// ✅ Solo procesa lo que se le pasa en la tx actual
```

---

## 📈 Costo Comparativo

### Gas Costs

| Operación | ERC20 | Permit | Permit2 | Cadence |
|-----------|-------|--------|---------|---------|
| Approve | 46,000 | 0 (off-chain) | 0 (off-chain) | N/A |
| Transfer | 65,000 | 174,000 | 191,000 | 50,000 |
| Revoke | 23,000 | 23,000 | 23,000 | 0 |
| **Total** | **134,000** | **174,000** | **191,000** | **50,000** |

**Cadence ahorra ~73% de gas** comparado con ERC20 tradicional.

### User Friction

| Step | ERC20 | Permit | Cadence |
|------|-------|--------|---------|
| 1. Approve | ✅ TX | ✅ Signature | ❌ Not needed |
| 2. Action | ✅ TX | ✅ TX | ✅ TX |
| 3. Revoke | ⚠️ TX (opcional) | ⚠️ TX (opcional) | ❌ Not needed |
| **User friction** | High | Medium | Low |

---

## 🎓 Lecciones de Diseño

### ERC20: Diseño Reactivo

```
Problema → Hack → Parche → Nuevo problema → Nuevo hack → Nuevo parche
```

**Timeline real**:
- 2015: ERC20 lanzado con `approve()`
- 2018: BeautyChain hack ($1B), descubre SWC-114
- 2018: OpenZeppelin añade `increaseAllowance()`
- 2020: EIP-2612 Permit (gasless approvals)
- 2022: Uniswap Permit2 (expirable approvals)
- 2024: Li.Fi hack ($9.7M), todavía vulnerable

**Problema fundamental**: Balance model requiere approvals.

### Cadence: Diseño Proactivo

```
Análisis de problemas conocidos → Diseño fundamentalmente diferente → Problema eliminado
```

**Insight clave**: Resources > Balances

```cadence
// En Cadence, tokens son OBJETOS que posees
let myTokens: @Vault <- ...

// En Solidity, tokens son NÚMEROS en un mapping
mapping(address => uint256) balances;
```

**Consecuencia**:
- Solidity: Necesitas "permiso" para mover números de otros
- Cadence: Ya posees el objeto, no necesitas permiso

---

## 🏆 Ganador por Categoría

| Categoría | Ganador | Razón |
|-----------|---------|-------|
| **Seguridad** | 🥇 Cadence | $0 hacks vs $16.2M+ (2024) |
| **UX** | 🥇 Cadence | 1 tx vs 2-3 tx |
| **Gas cost** | 🥇 Cadence | 50k vs 134k-191k |
| **Simplicidad** | 🥇 Cadence | No approvals > múltiples soluciones |
| **Retrocompatibilidad** | 🥇 Solidity | Ecosistema maduro |
| **Tooling** | 🥇 Solidity | Más herramientas disponibles |
| **Fundamentalmente correcto** | 🥇 Cadence | Diseñado bien desde el inicio |

---

## 🎯 Conclusiones

### Para Usuarios

**Solidity**:
- ⚠️ Revoca approvals regularmente (usa [Revoke.cash](https://revoke.cash))
- ⚠️ Evita infinite approvals cuando sea posible
- ⚠️ Usa dApps con Permit/Permit2 si disponible

**Cadence**:
- ✅ No te preocupes por approvals
- ✅ No hay nada que revocar
- ✅ Disfruta de seguridad gratuita

### Para Desarrolladores

**Solidity**:
- ✅ Implementa EIP-2612 Permit en nuevos tokens
- ✅ Considera Permit2 para mejor UX
- ✅ Nunca uses `approve()` sin validación
- ✅ Audita todo código que use `transferFrom()`

**Cadence**:
- ✅ Usa recursos directamente (patrón estándar)
- ✅ Capabilities solo cuando realmente necesites delegación
- ✅ Siempre haz capabilities revocables

### Para Auditores

**Solidity**:
- 🔍 Busca infinite approvals sin expiry
- 🔍 Verifica protección SWC-114
- 🔍 Revisa funciones con `call()` que puedan abusar approvals
- 🔍 Chequea que usuarios puedan revocar

**Cadence**:
- ✅ Approvals no existen (nada que auditar)
- 🔍 Verifica que capabilities sean revocables (cuando se usen)
- 🔍 Revisa control de acceso a resources

---

## 📚 Referencias

### Documentación
- [EIP-20 (ERC20)](https://eips.ethereum.org/EIPS/eip-20)
- [SWC-114](https://swcregistry.io/docs/SWC-114)
- [EIP-2612 (Permit)](https://eips.ethereum.org/EIPS/eip-2612)
- [Uniswap Permit2](https://github.com/Uniswap/permit2)
- [Cadence Capabilities](https://developers.flow.com/cadence/language/capabilities)

### Hacks Analizados
- [Li.Fi Hack Post-mortem](https://twitter.com/lifinance/status/1680959932034359297)
- [SenecaUSD Incident](https://medium.com/@SenecaUSD/seneca-usd-incident-post-mortem-aef5e5c8de57)
- [BeautyChain (BEC) Analysis](https://medium.com/secbit-media/a-disastrous-vulnerability-found-in-smart-contracts-of-beautychain-bec-dbf24ddbc30e)

### Herramientas
- [Revoke.cash](https://revoke.cash/) - Revocar approvals peligrosos
- [Etherscan Token Approvals](https://etherscan.io/tokenapprovalchecker)
- [Rabby Wallet](https://rabby.io/) - Alertas de approvals

---

**Actualizado**: 2025-11-14
**Conclusion**: Cadence elimina problemas de approvals arquitecturalmente.
