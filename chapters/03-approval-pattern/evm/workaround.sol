// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ERC20 Approval Solutions
 * @notice Implementa 3 soluciones modernas al problema de approvals
 *
 * SOLUCIONES:
 * 1. increaseAllowance/decreaseAllowance (OpenZeppelin)
 * 2. EIP-2612 Permit (gasless approvals)
 * 3. Permit2-style (expirable approvals con witness data)
 */

// ═══════════════════════════════════════════════════════════════════════
// SOLUCIÓN 1: OpenZeppelin increaseAllowance/decreaseAllowance
// ═══════════════════════════════════════════════════════════════════════

contract SaferERC20 {
    string public name = "Safer Token";
    string public symbol = "SAFE";
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

    // Approve tradicional (todavía existe por compatibilidad)
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // ✅ SOLUCIÓN: increaseAllowance previene race condition
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        uint256 newAllowance = allowance[msg.sender][spender] + addedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
        return true;
    }

    // ✅ SOLUCIÓN: decreaseAllowance es más seguro que approve(spender, 0)
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = allowance[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "Decreased below zero");
        uint256 newAllowance = currentAllowance - subtractedValue;
        allowance[msg.sender][spender] = newAllowance;
        emit Approval(msg.sender, spender, newAllowance);
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
// SOLUCIÓN 2: EIP-2612 Permit (Gasless Approvals)
// ═══════════════════════════════════════════════════════════════════════

contract PermitToken {
    string public name = "Permit Token";
    string public symbol = "PRMT";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;

        // EIP-712 domain separator
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // ✅ SOLUCIÓN: EIP-2612 Permit
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline)
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address signer = ecrecover(hash, v, r, s);

        require(signer == owner, "Invalid signature");
        require(signer != address(0), "Invalid signer");

        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
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
// SOLUCIÓN 3: Permit2-Style (Expirable Approvals + Witness)
// ═══════════════════════════════════════════════════════════════════════

contract Permit2StyleToken {
    string public name = "Permit2 Style Token";
    string public symbol = "P2T";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public nonces;

    // ⭐ Nueva estructura: Approvals con expiry
    struct Approval {
        uint160 amount;
        uint48 expiration;  // Auto-expira!
    }

    mapping(address => mapping(address => Approval)) public approvals;

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TRANSFER_TYPEHASH =
        keccak256("PermitTransfer(address token,address from,address to,uint256 amount,uint256 nonce,uint256 deadline)");

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint160 value, uint48 expiration);

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // ✅ SOLUCIÓN: Approve con expiry automático
    function approve(address spender, uint160 amount, uint48 expiration) external returns (bool) {
        require(expiration > block.timestamp, "Expiration in the past");

        approvals[msg.sender][spender] = Approval({
            amount: amount,
            expiration: expiration
        });

        emit Approval(msg.sender, spender, amount, expiration);
        return true;
    }

    // ✅ SOLUCIÓN: TransferFrom con validación de expiry
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        Approval memory approval = approvals[from][msg.sender];

        require(balanceOf[from] >= amount, "Insufficient balance");
        require(approval.amount >= amount, "Insufficient allowance");
        require(approval.expiration > block.timestamp, "Approval expired");

        // Update approval
        approvals[from][msg.sender].amount = uint160(approval.amount - amount);

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    // ✅ SOLUCIÓN: Permit con deadline para transfer directo
    function permitTransfer(
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Permit expired");

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TRANSFER_TYPEHASH,
                address(this),
                from,
                to,
                amount,
                nonces[from]++,
                deadline
            )
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address signer = ecrecover(hash, v, r, s);

        require(signer == from, "Invalid signature");
        require(signer != address(0), "Invalid signer");
        require(balanceOf[from] >= amount, "Insufficient balance");

        // Transfer directo, sin allowance
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    // ✅ Helper: Revocar approval manualmente
    function revokeApproval(address spender) external {
        delete approvals[msg.sender][spender];
        emit Approval(msg.sender, spender, 0, 0);
    }

    // ✅ Helper: Verificar si approval expiró
    function isApprovalValid(address owner, address spender) external view returns (bool) {
        Approval memory approval = approvals[owner][spender];
        return approval.amount > 0 && approval.expiration > block.timestamp;
    }
}

// ═══════════════════════════════════════════════════════════════════════
// DEX Seguro que usa Permit
// ═══════════════════════════════════════════════════════════════════════

contract SafeDEX {
    PermitToken public token;

    constructor(address _token) {
        token = PermitToken(_token);
    }

    // ✅ SOLUCIÓN: Swap usando permit (1 transacción!)
    function swapWithPermit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Usuario firma permit off-chain
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);

        // Ahora puede usar transferFrom
        token.transferFrom(msg.sender, address(this), amount);

        // Simula swap (1:1 para simplicidad)
        token.transfer(msg.sender, amount);
    }
}

// ═══════════════════════════════════════════════════════════════════════
// Bridge Seguro (resuelve Li.Fi vulnerability)
// ═══════════════════════════════════════════════════════════════════════

contract SecureBridge {
    // Whitelist de tokens permitidos
    mapping(address => bool) public allowedTokens;
    // Whitelist de targets permitidos
    mapping(address => bool) public allowedTargets;

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function addAllowedToken(address token) external onlyOwner {
        allowedTokens[token] = true;
    }

    function addAllowedTarget(address target) external onlyOwner {
        allowedTargets[target] = true;
    }

    // ✅ SOLUCIÓN: Valida target antes de call
    function bridgeAndSwap(
        address token,
        address target,
        bytes calldata data
    ) external {
        require(allowedTokens[token], "Token not allowed");
        require(allowedTargets[target], "Target not allowed");

        // ✅ Ahora es seguro hacer el call
        (bool success, ) = target.call(data);
        require(success, "Call failed");
    }
}
