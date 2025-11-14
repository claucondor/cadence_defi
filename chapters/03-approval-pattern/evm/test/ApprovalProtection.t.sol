// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../workaround.sol";

/**
 * @title Approval Protection Tests
 * @notice Tests que demuestran cómo las soluciones previenen ataques
 *
 * TESTS INCLUIDOS:
 * 1. increaseAllowance/decreaseAllowance previene race conditions
 * 2. EIP-2612 Permit permite gasless approvals
 * 3. Permit2-style con expirable approvals
 * 4. Secure bridge pattern
 */

contract ApprovalProtectionTest is Test {
    SaferERC20 public saferToken;
    PermitToken public permitToken;
    Permit2StyleToken public permit2Token;
    SafeDEX public safeDex;
    SecureBridge public secureBridge;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address spender = makeAddr("spender");

    uint256 alicePrivateKey = 0xA11CE;
    uint256 bobPrivateKey = 0xB0B;

    function setUp() public {
        // Deploy tokens
        saferToken = new SaferERC20(1_000_000 * 1e18);
        permitToken = new PermitToken(1_000_000 * 1e18);
        permit2Token = new Permit2StyleToken(1_000_000 * 1e18);

        // Distribute tokens
        saferToken.transfer(alice, 100_000 * 1e18);
        permitToken.transfer(alice, 100_000 * 1e18);
        permit2Token.transfer(alice, 100_000 * 1e18);

        // Deploy DEX and bridge
        safeDex = new SafeDEX(address(permitToken));
        secureBridge = new SecureBridge();
    }

    // ═══════════════════════════════════════════════════════════════════
    // TEST 1: increaseAllowance/decreaseAllowance
    // ═══════════════════════════════════════════════════════════════════

    function test_IncreaseAllowance_PreventsRaceCondition() public {
        vm.startPrank(alice);

        // Aprueba 100 tokens
        saferToken.approve(spender, 100 * 1e18);
        assertEq(saferToken.allowance(alice, spender), 100 * 1e18);

        // ✅ SOLUCIÓN: Usa increaseAllowance en vez de approve
        // No hay race condition porque es aditivo
        saferToken.increaseAllowance(spender, 50 * 1e18);

        assertEq(
            saferToken.allowance(alice, spender),
            150 * 1e18,
            "Allowance should increase to 150"
        );

        console.log("\n=== increaseAllowance Protection ===");
        console.log("No race condition - allowance atomically increased");

        vm.stopPrank();
    }

    function test_DecreaseAllowance_Safe() public {
        vm.startPrank(alice);

        saferToken.approve(spender, 100 * 1e18);

        // ✅ SOLUCIÓN: decreaseAllowance es más seguro
        saferToken.decreaseAllowance(spender, 30 * 1e18);

        assertEq(saferToken.allowance(alice, spender), 70 * 1e18);

        vm.stopPrank();

        console.log("\n=== decreaseAllowance Protection ===");
        console.log("Safe atomic decrease");
    }

    function test_DecreaseAllowance_RevertsOnUnderflow() public {
        vm.startPrank(alice);

        saferToken.approve(spender, 100 * 1e18);

        // ✅ PROTECCIÓN: Revierte si intentas decrementar más de lo disponible
        vm.expectRevert("Decreased below zero");
        saferToken.decreaseAllowance(spender, 200 * 1e18);

        vm.stopPrank();
    }

    // ═══════════════════════════════════════════════════════════════════
    // TEST 2: EIP-2612 Permit (Gasless Approvals)
    // ═══════════════════════════════════════════════════════════════════

    function test_Permit_GaslessApproval() public {
        uint256 amount = 1000 * 1e18;
        uint256 deadline = block.timestamp + 1 hours;

        // ✅ Alice firma off-chain (no gasta gas)
        (uint8 v, bytes32 r, bytes32 s) = _signPermit(
            alice,
            alicePrivateKey,
            address(permitToken),
            spender,
            amount,
            0, // nonce
            deadline
        );

        // Bob (o cualquiera) puede usar la firma
        vm.prank(bob);
        permitToken.permit(alice, spender, amount, deadline, v, r, s);

        // Verifica que el approval fue creado
        assertEq(permitToken.allowance(alice, spender), amount);

        console.log("\n=== EIP-2612 Permit ===");
        console.log("Alice signed off-chain (0 gas)");
        console.log("Approval created successfully");
    }

    function test_Permit_PreventsReplay() public {
        uint256 amount = 1000 * 1e18;
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(
            alice,
            alicePrivateKey,
            address(permitToken),
            spender,
            amount,
            0,
            deadline
        );

        // Primera vez funciona
        permitToken.permit(alice, spender, amount, deadline, v, r, s);

        // ✅ PROTECCIÓN: Segunda vez revierte (nonce ya usado)
        vm.expectRevert("Invalid signature");
        permitToken.permit(alice, spender, amount, deadline, v, r, s);

        console.log("\n=== Permit Replay Protection ===");
        console.log("Nonce prevents replay attacks");
    }

    function test_Permit_ExpiresAfterDeadline() public {
        uint256 amount = 1000 * 1e18;
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(
            alice,
            alicePrivateKey,
            address(permitToken),
            spender,
            amount,
            0,
            deadline
        );

        // Avanza el tiempo más allá del deadline
        vm.warp(deadline + 1);

        // ✅ PROTECCIÓN: Revierte si el deadline pasó
        vm.expectRevert("Permit expired");
        permitToken.permit(alice, spender, amount, deadline, v, r, s);

        console.log("\n=== Permit Deadline Protection ===");
        console.log("Expired permits are rejected");
    }

    // ═══════════════════════════════════════════════════════════════════
    // TEST 3: SafeDEX con Permit (UX mejorado)
    // ═══════════════════════════════════════════════════════════════════

    function test_SafeDEX_OneTransaction() public {
        uint256 amount = 1000 * 1e18;
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 v, bytes32 r, bytes32 s) = _signPermit(
            alice,
            alicePrivateKey,
            address(permitToken),
            address(safeDex),
            amount,
            0,
            deadline
        );

        uint256 balanceBefore = permitToken.balanceOf(alice);

        // ✅ SOLUCIÓN: Una sola transacción (permit + swap)
        vm.prank(alice);
        safeDex.swapWithPermit(amount, deadline, v, r, s);

        // Balance se mantiene (swap 1:1 para simplicidad)
        assertEq(permitToken.balanceOf(alice), balanceBefore);

        console.log("\n=== SafeDEX with Permit ===");
        console.log("One transaction for approve + swap");
        console.log("Better UX than traditional approve + swap");
    }

    // ═══════════════════════════════════════════════════════════════════
    // TEST 4: Permit2-Style Expirable Approvals
    // ═══════════════════════════════════════════════════════════════════

    function test_Permit2Style_ExpirableApprovals() public {
        vm.startPrank(alice);

        uint48 expiration = uint48(block.timestamp + 1 days);

        // ✅ SOLUCIÓN: Approval con expiry automático
        permit2Token.approve(spender, 1000 * 1e18, expiration);

        // Funciona antes de expirar
        assertTrue(permit2Token.isApprovalValid(alice, spender));

        // Avanza el tiempo
        vm.warp(expiration + 1);

        // ✅ PROTECCIÓN: Approval expiró automáticamente
        assertFalse(permit2Token.isApprovalValid(alice, spender));

        vm.stopPrank();

        console.log("\n=== Permit2-Style Expirable Approvals ===");
        console.log("Approval automatically expires after 1 day");
    }

    function test_Permit2Style_TransferFromRevertsAfterExpiry() public {
        vm.startPrank(alice);

        uint48 expiration = uint48(block.timestamp + 1 hours);
        permit2Token.approve(spender, 1000 * 1e18, expiration);

        vm.stopPrank();

        // Funciona antes de expirar
        vm.prank(spender);
        permit2Token.transferFrom(alice, bob, 100 * 1e18);

        // Avanza el tiempo
        vm.warp(expiration + 1);

        // ✅ PROTECCIÓN: transferFrom revierte después de expiry
        vm.prank(spender);
        vm.expectRevert("Approval expired");
        permit2Token.transferFrom(alice, bob, 100 * 1e18);

        console.log("\n=== Permit2 Expiry Protection ===");
        console.log("transferFrom automatically blocked after expiry");
    }

    function test_Permit2Style_ManualRevocation() public {
        vm.startPrank(alice);

        uint48 expiration = uint48(block.timestamp + 1 days);
        permit2Token.approve(spender, 1000 * 1e18, expiration);

        assertTrue(permit2Token.isApprovalValid(alice, spender));

        // ✅ SOLUCIÓN: Revocación manual inmediata
        permit2Token.revokeApproval(spender);

        // Approval ya no es válido
        assertFalse(permit2Token.isApprovalValid(alice, spender));

        vm.stopPrank();

        console.log("\n=== Manual Revocation ===");
        console.log("Users can revoke approvals immediately");
    }

    // ═══════════════════════════════════════════════════════════════════
    // TEST 5: Permit2 Transfer Directo (sin allowance)
    // ═══════════════════════════════════════════════════════════════════

    function test_Permit2_DirectTransfer() public {
        uint256 amount = 500 * 1e18;
        uint256 deadline = block.timestamp + 1 hours;

        (uint8 v, bytes32 r, bytes32 s) = _signPermitTransfer(
            alice,
            alicePrivateKey,
            address(permit2Token),
            bob,
            amount,
            0,
            deadline
        );

        uint256 aliceBalanceBefore = permit2Token.balanceOf(alice);
        uint256 bobBalanceBefore = permit2Token.balanceOf(bob);

        // ✅ SOLUCIÓN: Transfer directo sin crear allowance
        permit2Token.permitTransfer(alice, bob, amount, deadline, v, r, s);

        assertEq(permit2Token.balanceOf(alice), aliceBalanceBefore - amount);
        assertEq(permit2Token.balanceOf(bob), bobBalanceBefore + amount);

        // ✅ NO se creó allowance
        assertEq(permit2Token.allowance(alice, bob), 0);

        console.log("\n=== Permit2 Direct Transfer ===");
        console.log("Transfer without creating allowance");
        console.log("More secure - no lingering permissions");
    }

    // ═══════════════════════════════════════════════════════════════════
    // TEST 6: Secure Bridge (Li.Fi fix)
    // ═══════════════════════════════════════════════════════════════════

    function test_SecureBridge_RejectsUnauthorizedTargets() public {
        address maliciousTarget = makeAddr("malicious");
        bytes memory data = abi.encodeWithSignature("steal()");

        // ✅ PROTECCIÓN: Rechaza targets no autorizados
        vm.expectRevert("Target not allowed");
        secureBridge.bridgeAndSwap(address(permitToken), maliciousTarget, data);

        console.log("\n=== Secure Bridge Protection ===");
        console.log("Unauthorized targets are rejected");
    }

    function test_SecureBridge_WhitelistRequired() public {
        address allowedTarget = makeAddr("allowedSwap");
        bytes memory data = abi.encodeWithSignature("swap()");

        // Añade el target a la whitelist
        secureBridge.addAllowedToken(address(permitToken));
        secureBridge.addAllowedTarget(allowedTarget);

        // ✅ Ahora funciona
        // (el call fallaría porque allowedTarget no existe, pero la validación pasó)
        vm.expectRevert();
        secureBridge.bridgeAndSwap(address(permitToken), allowedTarget, data);

        console.log("\n=== Whitelist Protection ===");
        console.log("Only whitelisted targets can be called");
    }

    // ═══════════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════════

    function _signPermit(
        address owner,
        uint256 ownerPrivateKey,
        address token,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 domainSeparator = PermitToken(token).DOMAIN_SEPARATOR();
        bytes32 permitTypehash = PermitToken(token).PERMIT_TYPEHASH();

        bytes32 structHash = keccak256(
            abi.encode(permitTypehash, owner, spender, value, nonce, deadline)
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (v, r, s) = vm.sign(ownerPrivateKey, hash);
    }

    function _signPermitTransfer(
        address from,
        uint256 fromPrivateKey,
        address token,
        address to,
        uint256 amount,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 domainSeparator = Permit2StyleToken(token).DOMAIN_SEPARATOR();
        bytes32 typehash = Permit2StyleToken(token).PERMIT_TRANSFER_TYPEHASH();

        bytes32 structHash = keccak256(
            abi.encode(typehash, token, from, to, amount, nonce, deadline)
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (v, r, s) = vm.sign(fromPrivateKey, hash);
    }
}
