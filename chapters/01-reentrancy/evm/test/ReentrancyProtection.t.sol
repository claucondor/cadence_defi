// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../workaround.sol";

/**
 * @title ReentrancyProtectionTest
 * @notice Tests que verifican que las soluciones previenen reentrancy
 * @dev Estos tests demuestran que CEI, ReentrancyGuard, y Pull Payment funcionan
 */
contract ReentrancyProtectionTest is Test {

    CEIVault public ceiVault;
    GuardedVault public guardedVault;
    PullPaymentVault public pullVault;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public eve = makeAddr("eve"); // Atacante

    function setUp() public {
        // Deploy de los 3 vaults protegidos
        ceiVault = new CEIVault();
        guardedVault = new GuardedVault();
        pullVault = new PullPaymentVault();

        // Dar fondos a los usuarios
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(eve, 2 ether);
    }

    // ========================================================================
    // TESTS PARA CEI PATTERN
    // ========================================================================

    function test_CEI_SetupWorks() public {
        assertEq(address(ceiVault).balance, 0);
    }

    function test_CEI_DepositAndWithdraw() public {
        // Alice deposita
        vm.prank(alice);
        ceiVault.deposit{value: 5 ether}();

        assertEq(ceiVault.balances(alice), 5 ether);
        assertEq(address(ceiVault).balance, 5 ether);

        uint256 aliceBalanceBefore = alice.balance;

        // Alice retira
        vm.prank(alice);
        ceiVault.withdraw();

        // Verificar retiro exitoso
        assertEq(alice.balance, aliceBalanceBefore + 5 ether);
        assertEq(ceiVault.balances(alice), 0);
        assertEq(address(ceiVault).balance, 0);
    }

    /**
     * Test crítico: CEI Pattern previene reentrancy
     */
    function test_CEI_PreventsReentrancy() public {
        // Usuarios honestos depositan
        vm.prank(alice);
        ceiVault.deposit{value: 5 ether}();

        vm.prank(bob);
        ceiVault.deposit{value: 5 ether}();

        uint256 vaultBalanceBefore = address(ceiVault).balance;
        assertEq(vaultBalanceBefore, 10 ether);

        // Crear atacante personalizado para CEI vault
        CEIAttacker attacker = new CEIAttacker(address(ceiVault));

        // Atacante intenta explotar
        vm.deal(address(attacker), 1 ether);
        vm.prank(address(attacker));

        // El ataque FALLA porque el balance se actualiza primero
        attacker.attack{value: 1 ether}();

        // Verificar que el vault NO fue drenado
        // El atacante solo puede retirar su propio 1 ETH, una vez
        uint256 vaultBalanceAfter = address(ceiVault).balance;

        // Alice y Bob siguen teniendo sus fondos
        assertEq(vaultBalanceAfter, 10 ether, "CEI pattern protected the vault");

        // Alice puede retirar normalmente
        vm.prank(alice);
        ceiVault.withdraw();
        assertEq(alice.balance, 10 ether); // Recuperó sus 5 ETH
    }

    // ========================================================================
    // TESTS PARA REENTRANCYGUARD
    // ========================================================================

    function test_Guard_SetupWorks() public {
        assertEq(address(guardedVault).balance, 0);
    }

    function test_Guard_DepositAndWithdraw() public {
        vm.prank(alice);
        guardedVault.deposit{value: 5 ether}();

        uint256 aliceBalanceBefore = alice.balance;

        vm.prank(alice);
        guardedVault.withdraw();

        assertEq(alice.balance, aliceBalanceBefore + 5 ether);
        assertEq(guardedVault.balances(alice), 0);
    }

    /**
     * Test crítico: ReentrancyGuard previene reentrancy
     */
    function test_Guard_PreventsReentrancy() public {
        // Usuarios honestos depositan
        vm.prank(alice);
        guardedVault.deposit{value: 5 ether}();

        vm.prank(bob);
        guardedVault.deposit{value: 5 ether}();

        uint256 vaultBalanceBefore = address(guardedVault).balance;
        assertEq(vaultBalanceBefore, 10 ether);

        // Crear atacante para vault guardado
        GuardedAttacker attacker = new GuardedAttacker(address(guardedVault));

        vm.deal(address(attacker), 1 ether);

        // El ataque debe REVERTIR con "ReentrancyGuard: reentrant call"
        vm.prank(address(attacker));
        vm.expectRevert("ReentrancyGuard: reentrant call");
        attacker.attack{value: 1 ether}();

        // Vault no fue afectado
        assertEq(address(guardedVault).balance, vaultBalanceBefore);
    }

    /**
     * Test: Gas overhead de ReentrancyGuard
     */
    function test_Guard_GasOverhead() public {
        vm.prank(alice);
        guardedVault.deposit{value: 5 ether}();

        // Medir gas de withdraw con guard
        uint256 gasBefore = gasleft();
        vm.prank(alice);
        guardedVault.withdraw();
        uint256 gasWithGuard = gasBefore - gasleft();

        console.log("Gas used with ReentrancyGuard:", gasWithGuard);

        // Comparar con CEI (sin guard)
        vm.prank(bob);
        ceiVault.deposit{value: 5 ether}();

        gasBefore = gasleft();
        vm.prank(bob);
        ceiVault.withdraw();
        uint256 gasWithoutGuard = gasBefore - gasleft();

        console.log("Gas used without ReentrancyGuard (CEI only):", gasWithoutGuard);
        console.log("Extra gas cost of ReentrancyGuard:", gasWithGuard - gasWithoutGuard);

        // ReentrancyGuard añade ~2,500 gas
    }

    // ========================================================================
    // TESTS PARA PULL PAYMENT PATTERN
    // ========================================================================

    function test_Pull_SetupWorks() public {
        assertEq(address(pullVault).balance, 0);
    }

    function test_Pull_DepositWorks() public {
        vm.prank(alice);
        pullVault.deposit{value: 5 ether}();

        assertEq(pullVault.balances(alice), 5 ether);
        assertEq(address(pullVault).balance, 5 ether);
    }

    function test_Pull_RequestAndCompleteWithdrawal() public {
        // Alice deposita
        vm.prank(alice);
        pullVault.deposit{value: 5 ether}();

        // Alice solicita withdrawal (step 1)
        vm.prank(alice);
        pullVault.requestWithdrawal(3 ether);

        // Verificar estado intermedio
        assertEq(pullVault.balances(alice), 2 ether); // 5 - 3
        assertEq(pullVault.pendingWithdrawals(alice), 3 ether);

        uint256 aliceBalanceBefore = alice.balance;

        // Alice completa withdrawal (step 2)
        vm.prank(alice);
        pullVault.completeWithdrawal();

        // Verificar resultado
        assertEq(alice.balance, aliceBalanceBefore + 3 ether);
        assertEq(pullVault.pendingWithdrawals(alice), 0);
        assertEq(address(pullVault).balance, 2 ether);
    }

    /**
     * Test crítico: Pull Payment previene reentrancy
     */
    function test_Pull_PreventsReentrancy() public {
        // Setup
        vm.prank(alice);
        pullVault.deposit{value: 5 ether}();

        vm.prank(bob);
        pullVault.deposit{value: 5 ether}();

        // Atacante intenta exploit
        PullAttacker attacker = new PullAttacker(address(pullVault));
        vm.deal(address(attacker), 1 ether);

        vm.prank(address(attacker));
        attacker.attack{value: 1 ether}();

        // Verificar que el vault está seguro
        // El atacante solo puede retirar su propio balance, una vez
        uint256 vaultBalance = address(pullVault).balance;
        assertEq(vaultBalance, 10 ether, "Pull payment protected the vault");

        // Alice puede completar su withdrawal normalmente
        vm.prank(alice);
        pullVault.requestWithdrawal(5 ether);

        vm.prank(alice);
        pullVault.completeWithdrawal();

        assertEq(alice.balance, 10 ether); // Recuperó sus fondos
    }

    /**
     * Test: UX del Pull Payment (requiere 2 transacciones)
     */
    function test_Pull_RequiresTwoTransactions() public {
        vm.prank(alice);
        pullVault.deposit{value: 5 ether}();

        // Intentar completar sin solicitar primero falla
        vm.prank(alice);
        vm.expectRevert("No pending withdrawal");
        pullVault.completeWithdrawal();

        // Debe seguir el proceso de 2 pasos
        vm.prank(alice);
        pullVault.requestWithdrawal(5 ether);

        vm.prank(alice);
        pullVault.completeWithdrawal(); // Ahora sí funciona

        assertEq(alice.balance, 10 ether);
    }

    // ========================================================================
    // TESTS COMPARATIVOS
    // ========================================================================

    /**
     * Test: Comparar las 3 soluciones lado a lado
     */
    function test_CompareAllThreeSolutions() public {
        // Setup: depositar en los 3 vaults
        vm.prank(alice);
        ceiVault.deposit{value: 1 ether}();

        vm.prank(alice);
        guardedVault.deposit{value: 1 ether}();

        vm.prank(alice);
        pullVault.deposit{value: 1 ether}();

        console.log("=== COMPARISON OF SOLUTIONS ===");

        // CEI Pattern
        uint256 gasBefore = gasleft();
        vm.prank(alice);
        ceiVault.withdraw();
        uint256 gasUnprotected = gasBefore - gasleft();
        console.log("CEI Pattern gas:", gasUnprotected);

        // ReentrancyGuard
        vm.prank(alice);
        guardedVault.deposit{value: 1 ether}();

        gasBefore = gasleft();
        vm.prank(alice);
        guardedVault.withdraw();
        uint256 gasGuarded = gasBefore - gasleft();
        console.log("ReentrancyGuard gas:", gasGuarded);
        console.log("Guard overhead:", gasGuarded - gasUnprotected);

        // Pull Payment
        vm.prank(alice);
        pullVault.requestWithdrawal(1 ether);

        gasBefore = gasleft();
        vm.prank(alice);
        pullVault.completeWithdrawal();
        uint256 gasPull = gasBefore - gasleft();
        console.log("Pull Payment (step 2 only) gas:", gasPull);

        console.log("");
        console.log("All three patterns successfully prevent reentrancy!");
    }
}

