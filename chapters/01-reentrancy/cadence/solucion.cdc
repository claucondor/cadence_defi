/**
 * SOLUCIÓN EN CADENCE: Reentrancy es IMPOSIBLE por diseño
 *
 * En este archivo verás cómo Cadence previene reentrancy automáticamente
 * usando Resources y linear types, sin necesidad de workarounds manuales.
 *
 * CONCEPTOS CLAVE:
 * 1. Resources: Objetos únicos que solo pueden existir en UN lugar a la vez
 * 2. Linear Types: Resources deben ser usados exactamente una vez
 * 3. Ownership: Solo el dueño de un Resource puede llamar sus métodos
 * 4. Move Semantics: Resources se MUEVEN, no se copian
 *
 * RESULTADO: Reentrancy es imposible - el compilador lo previene
 */

// ============================================================================
// EJEMPLO 1: Vault Básico (Reentrancy imposible)
// ============================================================================

pub contract SimpleVault {

    /**
     * Resource: VaultResource
     *
     * ⭐ CLAVE: Este es un RESOURCE, no una clase normal
     *
     * Propiedades de Resources:
     * 1. Solo puede existir en UN lugar a la vez
     * 2. Solo el DUEÑO puede llamar sus métodos
     * 3. No puede ser copiado, solo movido
     * 4. Debe ser manejado explícitamente (no puede ser olvidado)
     */
    pub resource VaultResource {

        // Balance del vault
        pub var balance: UFix64

        init() {
            self.balance = 0.0
        }

        /**
         * Depositar tokens en el vault
         *
         * @param from: El vault de donde vienen los tokens
         *
         * IMPORTANTE: El parámetro `from` tiene el operador `@` que significa
         * que es un Resource que se está MOVIENDO (no copiando)
         *
         * Una vez que el Resource se mueve a esta función, el caller
         * YA NO puede usarlo - el ownership se transfiere
         */
        pub fun deposit(from: @FungibleToken.Vault) {
            // Extraer el balance del vault que recibimos
            let amount = from.balance

            // ⭐ PREVENCIÓN DE REENTRANCY #1:
            // Destruimos el vault recibido ANTES de actualizar estado
            // No hay forma de "reusar" este vault - ya fue destruido
            destroy from

            // Actualizar balance
            self.balance = self.balance + amount
        }

        /**
         * Retirar tokens del vault
         *
         * @param amount: Cantidad a retirar
         * @return: Un NUEVO vault con los tokens retirados
         *
         * ⭐ PREVENCIÓN DE REENTRANCY #2:
         * La función RETORNA un Resource (@FungibleToken.Vault)
         *
         * El compilador FUERZA que el caller maneje este Resource:
         * - Debe almacenarlo en algún lado
         * - O destruirlo explícitamente
         * - Si no hace ninguna, el código NO COMPILA
         *
         * No hay forma de "olvidarse" de manejar el valor de retorno
         */
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            // Pre-condición: Verificar que tenemos suficiente balance
            pre {
                self.balance >= amount: "Insufficient balance"
            }

            // ⭐ CLAVE: Actualizamos el balance ANTES de crear el nuevo vault
            // (Aunque técnicamente no importa, porque reentrancy es imposible)
            self.balance = self.balance - amount

            // Crear un NUEVO vault con los tokens retirados
            // Este vault se MUEVE al caller
            return <- FungibleToken.createVault(amount: amount)
        }

        /**
         * Destructor del vault
         *
         * ⭐ SEGURIDAD: Si intentas destruir un vault con balance > 0,
         * el compilador lo previene (a menos que manejes los fondos)
         */
        destroy() {
            // En un vault real, esto verificaría que balance == 0
            // o transferiría los fondos a un vault de recuperación
            pre {
                self.balance == 0.0: "Cannot destroy vault with balance"
            }
        }
    }

    /**
     * Crear un nuevo vault vacío
     *
     * @return: Un nuevo VaultResource con balance 0
     *
     * Nota: El operador `<-` se usa para MOVER Resources
     */
    pub fun createVault(): @VaultResource {
        return <- create VaultResource()
    }
}

