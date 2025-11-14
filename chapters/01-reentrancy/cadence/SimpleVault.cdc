/**
 * SimpleVault - Demostración de cómo Cadence previene Reentrancy
 *
 * Este contrato demuestra que en Cadence, los ataques de reentrancy
 * son IMPOSIBLES por el diseño del lenguaje usando Resources.
 *
 * Sintaxis: Cadence 1.0
 */

access(all) contract SimpleVault {

    // Eventos
    access(all) event VaultCreated(initialBalance: UFix64)
    access(all) event Deposit(amount: UFix64, newBalance: UFix64)
    access(all) event Withdrawal(amount: UFix64, newBalance: UFix64)

    /**
     * MockToken Resource - Simulación simple de un token
     *
     * En producción usarías el estándar FungibleToken de Flow,
     * pero para este demo creamos una versión simplificada.
     */
    access(all) resource Token {
        access(all) var balance: UFix64

        init(balance: UFix64) {
            self.balance = balance
        }

        access(all) fun getBalance(): UFix64 {
            return self.balance
        }
    }

    /**
     * VaultResource - El vault principal
     *
     * ⭐ CLAVE: Este es un RESOURCE, no una clase normal
     *
     * Propiedades de Resources:
     * 1. Solo puede existir en UN lugar a la vez
     * 2. Solo el DUEÑO puede llamar sus métodos
     * 3. No puede ser copiado, solo movido (<-)
     * 4. Debe ser manejado explícitamente (no puede ser olvidado)
     */
    access(all) resource Vault {

        access(all) var balance: UFix64

        init(initialBalance: UFix64) {
            self.balance = initialBalance
            emit VaultCreated(initialBalance: initialBalance)
        }

        /**
         * Depositar tokens en el vault
         *
         * @param tokens: Resource de tokens que se está MOVIENDO (operador @)
         *
         * ⭐ PREVENCIÓN DE REENTRANCY #1:
         * El Resource `tokens` se destruye INMEDIATAMENTE.
         * No hay forma de "reusar" este resource - ya fue destruido.
         */
        access(all) fun deposit(tokens: @Token) {
            let amount = tokens.balance

            // Destruir el resource recibido
            // Esto previene que pueda ser usado nuevamente
            destroy tokens

            // Actualizar balance
            self.balance = self.balance + amount

            emit Deposit(amount: amount, newBalance: self.balance)
        }

        /**
         * Retirar tokens del vault
         *
         * @param amount: Cantidad a retirar
         * @return: Un NUEVO Token resource con los tokens retirados
         *
         * ⭐ PREVENCIÓN DE REENTRANCY #2:
         * La función RETORNA un Resource (@Token)
         *
         * El compilador FUERZA que el caller maneje este Resource:
         * - Debe almacenarlo, depositarlo, o destruirlo
         * - Si no lo maneja, el código NO COMPILA
         * - No hay forma de "olvidarse" de manejar el valor de retorno
         *
         * ⭐ PREVENCIÓN DE REENTRANCY #3:
         * Mientras el caller maneja el Token retornado, NO puede
         * llamar withdraw() otra vez porque:
         * 1. El Resource retornado debe ser manejado primero
         * 2. El compilador da error si intentas hacer otra operación
         *    sin manejar el resource pendiente
         */
        access(all) fun withdraw(amount: UFix64): @Token {
            pre {
                self.balance >= amount: "Insufficient balance to withdraw"
            }

            // Actualizar balance ANTES de crear el nuevo token
            // (Aunque en Cadence el orden no importa para reentrancy,
            // es buena práctica)
            self.balance = self.balance - amount

            emit Withdrawal(amount: amount, newBalance: self.balance)

            // Crear y retornar un NUEVO token resource
            // Este resource se MUEVE al caller
            return <- create Token(balance: amount)
        }

        /**
         * Obtener balance (función de lectura)
         */
        access(all) fun getBalance(): UFix64 {
            return self.balance
        }
    }

    /**
     * Crear un nuevo vault
     *
     * @param initialBalance: Balance inicial del vault
     * @return: Un nuevo Vault resource
     *
     * Nota: El operador `<-` se usa para MOVER Resources
     */
    access(all) fun createVault(initialBalance: UFix64): @Vault {
        return <- create Vault(initialBalance: initialBalance)
    }

    /**
     * Crear tokens para testing
     */
    access(all) fun createTokens(amount: UFix64): @Token {
        return <- create Token(balance: amount)
    }

    init() {
        // El contrato se inicializa vacío
    }
}

/**
 * ============================================================================
 * ¿POR QUÉ REENTRANCY ES IMPOSIBLE EN ESTE CÓDIGO?
 * ============================================================================
 *
 * Imaginemos que un atacante intenta hacer reentrancy:
 *
 * 1. Atacante llama vault.withdraw(100.0)
 * 2. withdraw() retorna un @Token resource
 * 3. El compilador FUERZA que el atacante maneje ese @Token
 * 4. Mientras no maneje el @Token, NO PUEDE llamar withdraw() otra vez
 * 5. Si intenta hacerlo: "loss of resource" - ERROR DE COMPILACIÓN
 *
 * EJEMPLO DE CÓDIGO QUE NO COMPILA:
 *
 * ```cadence
 * let token1 <- vault.withdraw(amount: 100.0)
 * let token2 <- vault.withdraw(amount: 100.0)  // ERROR: "loss of resource token1"
 * ```
 *
 * El compilador dice: "¿Qué vas a hacer con token1? No puedes olvidarlo!"
 *
 * CÓDIGO CORRECTO (no es reentrancy, son dos operaciones secuenciales):
 *
 * ```cadence
 * let token1 <- vault.withdraw(amount: 100.0)
 * destroy token1  // o depositarlo en otro vault
 *
 * // Ahora sí puedes hacer otro withdraw
 * let token2 <- vault.withdraw(amount: 100.0)
 * destroy token2
 * ```
 *
 * Pero esto NO es reentrancy porque:
 * - El primer withdraw() YA terminó completamente
 * - El balance YA se actualizó
 * - Son dos operaciones independientes y secuenciales
 *
 * ============================================================================
 * COMPARACIÓN CON SOLIDITY
 * ============================================================================
 *
 * SOLIDITY (Vulnerable sin protección):
 * ```solidity
 * function withdraw() public {
 *     uint balance = balances[msg.sender];
 *     msg.sender.call{value: balance}("");  // ⚠️ Atacante re-entra AQUÍ
 *     balances[msg.sender] = 0;  // ❌ Demasiado tarde!
 * }
 * ```
 *
 * SOLIDITY (Con ReentrancyGuard):
 * ```solidity
 * function withdraw() public nonReentrant {  // ← Debes recordar esto
 *     uint balance = balances[msg.sender];
 *     balances[msg.sender] = 0;  // ← Debes recordar el orden
 *     msg.sender.call{value: balance}("");
 * }
 * ```
 * Costo: ~2,500 gas extra por transacción
 * Depende de: Que el desarrollador lo recuerde
 *
 * CADENCE (Seguro por diseño):
 * ```cadence
 * access(all) fun withdraw(amount: UFix64): @Token {
 *     pre { self.balance >= amount }
 *     self.balance = self.balance - amount
 *     return <- create Token(balance: amount)
 * }
 * ```
 * Costo: 0 extra (compile-time safety)
 * Depende de: Nada, el compilador te protege automáticamente
 *
 * ============================================================================
 */