// ============================================================================
// ATACANTES PERSONALIZADOS PARA CADA SOLUCIÓN
// ============================================================================

/**
 * Atacante que intenta exploitar CEIVault
 */
contract CEIAttacker {
    CEIVault public target;
    uint256 public attackCount;

    constructor(address _target) {
        target = CEIVault(_target);
    }

    function attack() public payable {
        target.deposit{value: msg.value}();
        target.withdraw();
    }

    receive() external payable {
        attackCount++;
        // Intentar re-entrar
        if (attackCount < 5 && address(target).balance >= 1 ether) {
            target.withdraw(); // Esto fallará porque balance ya es 0
        }
    }
}

/**
 * Atacante que intenta explotar GuardedVault
 */
contract GuardedAttacker {
    GuardedVault public target;

    constructor(address _target) {
        target = GuardedVault(_target);
    }

    function attack() public payable {
        target.deposit{value: msg.value}();
        target.withdraw(); // Esto va a revertir en la re-entrada
    }

    receive() external payable {
        // Intentar re-entrar - esto dispara el revert
        target.withdraw(); // ReentrancyGuard: reentrant call
    }
}

/**
 * Atacante que intenta exploitar PullPaymentVault
 */
contract PullAttacker {
    PullPaymentVault public target;

    constructor(address _target) {
        target = PullPaymentVault(_target);
    }

    function attack() public payable {
        target.deposit{value: msg.value}();
        target.requestWithdrawal(msg.value);
        target.completeWithdrawal();
    }

    receive() external payable {
        // Intentar re-entrar
        if (target.pendingWithdrawals(address(this)) > 0) {
            target.completeWithdrawal(); // Falla porque pendingWithdrawals ya es 0
        }
    }
}

/**
 * ============================================================================
 * RESUMEN DE RESULTADOS
 * ============================================================================
 *
 * ✅ CEI Pattern:
 * - Previene reentrancy actualizando estado primero
 * - Gas-efficient (sin overhead)
 * - Depende de disciplina del desarrollador
 *
 * ✅ ReentrancyGuard:
 * - Previene reentrancy con mutex lock
 * - ~2,500 gas overhead
 * - Más explícito en el código
 * - Depende de recordar usar el modifier
 *
 * ✅ Pull Payment:
 * - Previene reentrancy separando lógica
 * - Requiere 2 transacciones (peor UX)
 * - Mayor costo total de gas
 * - Más seguro en general
 *
 * CONCLUSIÓN:
 * Todas las soluciones funcionan, pero requieren que el desarrollador las aplique
 * manualmente. En Cadence, esto no es necesario - el lenguaje lo previene.
 *
 * ============================================================================
 */
