// Cadence 1.0 - Capability-Based Access Control
// NO approvals needed - capabilities are unforgeable references

access(all) contract CapabilityPattern {

    // ═══════════════════════════════════════════════════════════════════
    // RESOURCE: Vault (similar a ERC20 pero con ownership real)
    // ═══════════════════════════════════════════════════════════════════

    access(all) resource Vault {
        access(all) var balance: UFix64

        init(balance: UFix64) {
            self.balance = balance
        }

        // SOLO el dueño directo puede retirar
        access(all) fun withdraw(amount: UFix64): @Vault {
            pre {
                self.balance >= amount: "Insufficient balance"
            }
            self.balance = self.balance - amount
            return <- create Vault(balance: amount)
        }

        // Cualquiera con referencia puede depositar
        access(all) fun deposit(from: @Vault) {
            self.balance = self.balance + from.balance
            destroy from
        }

        access(all) fun getBalance(): UFix64 {
            return self.balance
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // INTERFACES: Definen capabilities específicas
    // ═══════════════════════════════════════════════════════════════════

    // Capability SOLO para retirar (peligrosa - raramente se da)
    access(all) resource interface Provider {
        access(all) fun withdraw(amount: UFix64): @Vault
    }

    // Capability SOLO para depositar (común - recibir pagos)
    access(all) resource interface Receiver {
        access(all) fun deposit(from: @Vault)
    }

    // Capability SOLO para leer balance (pública)
    access(all) resource interface Balance {
        access(all) fun getBalance(): UFix64
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONTRACT FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════

    access(all) fun createEmptyVault(): @Vault {
        return <- create Vault(balance: 0.0)
    }

    access(all) fun createVault(balance: UFix64): @Vault {
        return <- create Vault(balance: balance)
    }
}

// ═══════════════════════════════════════════════════════════════════════
// EJEMPLO: DEX sin approvals
// ═══════════════════════════════════════════════════════════════════════

access(all) contract SimpleDEX {

    // Pool de liquidez (simplificado)
    access(self) let liquidityVault: @CapabilityPattern.Vault

    init() {
        self.liquidityVault <- CapabilityPattern.createVault(balance: 10000.0)
    }

    // ✅ Swap directo - NO requiere approval!
    // Usuario pasa su vault directamente, DEX no tiene acceso persistente
    access(all) fun swap(from: @CapabilityPattern.Vault, minimumOut: UFix64): @CapabilityPattern.Vault {
        pre {
            from.balance > 0.0: "Cannot swap zero amount"
            minimumOut > 0.0: "Invalid minimum output"
        }

        let inputAmount = from.balance

        // Simula swap 1:1 (en realidad sería AMM curve)
        let outputAmount = inputAmount * 0.97  // 3% fee

        // Valida slippage
        if outputAmount < minimumOut {
            panic("Slippage too high")
        }

        // Deposita input al pool
        self.liquidityVault.deposit(from: <-from)

        // Retira output del pool
        let output <- self.liquidityVault.withdraw(amount: outputAmount)

        return <- output
    }

    // ✅ NO hay función "drainApprovals" - es IMPOSIBLE
    // El DEX solo tiene acceso a tokens durante la transacción
}

// ═══════════════════════════════════════════════════════════════════════
// EJEMPLO: Capability delegada (caso avanzado)
// ═══════════════════════════════════════════════════════════════════════

access(all) contract DelegatedWithdrawal {

    // Estructura para withdrawal delegado con límites
    access(all) struct WithdrawalCapInfo {
        access(all) let maxAmount: UFix64
        access(all) let expiry: UFix64

        init(maxAmount: UFix64, expiry: UFix64) {
            self.maxAmount = maxAmount
            self.expiry = expiry
        }
    }

    // Resource que controla withdrawals delegados
    access(all) resource WithdrawalController {
        access(all) let vaultCap: Capability<&{CapabilityPattern.Provider}>
        access(all) var withdrawn: UFix64
        access(all) let maxAmount: UFix64
        access(all) let expiry: UFix64

        init(
            vaultCap: Capability<&{CapabilityPattern.Provider}>,
            maxAmount: UFix64,
            expiry: UFix64
        ) {
            self.vaultCap = vaultCap
            self.withdrawn = 0.0
            self.maxAmount = maxAmount
            self.expiry = expiry
        }

        // ✅ Withdrawal con límites y expiry
        access(all) fun withdrawUpTo(amount: UFix64): @CapabilityPattern.Vault {
            pre {
                getCurrentBlock().timestamp <= self.expiry: "Capability expired"
                self.withdrawn + amount <= self.maxAmount: "Exceeds maximum amount"
            }

            let vaultRef = self.vaultCap.borrow()
                ?? panic("Could not borrow vault capability")

            let tokens <- vaultRef.withdraw(amount: amount)
            self.withdrawn = self.withdrawn + amount

            return <- tokens
        }

        // ✅ Revocación: Owner del vault puede unlink la capability
        // Esto invalida TODAS las referencias instantáneamente
    }

    access(all) fun createWithdrawalController(
        vaultCap: Capability<&{CapabilityPattern.Provider}>,
        maxAmount: UFix64,
        expiry: UFix64
    ): @WithdrawalController {
        return <- create WithdrawalController(
            vaultCap: vaultCap,
            maxAmount: maxAmount,
            expiry: expiry
        )
    }
}

// ═══════════════════════════════════════════════════════════════════════
// COMPARACIÓN: Approve vs Capability
// ═══════════════════════════════════════════════════════════════════════

/**
 * ERC20 Approve (Solidity):
 * ═══════════════════════════════════════════════════════════════════════
 *
 * // Usuario aprueba
 * token.approve(spender, type(uint256).max);  // ∞ approval
 *
 * // Spender puede usar CUANDO QUIERA
 * token.transferFrom(user, attacker, balance);  // Incluso años después!
 *
 * PROBLEMAS:
 * ❌ Permiso global persistente
 * ❌ No expira automáticamente
 * ❌ Si spender es hackeado → todos pierden fondos
 * ❌ Race conditions (SWC-114)
 * ❌ Usuario debe revocar manualmente (y pagar gas)
 *
 * ═══════════════════════════════════════════════════════════════════════
 *
 * Cadence Capability:
 * ═══════════════════════════════════════════════════════════════════════
 *
 * // Usuario crea capability específica (opcional)
 * let cap = account.capabilities.storage
 *     .issue<&{Provider}>(/storage/vault)
 * account.capabilities.publish(cap, at: /public/provider)
 *
 * // O simplemente transfer directo (común)
 * let vault <- vaultRef.withdraw(amount: 100.0)
 * dex.swap(from: <-vault)
 *
 * VENTAJAS:
 * ✅ Mayoría de casos NO requieren capability (transfer directo)
 * ✅ Capabilities son específicas (solo Provider, solo Receiver, etc.)
 * ✅ Revocación instantánea (unlink)
 * ✅ Tipo-seguras (compilador fuerza permisos)
 * ✅ No hay estado global mutable
 * ✅ No hay race conditions
 * ✅ Si contrato es hackeado → solo afecta esa tx, no todos los fondos
 *
 * ═══════════════════════════════════════════════════════════════════════
 */
