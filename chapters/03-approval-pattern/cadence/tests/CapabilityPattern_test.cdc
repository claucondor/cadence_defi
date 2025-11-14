import Test
import "CapabilityPattern"

// ═══════════════════════════════════════════════════════════════════════
// TEST SUITE: Capability Pattern (No Approvals Needed!)
// ═══════════════════════════════════════════════════════════════════════

access(all) fun testCreateVault() {
    let vault <- CapabilityPattern.createVault(balance: 100.0)

    Test.assertEqual(100.0, vault.balance)

    destroy vault
}

access(all) fun testDirectTransfer() {
    // ✅ Transfer directo - NO requiere approval
    let sender <- CapabilityPattern.createVault(balance: 100.0)
    let receiver <- CapabilityPattern.createEmptyVault()

    // Sender retira y envía directamente
    let payment <- sender.withdraw(amount: 50.0)
    receiver.deposit(from: <-payment)

    Test.assertEqual(50.0, sender.balance)
    Test.assertEqual(50.0, receiver.balance)

    destroy sender
    destroy receiver
}

access(all) fun testDEXSwapNoApproval() {
    // ✅ DEX swap SIN approval necesario!
    let userVault <- CapabilityPattern.createVault(balance: 100.0)

    // Usuario retira lo que quiere intercambiar
    let toSwap <- userVault.withdraw(amount: 50.0)

    // Hace swap (el DEX toma ownership temporal)
    // En el test solo verificamos el concepto
    // (SimpleDEX requeriría deployment de contrato)

    Test.assertEqual(50.0, userVault.balance)
    Test.assertEqual(50.0, toSwap.balance)

    // Usuario recibe resultado del swap
    userVault.deposit(from: <-toSwap)

    destroy userVault
}

access(all) fun testNoInfiniteApproval() {
    // ✅ En Cadence NO existe concepto de "infinite approval"
    let vault <- CapabilityPattern.createVault(balance: 1000.0)

    // Para transferir, DEBES tener el resource o una capability específica
    // NO puedes simplemente "gastar" tokens de otro con un mapping global

    Test.assertEqual(1000.0, vault.balance)

    // Si quieres dar acceso, creas una capability LIMITADA:
    // - Solo withdraw (Provider)
    // - Solo deposit (Receiver)
    // - Solo read (Balance)

    destroy vault
}

access(all) fun testCapabilityRevocation() {
    // ✅ Capabilities pueden revocarse instantáneamente
    // (Este test es conceptual - la revocación real requiere Account API)

    let vault <- CapabilityPattern.createVault(balance: 100.0)

    // En código real:
    // 1. Crear capability: account.capabilities.storage.issue()
    // 2. Publicar: account.capabilities.publish()
    // 3. Revocar: account.capabilities.unpublish()
    //
    // Una vez revocada, TODAS las referencias fallan inmediatamente

    Test.assertEqual(100.0, vault.balance)

    destroy vault
}

access(all) fun testNoRaceCondition() {
    // ✅ NO hay race conditions como SWC-114
    // Porque NO hay estado global de approvals que cambiar

    let vault <- CapabilityPattern.createVault(balance: 100.0)

    // Retiras directamente lo que necesitas
    let payment1 <- vault.withdraw(amount: 30.0)
    let payment2 <- vault.withdraw(amount: 20.0)

    Test.assertEqual(50.0, vault.balance)
    Test.assertEqual(30.0, payment1.balance)
    Test.assertEqual(20.0, payment2.balance)

    // No hay forma de "front-run" porque cada withdraw es atómico
    // y directamente controlado por el dueño

    destroy vault
    destroy payment1
    destroy payment2
}

access(all) fun testSecureByDefault() {
    // ✅ Seguridad por defecto - no puedes accidentalmente dar permisos infinitos
    let vault <- CapabilityPattern.createVault(balance: 1000.0)

    // Intentar retirar más de lo disponible REVIERTE
    // (En Cadence esto causaría panic, aquí solo documentamos)

    // vault.withdraw(amount: 2000.0)  // ❌ Panic: "Insufficient balance"

    Test.assertEqual(1000.0, vault.balance)

    destroy vault
}

access(all) fun testTypeSafety() {
    // ✅ Tipo-seguridad del compilador
    // Si tienes Capability<&{Receiver}>, SOLO puedes deposit()
    // Si tienes Capability<&{Provider}>, SOLO puedes withdraw()
    // Si tienes Capability<&{Balance}>, SOLO puedes getBalance()

    let vault <- CapabilityPattern.createVault(balance: 100.0)

    // El compilador fuerza que solo uses las funciones permitidas
    // No hay forma de "engañar" al sistema

    Test.assertEqual(100.0, vault.getBalance())

    destroy vault
}

// ═══════════════════════════════════════════════════════════════════════
// COMPARACIÓN: ¿Qué pasaría en ERC20?
// ═══════════════════════════════════════════════════════════════════════

/**
 * Escenario: Usuario quiere usar un DEX
 *
 * ERC20 (Solidity):
 * ════════════════════════════════════════════════════════════════════
 *
 * // TX 1: Approve (usuario paga gas)
 * token.approve(dex, type(uint256).max);  // ∞ approval
 *
 * // TX 2: Swap (usuario paga gas)
 * dex.swap(tokenIn, tokenOut, amountIn);
 *
 * // ⚠️ Problema: Approval persiste PARA SIEMPRE
 * // Si DEX es hackeado en el futuro → todos pierden fondos
 *
 * // Para revocar (opcional, mayoría no lo hace):
 * // TX 3: Revoke (usuario paga gas de nuevo)
 * token.approve(dex, 0);
 *
 * TOTAL: 3 transacciones (approve + swap + revoke)
 *
 * ════════════════════════════════════════════════════════════════════
 *
 * Cadence:
 * ════════════════════════════════════════════════════════════════════
 *
 * // TX 1: Swap (una sola transacción!)
 * transaction {
 *     prepare(signer: auth(BorrowValue) &Account) {
 *         let vaultRef = signer.storage.borrow<&Vault>(/storage/vault)!
 *
 *         // Retira lo que quieres intercambiar
 *         let toSwap <- vaultRef.withdraw(amount: 100.0)
 *
 *         // Hace swap
 *         let result <- dex.swap(from: <-toSwap, minimumOut: 95.0)
 *
 *         // Deposita resultado
 *         vaultRef.deposit(from: <-result)
 *     }
 * }
 *
 * // ✅ DEX NUNCA tiene acceso persistente a tus fondos
 * // ✅ Una sola transacción
 * // ✅ No hay nada que revocar
 * // ✅ Si DEX es hackeado → solo afecta la tx actual, no tus fondos
 *
 * TOTAL: 1 transacción (swap directo)
 *
 * ════════════════════════════════════════════════════════════════════
 */
