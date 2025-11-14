// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../workaround.sol";

contract OverflowProtectionTest is Test {
    Solidity8Token public token8;
    OptimizedToken public tokenOpt;
    
    function setUp() public {
        token8 = new Solidity8Token();
        tokenOpt = new OptimizedToken();
    }
    
    function test_Solidity8_PreventsOverflow() public {
        vm.expectRevert();
        token8.batchTransfer(new address[](2), 2**255);
    }
    
    function test_UncheckedOptimization() public {
        tokenOpt.efficientLoop(100);
    }
}