// ============================================================================
// EJEMPLO 2: ¿Por qué reentrancy es IMPOSIBLE?
// ============================================================================

/**
 * Este ejemplo demuestra por qué un ataque de reentrancy no puede ocurrir
 */

// Supongamos que un atacante intenta hacer reentrancy:
//
// transaction {
//
//     let vaultRef: &SimpleVault.VaultResource
//
//     prepare(signer: AuthAccount) {
//         // Obtener referencia al vault del atacante
//         self.vaultRef = signer.borrow<&SimpleVault.VaultResource>(
//             from: /storage/vault
//         ) ?? panic("Vault not found")
//     }
//
//     execute {
//         // Atacante intenta retirar
//         let withdrawn <- self.vaultRef.withdraw(amount: 1.0)
//
//         // ❌ REENTRANCY IMPOSIBLE AQUÍ
//         //
//         // ¿Por qué?
//         //
//         // 1. El vault `withdrawn` es un RESOURCE
//         // 2. Debe ser manejado explícitamente
//         // 3. Si intentamos llamar withdraw() otra vez ANTES de
//         //    manejar `withdrawn`, el compilador da ERROR:
//         //
//         //    "loss of resource"
//         //
//         // 4. El compilador FUERZA que depositemos o destruyamos
//         //    `withdrawn` antes de hacer otra operación
//
//         // Por ejemplo, si intentamos:
//         // let withdrawn2 <- self.vaultRef.withdraw(amount: 1.0)
//         // ERROR: "loss of resource `withdrawn`"
//
//         // Debemos manejar `withdrawn` primero:
//         destroy withdrawn  // o depositarlo en otro vault
//
//         // Ahora sí podemos hacer otro withdraw
//         let withdrawn2 <- self.vaultRef.withdraw(amount: 1.0)
//         destroy withdrawn2
//
//         // Pero esto NO es reentrancy - son dos operaciones secuenciales
//         // El balance ya se actualizó después del primer withdraw
//     }
// }

// ============================================================================
// EJEMPLO 3: Vault Completo con Capabilities
// ============================================================================

/**
 * Este es un ejemplo más completo que usa Capabilities para control de acceso
 *
 * CAPABILITIES en Cadence:
 * - Son como "llaves" para acceder a Resources
 * - Se pueden revocar
 * - Se pueden dar permisos limitados (solo lectura, solo withdraw, etc.)
 * - Mucho más flexible que `msg.sender` de Solidity
 */

pub contract SecureVault {

    pub let VaultStoragePath: StoragePath
    pub let VaultPublicPath: PublicPath

    init() {
        self.VaultStoragePath = /storage/secureVault
        self.VaultPublicPath = /public/secureVault
    }

    /**
     * Interface pública del Vault
     * Solo expone funciones de lectura
     */
    pub resource interface VaultPublic {
        pub fun getBalance(): UFix64
    }

    /**
     * Interface privada del Vault
     * Expone funciones que modifican estado
     */
    pub resource interface VaultPrivate {
        pub fun deposit(from: @FungibleToken.Vault)
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault
    }

    /**
     * El Vault completo implementa ambas interfaces
     */
    pub resource Vault: VaultPublic, VaultPrivate {

        pub var balance: UFix64

        init() {
            self.balance = 0.0
        }

        // ========================================
        // Funciones Públicas (solo lectura)
        // ========================================

        pub fun getBalance(): UFix64 {
            return self.balance
        }

        // ========================================
        // Funciones Privadas (modifican estado)
        // ========================================

        /**
         * Depositar tokens
         *
         * ⭐ SEGURIDAD:
         * - Solo quien tiene la capability VaultPrivate puede llamar esto
         * - El vault `from` se destruye, no puede reutilizarse
         */
        pub fun deposit(from: @FungibleToken.Vault) {
            let amount = from.balance
            destroy from
            self.balance = self.balance + amount
        }

        /**
         * Retirar tokens
         *
         * ⭐ SEGURIDAD:
         * - Solo quien tiene la capability VaultPrivate puede llamar esto
         * - El compilador fuerza que el caller maneje el vault retornado
         * - Reentrancy es imposible
         */
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            pre {
                self.balance >= amount: "Insufficient balance"
            }

            self.balance = self.balance - amount
            return <- FungibleToken.createVault(amount: amount)
        }

        destroy() {
            pre {
                self.balance == 0.0: "Cannot destroy vault with balance"
            }
        }
    }

    /**
     * Crear un nuevo vault
     */
    pub fun createVault(): @Vault {
        return <- create Vault()
    }

    /**
     * Setup inicial para una cuenta
     *
     * Esta función muestra cómo un usuario configura su cuenta
     * para tener un vault y exponer solo lo necesario públicamente
     */
    pub fun setupAccount(account: AuthAccount) {
        // Crear el vault
        let vault <- create Vault()

        // Guardarlo en storage privado
        account.save(<-vault, to: self.VaultStoragePath)

        // Crear capability pública (solo lectura)
        account.link<&Vault{VaultPublic}>(
            self.VaultPublicPath,
            target: self.VaultStoragePath
        )

        // El dueño mantiene acceso completo via AuthAccount
        // Otros solo pueden leer el balance via VaultPublic capability
    }
}

