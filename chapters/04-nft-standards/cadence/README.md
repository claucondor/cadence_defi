# NFT Standards en Cadence

## 📋 Contenido

Este directorio contiene la implementación NFT en Cadence mostrando:

1. **SecureNFT.cdc** - NFT con Resources y MetadataViews
2. **tests/SecureNFT_test.cdc** - Tests completos
3. **flow.json** - Configuración de Flow CLI

---

## ✅ Ventajas Fundamentales de Cadence

### 1. Resources Eliminan Reentrancy por Diseño

**En EVM (vulnerable)**:
```solidity
function mint() external payable {
    require(!hasMinted[msg.sender], "Already minted");

    // ⚠️ External call con callback
    _safeMint(msg.sender, newTokenId);  // Calls onERC721Received()

    // ❌ Attacker ya re-entró
    hasMinted[msg.sender] = true;
}
```

**En Cadence (seguro por diseño)**:
```cadence
access(all) fun mintNFT(recipient: &{CollectionPublic}) {
    // ✅ Crear Resource directamente
    let nft <- create NFT(...)

    // ✅ Deposit es atómico, SIN callbacks
    recipient.deposit(token: <- nft)

    // ✅ No hay manera de re-entrar
}
```

**Por qué es imposible reentrancy**:
1. ❌ No hay callbacks como `onERC721Received()`
2. ❌ No hay external calls durante operaciones críticas
3. ✅ Resource es movido atómicamente
4. ✅ El compilador garantiza seguridad

**Resultado**: **$3.34M en hacks NFT prevenidos automáticamente**

### 2. True Ownership (No Mappings Centrales)

**EVM (ownership simulado)**:
```solidity
// Central mapping - vulnerable a bugs
mapping(uint256 => address) private _owners;

// "Ownership" es solo un entry en un mapping
_owners[tokenId] = msg.sender;

// Puede ser manipulado por bugs del contrato
```

**Cadence (ownership real)**:
```cadence
// Cada usuario tiene su propia Collection
access(all) resource Collection {
    access(all) var ownedNFTs: @{UInt64: NFT}
}

// NFT almacenado DIRECTAMENTE en account storage
account.storage.save(<-collection, to: /storage/NFTCollection)
```

**Implicaciones**:
| Aspecto | EVM | Cadence |
|---------|-----|---------|
| Ownership | Mapping entry | Resource in storage |
| Can duplicate? | ⚠️ Yes (bugs) | ❌ Impossible (compiler) |
| Can lose? | ⚠️ Yes (bugs) | ❌ Impossible (must destroy) |
| Bug in contract affects? | ✅ All NFTs | ❌ Only contract logic |

### 3. Composable NFTs: Trivial vs Imposible

**EVM (EIP-998: Draft desde 2018)**:
```solidity
// Complejo, costoso, poca adopción
mapping(uint256 => mapping(address => uint256[])) internal childTokens;

function safeTransferChild(...) external {
    // 50+ líneas de código complejo
    // Alto riesgo de bugs
    // Gas costs prohibitivos
}
```

**Cadence (3 líneas de código)**:
```cadence
access(all) resource NFT {
    // ✅ NFT puede contener otros NFTs naturalmente
    access(self) var childNFTs: @{UInt64: NFT}
}

// Agregar child NFT
access(all) fun addChildNFT(_ nft: @NFT) {
    self.childNFTs[nft.id] <-! nft  // ✅ Solo esto!
}
```

**Comparación**:
| Feature | EVM (EIP-998) | Cadence |
|---------|---------------|---------|
| Lines of code | 200+ | 3 |
| Implementation time | Weeks | Minutes |
| Audit complexity | Very High | Low |
| Production use | <1% NFTs | Natural pattern |
| Gas cost overhead | Very High | Minimal |

### 4. No Approval Pattern (Capabilities)

**EVM (dos pasos, vulnerable)**:
```solidity
// Paso 1: Approve
nft.approve(marketplace, tokenId);

// Paso 2: Marketplace toma el NFT
nft.transferFrom(seller, buyer, tokenId);

// Problemas:
// - Infinite approvals risk
// - Front-running attacks
// - Approval revocation bugs
```

