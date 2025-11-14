// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;  // ✅ 0.8+ = Protegido por defecto

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * SOLUCIÓN 1: SafeMath (para Solidity <0.8)
 */
contract SafeMathToken {
    using SafeMath for uint256;
    
    mapping(address => uint256) public balances;
    
    constructor() {
        balances[msg.sender] = 1000000 * 10**18;
    }
    
    function batchTransfer(address[] memory _receivers, uint256 _value) public returns (bool) {
        uint cnt = _receivers.length;
        uint256 amount = uint256(cnt).mul(_value);  // ✅ SafeMath previene overflow
        
        require(balances[msg.sender] >= amount);
        
        balances[msg.sender] = balances[msg.sender].sub(amount);
        
        for (uint i = 0; i < cnt; i++) {
            balances[_receivers[i]] = balances[_receivers[i]].add(_value);
        }
        
        return true;
    }
}

/**
 * SOLUCIÓN 2: Solidity 0.8+ Built-in Checks
 */
contract Solidity8Token {
    mapping(address => uint256) public balances;
    
    constructor() {
        balances[msg.sender] = 1000000 * 10**18;
    }
    
    function batchTransfer(address[] memory _receivers, uint256 _value) public returns (bool) {
        uint cnt = _receivers.length;
        uint256 amount = uint256(cnt) * _value;  // ✅ Revierte automáticamente si overflow
        
        require(balances[msg.sender] >= amount);
        
        balances[msg.sender] = balances[msg.sender] - amount;  // ✅ Revierte si underflow
        
        for (uint i = 0; i < cnt; i++) {
            balances[_receivers[i]] = balances[_receivers[i]] + _value;
        }
        
        return true;
    }
}

/**
 * SOLUCIÓN 3: unchecked{} para optimización cuando es seguro
 */
contract OptimizedToken {
    mapping(address => uint256) public balances;
    
    constructor() {
        balances[msg.sender] = 1000000 * 10**18;
    }
    
    function efficientLoop(uint256 n) public {
        uint256 sum = 0;
        
        for (uint256 i = 0; i < n; ) {
            sum += i;  // Checked
            
            unchecked {
                i++;  // ✅ Sabemos que i < n, no puede overflow
            }
        }
    }
}