// ============================================================================
// EJEMPLO 4: Mock FungibleToken para testing
// ============================================================================

/**
 * Implementación simplificada de FungibleToken para estos ejemplos
 * En producción, usarías el estándar FungibleToken de Flow
 */
pub contract FungibleToken {

    pub resource Vault {
        pub var balance: UFix64

        init(balance: UFix64) {
            self.balance = balance
        }

        destroy() {
            // En un token real, esto actualizaría supply total
        }
    }

    pub fun createVault(amount: UFix64): @Vault {
        return <- create Vault(balance: amount)
    }
}

// ============================================================================
// COMPARACIÓN: Cadence vs Solidity
// ============================================================================

/**
 * SOLIDITY (Requiere workarounds manuales):
 *
 * ```solidity
 * function withdraw() public nonReentrant {  // ← Debes recordar esto
 *     uint256 balance = balances[msg.sender];
 *     require(balance > 0);
 *
 *     balances[msg.sender] = 0;  // ← Debes recordar el orden correcto
 *
 *     (bool success, ) = msg.sender.call{value: balance}("");
 *     require(success);
 * }
 * ```
 *
 * PROBLEMAS:
 * - Debes RECORDAR usar nonReentrant
 * - Debes RECORDAR el orden CEI
 * - Compilador no te ayuda
 * - Costo extra de gas (~2,500)
 * - Aún vulnerable a reentrancy cross-contract
 *
 *
 * CADENCE (Seguro por diseño):
 *
 * ```cadence
 * pub fun withdraw(amount: UFix64): @Vault {  // ← No necesitas modifiers
 *     pre {
 *         self.balance >= amount
 *     }
 *
 *     self.balance = self.balance - amount
 *
 *     return <- createVault(amount: amount)  // ← Compiler fuerza manejo
 * }
 * ```
 *
 * VENTAJAS:
 * - ✅ No necesitas recordar nada
 * - ✅ Compilador previene reentrancy automáticamente
 * - ✅ Zero overhead de gas
 * - ✅ Imposible olvidarse o equivocarse
 * - ✅ Linear types garantizan seguridad
 *
 *
 * RESUMEN:
 *
 * | Aspecto              | Solidity              | Cadence              |
 * |----------------------|-----------------------|----------------------|
 * | Protección           | Manual                | Automática           |
 * | Overhead de gas      | ~2,500 gas            | 0 (compile-time)     |
 * | Puede olvidarse      | ✅ Sí (común)          | ❌ Imposible         |
 * | Requiere expertise   | ✅ Sí                  | ❌ No                |
 * | Garantía             | ⚠️ Si se aplica        | ✅ Siempre           |
 * | Code review          | ⚠️ Puede pasarse       | ✅ Type system       |
 */