**Cadence (Capabilities granulares)**:
```cadence
// Crear Capability específica
let cap = account.capabilities.storage.issue<&Collection>(
    CollectionStoragePath
)

// Capability tiene scope limitado
// - Solo lectura o solo escritura
// - Puede ser revocada
// - Type-safe access control

// No approval pattern necesario
```

### 5. Metadata On-Chain con MetadataViews

**EVM (off-chain por gas costs)**:
```solidity
// 1 KB on-chain = 20M gas ≈ $400 USD
// Por eso casi todos usan IPFS/Arweave

function tokenURI(uint256 tokenId) external view returns (string) {
    return string(abi.encodePacked(baseURI, tokenId.toString()));
    // Returns: "ipfs://QmHash/123"
}
```

**Cadence (on-chain, standardizado)**:
```cadence
// MetadataViews: Standard de Flow (FLIP-0636)
access(all) resource NFT {
    access(all) let name: String
    access(all) let description: String
    access(all) let thumbnail: String
    access(self) let metadata: {String: String}
}

// Metadata stored on-chain, affordable
// Standard interfaces para wallets
```

**Gas costs comparison**:
| Storage | EVM | Cadence |
|---------|-----|---------|
| 1 KB | $400 | Affordable |
| 10 KB | $4,000 | Affordable |
| 100 KB | $40,000 | Affordable |

### 6. Batch Operations: Natural vs Workaround

**EVM**:
```solidity
// ERC-721: No batch nativo, loop manual
for (uint256 i = 0; i < ids.length; i++) {
    safeTransferFrom(from, to[i], ids[i]);
}

// ERC-721A: Batch mint optimizado pero complejo
// ERC-1155: Batch nativo pero diferente standard
```

**Cadence**:
```cadence
// ✅ Batch withdraw: Natural
access(all) fun batchWithdraw(ids: [UInt64]): @[NFT] {
    var nfts: @[NFT] <- []
    for id in ids {
        nfts.append(<- self.withdraw(withdrawID: id))
    }
    return <- nfts
}

// ✅ Batch deposit: Natural
access(all) fun batchDeposit(tokens: @[NFT]) {
    while tokens.length > 0 {
        self.deposit(token: <- tokens.removeFirst())
    }
    destroy tokens
}
```

---

## 🏗️ Arquitectura de SecureNFT

### NFT Resource

```cadence
access(all) resource NFT {
    access(all) let id: UInt64
    access(all) let name: String
    access(all) let description: String
    access(all) let thumbnail: String
    access(self) let metadata: {String: String}

    // ✅ Composable: NFTs can own NFTs
    access(self) var childNFTs: @{UInt64: NFT}
}
```

**Propiedades de Resources**:
1. **Linear Type**: No puede duplicarse
2. **Must Be Handled**: No puede perderse
3. **Owned**: Quien tiene el Resource es el dueño
4. **Composable**: Puede contener otros Resources

### Collection Resource

```cadence
access(all) resource Collection {
    access(all) var ownedNFTs: @{UInt64: NFT}

    access(all) fun withdraw(withdrawID: UInt64): @NFT
    access(all) fun deposit(token: @NFT)
    access(all) fun batchWithdraw(ids: [UInt64]): @[NFT]
    access(all) fun batchDeposit(tokens: @[NFT])
}
```

**Ventajas**:
- Cada usuario tiene su propia Collection
- Isolated state (no shared mappings)
- Natural batch operations
- Type-safe operations

### Minter Resource

```cadence
access(all) resource NFTMinter {
    access(all) fun mintNFT(
        recipient: &{CollectionPublic},
        name: String,
        description: String,
        thumbnail: String,
        metadata: {String: String}
    ): UInt64

    access(all) fun batchMintNFT(
        recipient: &{CollectionPublic},
        count: Int,
        // ...
    ): [UInt64]
}
```

**Seguridad**:
- Solo el owner del Minter puede mintear
- No callbacks peligrosos
- Atomicity garantizada

---

## 🔒 Marketplace Seguro

**EVM (vulnerable)**:
```solidity
function acceptOffer(uint256 offerId) external payable {
    // ⚠️ External call BEFORE state update
    IERC721(nft).safeTransferFrom(...);  // Callback!

    delete offers[offerId];  // Too late
}
```

