// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Soluciones a Reentrancy en Solidity
 * @notice Este archivo demuestra 3 workarounds principales para prevenir reentrancy
 * @dev Todos estos patrones son MANUALES - el desarrollador debe recordar aplicarlos
 */

// ============================================================================
// SOLUCIÓN 1: CHECKS-EFFECTS-INTERACTIONS PATTERN
// ============================================================================

/**
 * @title CEIVault (Checks-Effects-Interactions)
 * @notice ✅ Vault seguro usando el patrón CEI
 * @dev ORDEN CORRECTO:
 *      1. Checks: Validar condiciones
 *      2. Effects: Actualizar estado
 *      3. Interactions: Llamar contratos externos
 *
 * VENTAJAS:
 * - No requiere librerías externas
 * - Gas-efficient (sin overhead)
 * - Patrón estándar de la industria
 *
 * DESVENTAJAS:
 * - Depende 100% de la disciplina del desarrollador
 * - Fácil olvidarlo en funciones complejas
 * - No hay enforcement del compilador
 */
contract CEIVault {

    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    function deposit() public payable {
        require(msg.value > 0, "Must deposit something");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice ✅ FUNCIÓN SEGURA usando CEI pattern
     * @dev ORDEN CORRECTO DE OPERACIONES
     */
    function withdraw() public {
        // 1️⃣ CHECKS: Validar todas las condiciones primero
        uint256 balance = balances[msg.sender];
        require(balance > 0, "Insufficient balance");

        // 2️⃣ EFFECTS: Actualizar TODOS los estados ANTES de interacciones externas
        // ⭐ CLAVE: Esto previene reentrancy porque el balance ya es 0
        balances[msg.sender] = 0;

        // 3️⃣ INTERACTIONS: Llamadas externas al FINAL
        // Ahora, aunque el atacante re-entre, su balance es 0
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");

        emit Withdrawal(msg.sender, balance);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

// ============================================================================
// SOLUCIÓN 2: REENTRANCYGUARD (OpenZeppelin)
// ============================================================================

/**
 * @title ReentrancyGuard (Simplified OpenZeppelin Implementation)
 * @notice Modifier que usa un "mutex lock" para prevenir llamadas recursivas
 * @dev Funciona como un semáforo: solo 1 función puede ejecutarse a la vez
 */
abstract contract ReentrancyGuard {

    // Estados del lock
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @notice Modifier que previene llamadas recursivas
     * @dev Funciona así:
     *      1. Verifica que no estemos en una llamada recursiva
     *      2. Marca que entramos a la función (_status = ENTERED)
     *      3. Ejecuta la función
     *      4. Marca que salimos (_status = NOT_ENTERED)
     *
     * Si un atacante intenta re-entrar, la verificación en paso 1 falla
     *
     * COSTO DE GAS:
     * - ~2,500 gas extra por función protegida
     * - 2 SSTOREs (escribir storage): uno al entrar, uno al salir
     * - Con EIP-1153 (Transient Storage), se reduce drásticamente
     */
    modifier nonReentrant() {
        // 1. Verificar que no estamos en una llamada recursiva
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // 2. Marcar que entramos
        _status = _ENTERED;

        // 3. Ejecutar la función
        _;

        // 4. Marcar que salimos (permite futuras llamadas)
        _status = _NOT_ENTERED;
    }
}

/**
 * @title GuardedVault
 * @notice ✅ Vault protegido con ReentrancyGuard
 * @dev Usa el modifier nonReentrant para protección automática
 *
 * VENTAJAS:
 * - Fácil de aplicar (solo agregar modifier)
 * - Librería auditada (OpenZeppelin)
 * - Explícito en el código
 *
 * DESVENTAJAS:
 * - Costo extra de gas (~2,500 por transacción)
 * - Aún requiere que el dev lo aplique manualmente
 * - Puede olvidarse en algunas funciones
 * - No protege contra reentrancy cross-contract
 */
contract GuardedVault is ReentrancyGuard {

    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    function deposit() public payable {
        require(msg.value > 0, "Must deposit something");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice ✅ FUNCIÓN PROTEGIDA con nonReentrant
     * @dev El modifier previene que esta función sea llamada recursivamente
     *
     * NOTA: Incluso con el guard, es BUENA PRÁCTICA seguir CEI pattern
     */
    function withdraw() public nonReentrant {  // ⭐ PROTECCIÓN AQUÍ
        uint256 balance = balances[msg.sender];
        require(balance > 0, "Insufficient balance");

        // Aún así, seguir CEI pattern es buena práctica
        balances[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");

        emit Withdrawal(msg.sender, balance);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

// ============================================================================
// SOLUCIÓN 3: PULL OVER PUSH PATTERN
// ============================================================================

/**
 * @title PullPaymentVault
 * @notice ✅ Vault usando patrón "Pull over Push"
 * @dev En vez de ENVIAR fondos (push), los usuarios los RETIRAN (pull)
 *
 * VENTAJAS:
 * - Elimina muchos vectores de reentrancy
 * - Aísla cada transferencia
 * - Fallo en una transferencia no afecta otras
 *
 * DESVENTAJAS:
 * - Peor UX (requiere transacción adicional)
 * - Mayor costo total de gas para usuarios
 * - No siempre aplicable a todos los casos de uso
 */
contract PullPaymentVault {

    mapping(address => uint256) public balances;
    mapping(address => uint256) public pendingWithdrawals; // ⭐ SEPARADO

    event Deposit(address indexed user, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 amount);
    event WithdrawalCompleted(address indexed user, uint256 amount);

    function deposit() public payable {
        require(msg.value > 0, "Must deposit something");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice PASO 1: Solicitar withdrawal (actualizar estado)
     * @dev Esta función NO envía ETH, solo actualiza accounting
     *      No hay external call = no hay reentrancy posible
     */
    function requestWithdrawal(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        pendingWithdrawals[msg.sender] += amount;

        emit WithdrawalRequested(msg.sender, amount);
    }

    /**
     * @notice PASO 2: Completar withdrawal (transferir fondos)
     * @dev ✅ SEGURO porque:
     *      1. Solo envía lo que está en pendingWithdrawals
     *      2. pendingWithdrawals se limpia ANTES del envío (CEI)
     *      3. Aunque haya reentrancy, pendingWithdrawals ya es 0
     */
    function completeWithdrawal() public {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawal");

        // EFFECTS: Limpiar ANTES de enviar
        pendingWithdrawals[msg.sender] = 0;

        // INTERACTIONS: Enviar al final
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit WithdrawalCompleted(msg.sender, amount);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

// ============================================================================
// COMPARACIÓN: Los 3 patrones lado a lado
// ============================================================================

/**
 * @title ComparisonDemo
 * @notice Demuestra que los 3 patrones previenen reentrancy exitosamente
 */
contract ComparisonDemo {

    CEIVault public ceiVault;
    GuardedVault public guardedVault;
    PullPaymentVault public pullVault;

    event SetupComplete(address cei, address guarded, address pull);

    function setup() public {
        ceiVault = new CEIVault();
        guardedVault = new GuardedVault();
        pullVault = new PullPaymentVault();

        emit SetupComplete(
            address(ceiVault),
            address(guardedVault),
            address(pullVault)
        );
    }

    /**
     * @notice Probar que todos los vaults son seguros
     * @dev Intentar atacar cada uno - todos deberían resistir
     */
    function testAttacks() public payable {
        require(msg.value >= 3 ether, "Need 3 ETH to test");

        // Depositar en cada vault
        ceiVault.deposit{value: 1 ether}();
        guardedVault.deposit{value: 1 ether}();
        pullVault.deposit{value: 1 ether}();

        // TODO: Desplegar atacantes y verificar que fallan
    }

    receive() external payable {}
}

/**
 * ============================================================================
 * RESUMEN DE SOLUCIONES
 * ============================================================================
 *
 * | Patrón           | Gas Overhead | Facilidad de Uso | Protección        |
 * |------------------|--------------|------------------|-------------------|
 * | CEI Pattern      | 0            | ⚠️ Manual         | ✅ Si se aplica   |
 * | ReentrancyGuard  | ~2,500 gas   | ✅ Fácil          | ✅ Si se aplica   |
 * | Pull Payment     | Extra TX     | ⚠️ Peor UX        | ✅ Si se aplica   |
 *
 * PROBLEMA FUNDAMENTAL:
 * - Todos son MANUALES: El desarrollador debe RECORDAR aplicarlos
 * - Compilador NO fuerza estas protecciones
 * - Un olvido = vulnerabilidad crítica
 * - Code reviews pueden pasar por alto
 *
 * CONTRASTE CON CADENCE:
 * - En Cadence, Resources hacen reentrancy IMPOSIBLE por diseño
 * - No necesitas recordar nada
 * - El compilador te protege automáticamente
 * - Zero overhead de gas
 * - Ver: ../cadence/solucion.cdc para la implementación
 *
 * ============================================================================
 */
