# Capítulo 3: ERC20 Approval Pattern

> **Duración estimada del video**: 25 minutos
> **Dificultad**: Intermedio
> **Prerequisitos**: Entender ERC20 básico

---

## 📋 Índice

1. [Introducción](#introducción)
2. [El Problema](#el-problema)
3. [Soluciones en EVM](#soluciones-en-evm)
4. [EIPs Relacionados](#eips-relacionados)
5. [Solución en Cadence](#solución-en-cadence)
6. [Comparación](#comparación)
7. [Demo Práctica](#demo-práctica)
8. [Recursos Adicionales](#recursos-adicionales)

---

## 🎯 Introducción

### ¿Qué aprenderás?

En este capítulo aprenderás:
- [ ] Por qué el patrón `approve()` de ERC20 es problemático
- [ ] El ataque SWC-114 Multiple Withdrawal
- [ ] Hacks recientes: Li.Fi ($9.7M), SenecaUSD ($6.5M)
- [ ] Soluciones modernas: EIP-2612 Permit, Uniswap Permit2
- [ ] Cómo Cadence elimina este problema con Capabilities

### Contexto

El patrón `approve()` de ERC20 tiene **problemas fundamentales de diseño** que han causado pérdidas millonarias:

**2024 solo**:
- **Li.Fi Bridge** (Julio 2024): $9.7M robados por infinite approvals
- **SenecaUSD** (Febrero 2024): $6.5M drenados de usuarios con approvals activos
- **KyberSwap** (Noviembre 2023): Infinite approvals explotados

El problema: **Los usuarios dan permisos ilimitados** a contratos que pueden ser comprometidos.

---

## ❌ El Problema

### Descripción Teórica

ERC20 requiere dos transacciones para que un contrato mueva tus tokens:

```solidity
// 1. Usuario aprueba al contrato
token.approve(spender, amount);

// 2. Contrato mueve los tokens
token.transferFrom(user, recipient, amount);
```

**Problemas fundamentales:**

### 1. SWC-114: Multiple Withdrawal Attack

**Race condition** al cambiar approvals:

```solidity
// Usuario tiene 100 tokens aprobados a un spender
token.approve(spender, 100);

// Usuario quiere cambiar a 50
token.approve(spender, 50);

// ⚠️ ATAQUE: Spender puede front-run y gastar 150 tokens!
// 1. Ve la tx de cambio a 50 en mempool
// 2. Gasta rápidamente los 100 antes del cambio
// 3. Después del cambio, tiene otros 50 disponibles
// Total: 150 tokens gastados!
```

### 2. Infinite Approvals

La mayoría de dApps piden **infinite approval** por UX:

```solidity
// Común en producción
token.approve(uniswapRouter, type(uint256).max);  // ∞ approval
```

**Consecuencias:**
- Si el contrato es hackeado → Todos tus tokens se van
- Si el contrato es malicioso → Puede drenar todo
- Si hay un bug → Pérdida total

**Casos reales:**

#### Li.Fi Bridge Hack (Julio 2024) - $9.7M

```solidity
// Contrato Li.Fi tenía función sin protección
function swapAndBridge(...) external {
    // ⚠️ call arbitrario sin validación
    (bool success, ) = target.call(data);
}

// Atacante llamó:
target = victimToken
data = transferFrom(victim, attacker, balance)

// Resultado: Drenó todos los tokens de usuarios con infinite approval
```

#### SenecaUSD Hack (Febrero 2024) - $6.5M

```solidity
// Bug en función performOperations()
function performOperations(...) external {
    // ⚠️ No validaba el target
    for (uint i = 0; i < operations.length; i++) {
        operations[i].target.call(operations[i].data);
    }
}

// Atacante inyectó calls maliciosos
// Drenó fondos de todos los usuarios con approvals activos
```

### 3. Front-running de Approvals

```solidity
// Usuario aprueba 1000 tokens para un DEX
token.approve(dex, 1000);

// MEV bot ve esto y front-runs con:
dex.swap(token, otherToken, 1000);  // Usa tu approval primero!

// Usuario queda sin tokens
```

### ¿Por qué es problemático en EVM?

**Limitaciones de diseño de ERC20:**

1. **No hay revocación automática**: Una vez aprobado, el permiso persiste para siempre
2. **Estado global mutable**: Cualquiera puede ver y explotar tus approvals
3. **Dos transacciones requeridas**: Overhead de gas + superficie de ataque
4. **UX vs Seguridad**: Infinite approvals son convenientes pero peligrosas

---

## 🔧 Soluciones en EVM

### Workaround 1: increaseAllowance / decreaseAllowance

**Descripción**: OpenZeppelin añadió funciones para evitar race conditions

```solidity
// OpenZeppelin ERC20
contract SafeERC20 {
    function increaseAllowance(address spender, uint256 addedValue) public {
        _approve(msg.sender, spender, allowance(msg.sender, spender) + addedValue);
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public {
        uint256 currentAllowance = allowance(msg.sender, spender);
        require(currentAllowance >= subtractedValue);
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
    }
}
```

**Ventajas**:
- ✅ Previene race condition de SWC-114
- ✅ Más granular que approve()

**Desventajas**:
- ❌ NO resuelve infinite approvals
- ❌ Usuarios raramente lo usan
- ❌ Mayoría de dApps siguen usando approve()

---

### Workaround 2: EIP-2612 Permit (Gasless Approvals)

**Descripción**: Approvals mediante firmas off-chain (EIP-712)

```solidity
// EIP-2612
interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v, bytes32 r, bytes32 s
    ) external;
}

// Usuario firma off-chain
const signature = await signer.signTypedData({
    name: "Token",
    version: "1",
    chainId: 1,
    verifyingContract: tokenAddress
}, {
    Permit: [
        { name: "owner", type: "address" },
        { name: "spender", type: "address" },
        { name: "value", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" }
    ]
}, {
    owner: userAddress,
    spender: spenderAddress,
    value: amount,
    nonce: 0,
    deadline: deadline
});

// Contrato usa la firma (sin tx previa de approve)
token.permit(owner, spender, amount, deadline, v, r, s);
token.transferFrom(owner, recipient, amount);
```

**Ventajas**:
- ✅ UNA sola transacción (mejor UX)
- ✅ Usuario no paga gas por el approve
- ✅ Deadline integrado (expiración)
- ✅ Usado por DAI, USDC, USDT modernos

**Desventajas**:
- ❌ NO está en ERC20 original (requiere nueva implementación)
- ❌ Todavía permite infinite approvals
- ❌ Complejidad de firmas (phishing risk)

---

### Workaround 3: Uniswap Permit2

**Descripción**: Contrato centralizado de permisos con features avanzadas (2022)

```solidity
// Permit2 - Uniswap
contract Permit2 {
    // Approval con deadline
    struct PermitDetails {
        address token;
        uint160 amount;
        uint48 expiration;  // ⭐ Auto-expira
        uint48 nonce;
    }

    // Batch approvals
    function permit(
        address owner,
        PermitBatch calldata permitBatch,
        bytes calldata signature
    ) external;

    // Witness data (condiciones extra)
    function permitWitnessTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32 witness,  // ⭐ Datos adicionales firmados
        string calldata witnessTypeString,
        bytes calldata signature
    ) external;
}
```

**Ventajas**:
- ✅ Expiración automática de approvals
- ✅ Batch approvals (múltiples tokens en una firma)
- ✅ Witness data (permite condicionales complejos)
- ✅ Revocación más fácil
- ✅ Usado por Uniswap, 1inch, otros

**Desventajas**:
- ❌ Requiere deployment de contrato extra
- ❌ Todavía confía en que Permit2 no sea vulnerable
- ❌ Complejidad adicional
- ❌ Centralización (todos aprueban a UN contrato)

---

### Workaround 4: Approval Managers / Revokers

**Descripción**: Herramientas para que usuarios gestionen approvals activos

**Ejemplos:**
- **Revoke.cash**: UI para ver y revocar approvals
- **Etherscan Token Approvals**: Ver approvals por address
- **Rabby Wallet**: Alertas de infinite approvals

```solidity
// Usuario puede revocar manualmente
token.approve(suspiciousContract, 0);  // Revoca approval
```

**Ventajas**:
- ✅ Da visibilidad al problema
- ✅ Permite mitigación reactiva

**Desventajas**:
- ❌ Requiere acción manual del usuario
- ❌ La mayoría de usuarios no revoca
- ❌ Costos de gas para revocar

---

## 📜 EIPs Relacionados

### EIP-20: ERC20 Token Standard (2015)

- **Status**: Final
- **Problema**: Diseño original con `approve()` tiene race conditions
- **Impacto**: Se convirtió en estándar antes de descubrir problemas

### EIP-2612: Permit Extension for EIP-20 (2020)

- **Status**: Final
- **Solución**: Firmas off-chain para approvals
- **Adopción**: DAI, USDC, USDT v2
- **Mejora**: UX mejor, pero no resuelve infinite approvals

### EIP-3009: Transfer With Authorization (2020)

- **Status**: Final
- **Alternativa a Permit**: Centro Dollar (USDC) lo usa
- **Diferencia**: `transferWithAuthorization()` en vez de `approve()`

```solidity
function transferWithAuthorization(
    address from,
    address to,
    uint256 value,
    uint256 validAfter,
    uint256 validBefore,
    bytes32 nonce,
    uint8 v, bytes32 r, bytes32 s
) external;
```

### SWC-114: Transaction Order Dependence (SWC Registry)

- **Categoría**: Security vulnerability
- **Descripción**: Race condition en approve()
- **Mitigación**: Use `increaseAllowance()` / `decreaseAllowance()`

---

## ✨ Solución en Cadence

### ¿Cómo Cadence resuelve esto nativamente?

**Cadence NO tiene approvals** porque usa **Capabilities** en vez de permisos globales.

### Modelo de Capabilities

**Concepto**: En vez de dar permiso global, das una **capability** específica y revocable.

```cadence
// Cadence
access(all) contract TokenVault {
    // Resource que posee tokens
    access(all) resource Vault {
        access(all) var balance: UFix64

        // SOLO el dueño puede retirar directamente
        access(all) fun withdraw(amount: UFix64): @Vault {
            pre { self.balance >= amount }
            self.balance = self.balance - amount
            return <- create Vault(balance: amount)
        }

        // Interfaz pública limitada
        access(all) fun deposit(from: @Vault) {
            self.balance = self.balance + from.balance
            destroy from
        }

        access(all) fun getBalance(): UFix64 {
            return self.balance
        }
    }

    // ⭐ Capability delegada (como un "permiso limitado")
    access(all) resource interface Provider {
        access(all) fun withdraw(amount: UFix64): @Vault
    }

    access(all) resource interface Receiver {
        access(all) fun deposit(from: @Vault)
    }
}

// Usuario crea capabilities específicas
transaction {
    prepare(signer: auth(IssueStorageCapabilityController, PublishCapability) &Account) {
        // Capability SOLO para depositar (receive-only)
        let receiverCap = signer.capabilities.storage
            .issue<&{TokenVault.Receiver}>(/storage/mainVault)

        signer.capabilities.publish(receiverCap, at: /public/receiver)

        // Capability para withdraw (si realmente lo necesitas)
        // IMPORTANTE: NO se publica públicamente, se da específicamente
        let providerCap = signer.capabilities.storage
            .issue<&{TokenVault.Provider}>(/storage/mainVault)

        // Solo se da a un contrato específico, NO es público
        // Y puede revocarse en cualquier momento!
    }
}
```

### Comparación directa: Approve vs Capability

<table>
<tr>
<th>ERC20 Approve</th>
<th>Cadence Capability</th>
</tr>
<tr>
<td>

```solidity
// Solidity - Global state
mapping(address => mapping(address => uint256))
    private _allowances;

function approve(address spender, uint256 amount)
    external returns (bool) {
    _allowances[msg.sender][spender] = amount;
    // ⚠️ Persiste para siempre
    return true;
}

function transferFrom(
    address from,
    address to,
    uint256 amount
) external {
    require(_allowances[from][msg.sender] >= amount);
    _allowances[from][msg.sender] -= amount;
    _transfer(from, to, amount);
}
```

</td>
<td>

```cadence
// Cadence - Capability
access(all) fun getProviderCapability(
    owner: Address
): Capability<&{Provider}>? {
    // ⭐ Capability específica, no es global
    return owner.getCapability<&{Provider}>(
        /public/provider
    )
}

// Usuario puede REVOCAR en cualquier momento
access(all) fun revokeCapability() {
    // Elimina la capability
    self.account.unlink(/public/provider)
    // ✅ Instantáneo, sin rastro
}

// Transfer directo (no requiere approval)
let vault <- signer.borrow<&Vault>()
    .withdraw(amount: 100.0)

receiver.deposit(from: <-vault)
```

</td>
</tr>
</table>

### Ventajas del Modelo de Capabilities

1. **No hay approvals infinitos**: Cada capability es específica
2. **Revocación instantánea**: `unlink()` y desaparece
3. **Granularidad**: Puedes dar `Receiver` pero NO `Provider`
4. **Tipo seguro**: El compilador fuerza que solo uses las funciones permitidas
5. **No hay race conditions**: No hay estado global que cambiar
6. **Transferencias directas**: Mayoría de casos NO requieren capabilities

### Ejemplo Real: Swap en DEX

<table>
<tr>
<th>Uniswap (Solidity)</th>
<th>DEX en Cadence</th>
</tr>
<tr>
<td>

```solidity
// 1. Usuario aprueba (tx separada)
tokenA.approve(
    uniswapRouter,
    type(uint256).max  // ∞
);

// 2. Usuario hace swap
uniswapRouter.swapExactTokensForTokens(
    amountIn,
    amountOutMin,
    path,
    to,
    deadline
);
// Router usa transferFrom() con la approval
```

</td>
<td>

```cadence
// 1. Usuario retira sus tokens
let vaultA <- signer.borrow<&Vault>()
    .withdraw(amount: 100.0)

// 2. Hace swap directamente (1 tx)
let vaultB <- dex.swap(
    from: <-vaultA,
    minimumOut: 95.0
)

// 3. Deposita resultado
signer.borrow<&Vault>()
    .deposit(from: <-vaultB)

// ✅ No requiere approval
// ✅ DEX NO tiene acceso perpetuo
// ✅ Una transacción
```

</td>
</tr>
</table>

---

## ⚖️ Comparación

| Aspecto | ERC20 Approve | EIP-2612 Permit | Permit2 | Cadence Capabilities |
|---------|---------------|-----------------|---------|----------------------|
| **Requiere approval** | ✅ Sí | ✅ Sí (firma) | ✅ Sí (firma) | ❌ No |
| **Infinite approvals posibles** | ✅ Sí | ✅ Sí | ⚠️ Con expiry | ❌ Imposible |
| **Race conditions (SWC-114)** | ✅ Sí | ⚠️ Menos | ❌ No | ❌ No |
| **Revocación** | Manual | Manual | Manual | Automática |
| **Número de transacciones** | 2 | 1 | 1 | 1 |
| **Exploits en 2024** | $9.7M+ | - | - | $0 |

---

## 💻 Demo Práctica

Ver archivos en:
- `evm/problema.sol` - Infinite approval vulnerable
- `evm/workaround.sol` - Permit, Permit2 patterns
- `cadence/CapabilityPattern.cdc` - Capabilities en acción

Tests:
```bash
# Solidity
cd evm && forge test -vv

# Cadence
cd cadence && flow test tests/CapabilityPattern_test.cdc
```

---

## 📚 Recursos Adicionales

### Documentación Oficial
- [EIP-20 (ERC20)](https://eips.ethereum.org/EIPS/eip-20)
- [EIP-2612 (Permit)](https://eips.ethereum.org/EIPS/eip-2612)
- [Uniswap Permit2 Docs](https://docs.uniswap.org/contracts/permit2/overview)
- [Cadence Capabilities](https://developers.flow.com/cadence/language/capabilities)

### Análisis de Hacks
- [Li.Fi Hack Analysis](https://twitter.com/lifinance/status/1680959932034359297)
- [SenecaUSD Post-mortem](https://medium.com/@SenecaUSD/seneca-usd-incident-post-mortem-aef5e5c8de57)

### Herramientas
- [Revoke.cash](https://revoke.cash/) - Revocar approvals
- [Etherscan Token Approvals](https://etherscan.io/tokenapprovalchecker)

---

## 🔗 Enlaces Rápidos

- [← Capítulo Anterior: Integer Overflow](../02-overflow/)
- [↑ Índice General](../../INDEX.md)
- [→ Siguiente Capítulo: TBD](../04-tbd/)

---

**Tags**: `#ERC20` `#Approvals` `#Permit` `#Capabilities` `#SWC114`

**Fecha de creación**: 2025-11-14
**Última actualización**: 2025-11-14
**Estado**: 🟢 Completo
