# NFT Standards en EVM

## 📋 Contenido

Este directorio contiene implementaciones de NFTs en EVM mostrando:

1. **problema.sol** - Código vulnerable (ERC-721 con reentrancy)
2. **workaround.sol** - Soluciones modernas (ERC-721A, ERC-1155, marketplace seguro)
3. **test/** - Tests completos con Foundry

---

## 🔴 Problemas Fundamentales

### 1. ERC-721: Alto Costo de Gas

**El problema original**:
```solidity
// Storage por cada NFT
mapping(uint256 => address) private _owners;
mapping(address => uint256) private _balances;

function _safeMint(address to, uint256 tokenId) internal {
    _owners[tokenId] = to;        // 20,000 gas (SSTORE)
    _balances[to] += 1;           // 5,000 gas
    // ... más operaciones
}
```

**Costos reales**:
- Mintear 1 NFT: ~113,000 gas
- Mintear 5 NFTs: ~566,000 gas (113k × 5)
- Mintear 100 NFTs: ~11,300,000 gas ≈ $226 USD (gas a 50 gwei, ETH a $2000)

### 2. Vulnerabilidad: safeMint Reentrancy

**Código vulnerable**:
```solidity
function mint() external payable {
    require(!hasMinted[msg.sender], "Already minted");

    uint256 newTokenId = currentTokenId++;

    // ⚠️ VULNERABLE: External call BEFORE state update
    _safeMint(msg.sender, newTokenId);

    // ❌ TOO LATE: Attacker already re-entered
    hasMinted[msg.sender] = true;
}
```

**Cómo funciona el ataque**:
1. Attacker llama `mint()` pagando 0.1 ETH
2. `_safeMint()` llama a `onERC721Received()` en el attacker
3. Attacker re-entra a `mint()` **sin pagar** (hasMinted aún es false)
4. Repite el proceso 5 veces
5. Resultado: 5 NFTs por el precio de 1

**Hack real**: The Idols NFT (2024) - $340,000 robados

### 3. Marketplace Reentrancy (NFT Trader Hack)

**Código vulnerable**:
```solidity
function acceptOffer(uint256 offerId) external payable {
    Offer memory offer = offers[offerId];
    require(offer.active, "Offer not active");

    // ⚠️ VULNERABLE: External call BEFORE state update
    IERC721(offer.nftContract).safeTransferFrom(
        address(this),
        msg.sender,
        offer.tokenId
    );

    payable(offer.seller).transfer(msg.value);

    // ❌ TOO LATE: Attacker already accepted the same offer again
    delete offers[offerId];
}
```

**Hack real**: NFT Trader (Dec 2023) - **$3,000,000 robados**

### 4. No Batch Operations Nativas

ERC-721 no tiene operaciones batch:
```solidity
// ❌ No existe en ERC-721
function batchTransferFrom(address[] to, uint256[] tokenIds) external;

// Solución manual: Loop costoso
for (uint256 i = 0; i < tokenIds.length; i++) {
    safeTransferFrom(from, to[i], tokenIds[i]);  // ~113k gas cada uno
}
```

---

## ✅ Soluciones EVM

### Solución 1: ERC-721A (Azuki)

**Innovación principal**: Almacenar ownership una vez por batch

```solidity
// Antes (ERC-721): Storage por cada NFT
_owners[0] = alice;  // 20k gas
_owners[1] = alice;  // 20k gas
_owners[2] = alice;  // 20k gas

// Después (ERC-721A): Storage UNA VEZ
_owners[0] = alice;  // 20k gas
// Los demás IDs infieren ownership de alice
```

**Gas savings**:
| Operación | ERC-721 | ERC-721A | Ahorro |
|-----------|---------|----------|--------|
| Mint 1 NFT | 113k gas | 50k gas | 56% |
| Mint 5 NFTs | 566k gas | 104k gas | **82%** |
| Mint 10 NFTs | 1,130k gas | 120k gas | **89%** |

**Limitaciones**:
- ⚠️ Más complejo de implementar correctamente
- ⚠️ Requiere auditoría profesional
- ⚠️ No elimina reentrancy (necesita `nonReentrant`)
- ⚠️ No tiene batch transfer nativo

**Uso en producción**:
- Azuki: $1.5B+ en volumen
- Otherside: Yuga Labs
- Moonbirds

### Solución 2: ERC-1155 (Multi-Token Standard)

**Innovación**: Un contrato para NFTs Y tokens fungibles

```solidity
// Un mapping para todo
mapping(uint256 => mapping(address => uint256)) private _balances;

// NFT: balance = 1
_balances[tokenId][owner] = 1;

// Fungible token: balance = N
_balances[fungibleTokenId][owner] = 1000;
```

**Ventajas**:
- ✅ Batch operations nativas (`safeBatchTransferFrom`)
- ✅ Gas eficiente: ~90k gas para 5 NFTs
- ✅ Soporta fungibles + NFTs en un contrato

**Gas comparison (batch mint 5 NFTs)**:
| Standard | Gas Used | vs ERC-721 |
|----------|----------|------------|
| ERC-721 | 566k gas | Baseline |
| ERC-721A | 104k gas | -82% |
| ERC-1155 | ~90k gas | **-84%** |

**Limitaciones**:
- ⚠️ Menos compatible con marketplaces existentes (OpenSea, LooksRare)
- ⚠️ Lógica más compleja para NFTs únicos
- ⚠️ Metadata management más difícil

**Uso en producción**:
- Gaming items (Enjin, Horizon)
- Membership tokens
- Multi-class NFT collections

### Solución 3: Protección contra Reentrancy

**Pattern: Checks-Effects-Interactions**

```solidity
function mint(uint256 quantity) external payable nonReentrant {
    // 1. CHECKS: Validaciones
    require(msg.value == PRICE * quantity, "Incorrect payment");
    require(!hasMinted[msg.sender], "Already minted");

    // 2. EFFECTS: Actualizar estado ANTES de external calls
    hasMinted[msg.sender] = true;

    // 3. INTERACTIONS: External calls al final
    _safeMint(msg.sender, quantity);
}
```

**Marketplace seguro**:
```solidity
function acceptOffer(uint256 offerId) external payable nonReentrant {
    Offer storage offer = offers[offerId];

    // CHECKS
    require(offer.active, "Offer not active");
    require(msg.value == offer.price, "Incorrect payment");

    // EFFECTS: Update BEFORE external call
    offer.active = false;  // ✅ Now protected

    // INTERACTIONS
    IERC721(offer.nftContract).safeTransferFrom(...);
    payable(offer.seller).transfer(msg.value);
}
```

**Costo de seguridad**:
- `nonReentrant` modifier: +2,500 gas por transacción
- Pequeño precio por prevenir hacks de millones

---

## 🎯 EIP-998: Composable NFTs

**Problema**: NFTs que contienen otros NFTs

**Ejemplos de uso**:
- Gaming: Character + Equipped Items
- Real Estate: Building + Furniture
- Art: Collection bundles

**Status**:
- 📝 **Draft desde 2018** (7 años)
- ⚠️ Muy poca adopción (demasiado complejo)
- ⚠️ Gas costs prohibitivos
- ⚠️ No hay standard de facto

**Complejidad en Solidity**:
```solidity
interface IERC998 {
    function safeTransferChild(
        uint256 fromTokenId,
        address to,
        address childContract,
        uint256 childTokenId
    ) external;

    // Tracking de children es complejo y costoso
    mapping(uint256 => mapping(address => uint256[])) internal childTokens;
}
```

**Resultado**: Muy pocos proyectos lo usan en producción

---

## 📊 Comparación de Soluciones

| Feature | ERC-721 | ERC-721A | ERC-1155 |
|---------|---------|----------|----------|
| Gas (1 NFT) | 113k | 50k | 45k |
| Gas (5 NFTs) | 566k | 104k | 90k |
| Batch transfer | ❌ | ❌ | ✅ |
| Composable | ❌ | ❌ | ❌ |
| Marketplace support | ✅ | ✅ | ⚠️ |
| Implementation complexity | Medium | High | High |
| Reentrancy risk | ⚠️ | ⚠️ | ⚠️ |

**Nota**: Todas las soluciones EVM requieren:
- Careful implementation (reentrancy guards)
- Professional audits
- Constant vigilance para nuevos attack vectors

---

## 🧪 Tests

Ver `test/NFTVulnerabilities.t.sol` para tests completos.

**Tests incluidos**:
1. ✅ Reentrancy attack demonstration
2. ✅ Marketplace vulnerability
3. ✅ Gas comparisons (ERC-721 vs ERC-721A vs ERC-1155)
4. ✅ Security validations

**Ejecutar tests**:
```bash
forge test -vv
forge test --gas-report  # Ver comparación de gas
```

---

## 📚 Referencias

### Hacks Reales
- [NFT Trader Hack Postmortem](https://nfttrader.io/blog/post-mortem) - $3M stolen
- [The Idols NFT Bug](https://twitter.com/The_Idols_NFT) - $340K stolen

### EIPs
- [EIP-721: NFT Standard](https://eips.ethereum.org/EIPS/eip-721)
- [EIP-1155: Multi Token Standard](https://eips.ethereum.org/EIPS/eip-1155)
- [EIP-998: Composable NFTs](https://eips.ethereum.org/EIPS/eip-998) (Draft)

### Implementaciones
- [OpenZeppelin ERC-721](https://docs.openzeppelin.com/contracts/5.x/erc721)
- [ERC721A by Azuki](https://www.erc721a.org/)
- [OpenZeppelin ERC-1155](https://docs.openzeppelin.com/contracts/5.x/erc1155)

### Security
- [SWC-107: Reentrancy](https://swcregistry.io/docs/SWC-107)
- [Consensys Best Practices](https://consensys.github.io/smart-contract-best-practices/)