**Cadence (seguro por diseño)**:
```cadence
access(all) fun purchase(listingID: UInt64): @NFT {
    // 1. Remove listing (state update)
    let listing <- self.listings.remove(key: listingID)!

    // 2. Withdraw NFT (no callback)
    let nft <- listing.withdraw()

    // 3. Return NFT (atomic move)
    return <- nft
}
```

**Por qué es seguro**:
1. ✅ Listing removido antes de transferir
2. ✅ No callbacks durante withdraw
3. ✅ Resource movido atómicamente
4. ✅ Imposible re-entrar

---

## 📊 Comparación Directa

### Reentrancy Protection

| Aspecto | EVM | Cadence |
|---------|-----|---------|
| Protection method | Manual guards | By design |
| Code required | `nonReentrant` modifier | Nothing |
| Gas overhead | +2,500 per tx | 0 |
| Can forget? | ✅ Yes | ❌ Impossible |
| Audit complexity | High | Low |

### Composable NFTs

| Aspecto | EVM (EIP-998) | Cadence |
|---------|---------------|---------|
| Standard status | Draft (7 years) | Natural pattern |
| Implementation | 200+ LOC | 3 LOC |
| Gas cost | Prohibitive | Minimal |
| Production use | <1% | Common |
| Audit needs | Critical | Standard |

### Gas Efficiency

**Mint comparison (5 NFTs)**:
| Platform | Gas | Notes |
|----------|-----|-------|
| EVM (ERC-721) | 566k | Standard |
| EVM (ERC-721A) | 104k | Heavily optimized |
| EVM (ERC-1155) | 90k | Different standard |
| Cadence | Efficient | Natural efficiency |

---

## 🧪 Tests

Ver `tests/SecureNFT_test.cdc` para tests completos.

**Tests incluidos**:
1. ✅ Setup collections
2. ✅ Mint single NFT
3. ✅ Batch mint (eficiencia)
4. ✅ Transfer with true ownership
5. ✅ Composable NFTs
6. ✅ Batch operations
7. ✅ Metadata access
8. ✅ Ownership verification

**Ejecutar tests**:
```bash
flow test tests/SecureNFT_test.cdc
```

---

## 🎯 Use Cases

### 1. Standard NFT Collection
```cadence
// Mint NFT
minter.mintNFT(
    recipient: userCollection,
    name: "Art #1",
    description: "Beautiful artwork",
    thumbnail: "https://...",
    metadata: {"artist": "Alice"}
)
```

### 2. Gaming Items (Composable)
```cadence
// Character NFT con equipped items
let character <- create NFT(...)
character.addChildNFT(<- sword)
character.addChildNFT(<- shield)
character.addChildNFT(<- armor)
```

### 3. Batch Minting
```cadence
// Mint 100 NFTs eficientemente
minter.batchMintNFT(
    recipient: collection,
    count: 100,
    // ...
)
```

### 4. Secure Marketplace
```cadence
// Create listing (NFT stored securely)
marketplace.createListing(
    nft: <- myNFT,
    price: 10.0,
    seller: myAddress
)

// Purchase (atomic, no reentrancy)
let nft <- marketplace.purchase(listingID: 1)
```

---

## 📚 Referencias

### Flow Documentation
- [Cadence Resources](https://developers.flow.com/cadence/language/resources)
- [NFT Standard](https://developers.flow.com/build/advanced-concepts/nft-guide)
- [MetadataViews (FLIP-636)](https://github.com/onflow/flips/blob/main/application/20210916-nft-metadata.md)

### Standards
- [Flow NFT Standard](https://github.com/onflow/flow-nft)
- [MetadataViews](https://github.com/onflow/flow-nft#metadataviews)

### Examples
- [NBA Top Shot](https://nbatopshot.com/) - Largest NFT project on Flow
- [NFL All Day](https://nflallday.com/)
- [Flovatar](https://flovatar.com/)

---

## 💡 Conclusión

**Cadence no necesita "workarounds" para NFTs**:

| Problema | EVM | Cadence |
|----------|-----|---------|
| Reentrancy | Manual guards | Eliminated by design |
| High gas costs | Complex optimizations | Efficient by design |
| Composability | 7-year Draft EIP | Natural pattern |
| Approval pattern | Two-step, risky | Capabilities |
| Metadata | Off-chain (expensive) | On-chain (affordable) |
| Batch operations | Multiple standards | Natural |

**Resultado**: NFTs más seguros, más baratos, más fáciles de implementar.
