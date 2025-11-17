# Comparativa: NFT Standards EVM vs Cadence

## 🎯 Resumen Ejecutivo

| Aspecto | EVM | Cadence | Ganador |
|---------|-----|---------|---------|
| **Seguridad** | Manual (reentrancy guards) | By design (Resources) | 🏆 Cadence |
| **Gas Efficiency** | Optimizations needed | Natural efficiency | 🏆 Cadence |
| **Composability** | Complex (EIP-998 Draft) | Trivial (3 LOC) | 🏆 Cadence |
| **Ownership Model** | Simulated (mappings) | True (Resources) | 🏆 Cadence |
| **Batch Operations** | Multiple standards | Natural | 🏆 Cadence |
| **Marketplace Support** | High (established) | Growing | 🏆 EVM |
| **Developer Experience** | Complex, error-prone | Intuitive, safe | 🏆 Cadence |

---

## 1️⃣ Reentrancy Attacks

### EVM: Manual Protection Required

**Código vulnerable**:
```solidity
function mint() external payable {
    require(!hasMinted[msg.sender], "Already minted");

    _safeMint(msg.sender, newTokenId);  // ⚠️ Callback here

    hasMinted[msg.sender] = true;  // ❌ Too late
}
```

**Ataque**:
```solidity
function onERC721Received(...) external returns (bytes4) {
    if (attackCount < 5) {
        vulnerableNFT.mint{value: 0}();  // Re-enter!
    }
    return this.onERC721Received.selector;
}
```

**Resultado**: 5 NFTs por el precio de 1

**Fix en EVM**: Agregar `nonReentrant` modifier
```solidity
function mint() external payable nonReentrant {  // ✅ Added guard
    require(!hasMinted[msg.sender], "Already minted");
    hasMinted[msg.sender] = true;  // ✅ State updated first
    _safeMint(msg.sender, newTokenId);
}
```

**Costo del fix**:
- +2,500 gas por transacción
- Requiere recordar usar el modifier
- Auditoría necesaria para verificar

### Cadence: Imposible por Diseño

**Código (inherentemente seguro)**:
```cadence
access(all) fun mintNFT(recipient: &{CollectionPublic}) {
    let nft <- create NFT(...)
    recipient.deposit(token: <- nft)  // ✅ No callback
}
```

**Por qué no hay reentrancy**:
1. ❌ No existe `onERC721Received` callback
2. ✅ `deposit()` es una función simple, no hace external calls
3. ✅ Resource es movido atómicamente
4. ✅ El compilador previene race conditions

**Costo del fix**: **$0** - Ya es seguro

### Hacks Reales Prevenidos

| Hack | Fecha | Pérdida | Prevenible en Cadence? |
|------|-------|---------|------------------------|
| The Idols NFT | 2024 | $340,000 | ✅ Yes |
| NFT Trader | Dec 2023 | $3,000,000 | ✅ Yes |
| **Total** | | **$3,340,000** | ✅ Yes |

---

## 2️⃣ Gas Costs

### EVM: Optimizations Needed

**ERC-721 (Standard)**:
```solidity
// Cada NFT escribe a storage
_owners[0] = alice;  // 20,000 gas
_owners[1] = alice;  // 20,000 gas
_owners[2] = alice;  // 20,000 gas
_balances[alice] += 3;  // 5,000 gas
```

**Gas costs**:
| Operación | Gas | USD (gas 50 gwei, ETH $2000) |
|-----------|-----|------------------------------|
| Mint 1 NFT | 113,000 | $11.30 |
| Mint 5 NFTs | 566,000 | $56.60 |
| Mint 100 NFTs | 11,300,000 | **$1,130.00** |

**ERC-721A (Azuki Optimization)**:
```solidity
// Solo escribe ownership una vez por batch
_owners[0] = alice;  // 20,000 gas
// IDs 1-4 infieren ownership
```

**Gas savings**:
| Operación | ERC-721 | ERC-721A | Ahorro |
|-----------|---------|----------|--------|
| Mint 1 NFT | 113k | 50k | 56% |
| Mint 5 NFTs | 566k | 104k | **82%** |
| Mint 100 NFTs | 11,300k | 2,000k | **82%** |

**Pero**:
- Requiere implementación compleja
- Auditoría profesional necesaria ($50k-$100k)
- Azuki tuvo que inventar este patrón (años de trabajo)

**ERC-1155 (Multi-Token)**:
```solidity
// Mapping unificado
mapping(uint256 => mapping(address => uint256)) _balances;
```

**Gas**: ~90k para 5 NFTs (84% ahorro vs ERC-721)

**Pero**:
- Menos compatible con marketplaces
- Lógica más compleja
- Diferentes trade-offs

### Cadence: Eficiente por Diseño

```cadence
// Batch mint natural
access(all) fun batchMintNFT(recipient: &{CollectionPublic}, count: Int) {
    var i = 0
    while i < count {
        let nft <- create NFT(...)
        recipient.deposit(token: <- nft)
        i = i + 1
    }
}
```

**Ventajas**:
- No requiere trucos de optimización
- Código simple y directo
- Naturalmente eficiente
- No necesita años de investigación

### Comparación de Complejidad

| Aspecto | ERC-721 | ERC-721A | Cadence |
|---------|---------|----------|---------|
| Lines of code | ~300 | ~800 | ~200 |
| Optimization tricks | None | Many | None needed |
| Audit complexity | Medium | High | Low |
| Developer time | Days | Weeks | Hours |
| Gas efficiency | Baseline | 82% better | Naturally efficient |

---

## 3️⃣ Composable NFTs

### EVM: EIP-998 (Draft por 7 años)

**Complejidad**:
```solidity
contract ComposableNFT {
    // Tracking de children NFTs
    mapping(uint256 => mapping(address => uint256[])) internal childTokens;
    mapping(uint256 => address[]) internal childContracts;

    function safeTransferChild(
        uint256 fromTokenId,
        address to,
        address childContract,
        uint256 childTokenId
    ) external {
        // 50+ líneas de código complejo
        require(_exists(fromTokenId), "Parent doesn't exist");
        require(ownerOf(fromTokenId) == msg.sender, "Not owner");

        // Remove from parent tracking
        _removeChild(fromTokenId, childContract, childTokenId);

        // Transfer child
        IERC721(childContract).safeTransferFrom(address(this), to, childTokenId);

        emit TransferChild(fromTokenId, to, childContract, childTokenId);
    }

    function _removeChild(uint256 tokenId, address childContract, uint256 childId) internal {
        // Complejo array manipulation
        uint256[] storage children = childTokens[tokenId][childContract];
        for (uint256 i = 0; i < children.length; i++) {
            if (children[i] == childId) {
                children[i] = children[children.length - 1];
                children.pop();
                break;
            }
        }
    }
}
```

**Problemas**:
- 📝 EIP-998 aún en **Draft** (propuesto en 2018)
- 💰 Gas costs prohibitivos
- 🐛 Alta probabilidad de bugs
- 📉 <1% de adopción en producción
- 🔍 Requiere auditoría extensa

**Proyectos que lo usan**: Casi ninguno (demasiado complejo)

### Cadence: Trivial (3 líneas)

```cadence
access(all) resource NFT {
    // ✅ NFT puede contener otros NFTs
    access(self) var childNFTs: @{UInt64: NFT}
}

// Agregar child NFT
access(all) fun addChildNFT(_ nft: @NFT) {
    self.childNFTs[nft.id] <-! nft  // ✅ Solo esto!
}

// Remover child NFT
access(all) fun removeChildNFT(id: UInt64): @NFT {
    return <- self.childNFTs.remove(key: id)!
}
```

**Ventajas**:
- ✅ 3 líneas de código vs 200+ en EVM
- ✅ Type-safe (el compilador verifica todo)
- ✅ No puede perderse (linear types)
- ✅ Natural pattern (no requiere EIP)
- ✅ Gas eficiente

### Comparación

| Aspecto | EVM (EIP-998) | Cadence |
|---------|---------------|---------|
| Standard status | Draft (7 years) | Natural pattern |
| Lines of code | 200+ | 3 |
| Implementation time | Weeks | Minutes |
| Gas cost overhead | Very high | Minimal |
| Bug probability | High | Low (compiler checks) |
| Production use | <1% | Common |
| Audit cost | $50k-$100k | Standard |

### Use Cases

**Gaming: Character + Items**

EVM:
```solidity
// Complejo, costoso, propenso a bugs
characterNFT.safeTransferChild(
    characterId,
    address(this),
    swordContract,
    swordId
);
```

Cadence:
```cadence
// Simple, seguro, eficiente
character.addChildNFT(<- sword)
character.addChildNFT(<- shield)
character.addChildNFT(<- armor)
```

---

## 4️⃣ Ownership Model

### EVM: Simulated Ownership (Mappings)

```solidity
// Central mapping controlado por el contrato
mapping(uint256 => address) private _owners;

function _transfer(address from, address to, uint256 tokenId) internal {
    require(ownerOf(tokenId) == from, "Not owner");

    // "Ownership" es solo cambiar un mapping
    _owners[tokenId] = to;

    emit Transfer(from, to, tokenId);
}
```

**Problemas**:
1. ⚠️ Ownership es solo un entry en un mapping
2. ⚠️ Bug en el contrato puede transferir todos los NFTs
3. ⚠️ NFT puede "duplicarse" con un bug
4. ⚠️ NFT puede "perderse" si se envía a address(0)
5. ⚠️ Upgrade bugs pueden afectar todos los NFTs

**Ejemplos de bugs**:
- Poly Network: $611M stolen (bug en ownership logic)
- Uranium Finance: $50M (bug en balance tracking)

### Cadence: True Ownership (Resources)

```cadence
// Cada usuario tiene su propia Collection
access(all) resource Collection {
    access(all) var ownedNFTs: @{UInt64: NFT}
}

// NFT almacenado DIRECTAMENTE en account storage
account.storage.save(<-collection, to: /storage/NFTCollection)
```

**Ventajas**:
1. ✅ NFT almacenado **directamente** en el account del owner
2. ✅ **Imposible** duplicar (linear type)
3. ✅ **Imposible** perder (compiler checks)
4. ✅ Bug en contrato no afecta NFTs existentes
5. ✅ Ownership es **físico**, no virtual

**Comparación**:

| Aspecto | EVM | Cadence |
|---------|-----|---------|
| Storage | Central mapping | User's account |
| Can duplicate? | ⚠️ Yes (bugs) | ❌ Impossible |
| Can lose? | ⚠️ Yes (bugs) | ❌ Impossible |
| Bug affects? | All NFTs | Only new mints |
| Owner control | Virtual | Physical |

---

## 5️⃣ Approval Pattern

### EVM: Two-Step, Vulnerable

```solidity
// Paso 1: User aprueba marketplace
nft.approve(marketplace, tokenId);

// Paso 2: Marketplace transfiere
nft.transferFrom(seller, buyer, tokenId);
```

**Problemas**:
1. ⚠️ **Infinite approval**: `approve(spender, ALL_TOKENS)`
2. ⚠️ **Forgotten approvals**: Quedan activas indefinidamente
3. ⚠️ **Front-running**: Attacker ve approval en mempool
4. ⚠️ **Revocation bugs**: Olvidar revocar aprobaciones
5. ⚠️ **Phishing**: Malicious contract pide approval

**Stats**:
- OpenSea tiene approval de ~40% de todos los NFTs
- Riesgo si OpenSea es hackeado

### Cadence: Capabilities (Granular, Safe)

```cadence
// Crear Capability específica
let cap = account.capabilities.storage.issue<&Collection>(
    CollectionStoragePath
)

// Capability es:
// - Granular (solo lo que necesitas)
// - Revocable (puede eliminarse)
// - Type-safe (el compilador verifica)
// - Scoped (read-only o read-write)
```

**Ventajas**:
1. ✅ **No approval pattern** necesario
2. ✅ **Granular permissions**: Solo lo necesario
3. ✅ **Type-safe**: Compilador verifica
4. ✅ **Revocable**: Fácil de eliminar
5. ✅ **No phishing risk**: No approvals ciegos

---

## 6️⃣ Metadata Storage

### EVM: Off-Chain (Gas Costs)

```solidity
// On-chain storage costs
// 1 byte = ~20,000 gas
// 1 KB = 20,000,000 gas ≈ $400 USD

// Por eso casi todos usan IPFS/Arweave
function tokenURI(uint256 tokenId) external view returns (string) {
    return string(abi.encodePacked("ipfs://", ipfsHash, "/", tokenId));
}
```

**Problemas**:
- ⚠️ **IPFS puede desaparecer** (no garantizado)
- ⚠️ **Centralization risk** (IPFS gateways)
- ⚠️ **Not truly on-chain**
- ⚠️ **Metadata puede cambiar** (mutable IPFS)

**Costos**:
| Storage | Gas | USD (50 gwei, ETH $2k) |
|---------|-----|------------------------|
| 1 KB | 20M | $400 |
| 10 KB | 200M | $4,000 |
| 100 KB | 2B | $40,000 |
| 1 MB | 20B | **$400,000** |

### Cadence: On-Chain (Affordable)

```cadence
access(all) resource NFT {
    access(all) let name: String
    access(all) let description: String
    access(all) let thumbnail: String
    access(self) let metadata: {String: String}
}

// MetadataViews standard (FLIP-636)
// - On-chain metadata
// - Standardized interfaces
// - Affordable storage
```

**Ventajas**:
- ✅ **True on-chain metadata**
- ✅ **Affordable storage costs**
- ✅ **Standardized** (MetadataViews)
- ✅ **Immutable** (parte del Resource)

---

## 7️⃣ Batch Operations

### EVM: Multiple Solutions, Complex

**ERC-721**: No batch nativo
```solidity
// Loop manual
for (uint256 i = 0; i < ids.length; i++) {
    safeTransferFrom(from, to[i], ids[i]);  // ~113k gas each
}
// Total: ~566k gas para 5 NFTs
```

**ERC-721A**: Batch mint optimizado
```solidity
// Batch mint eficiente
_safeMint(to, quantity);
// ~104k gas para 5 NFTs
```

**ERC-1155**: Batch nativo
```solidity
safeBatchTransferFrom(from, to, ids, amounts, data);
// ~60k gas para 5 NFTs
```

**Problema**: Diferentes standards, diferentes APIs

### Cadence: Natural Pattern

```cadence
// Batch withdraw
access(all) fun batchWithdraw(ids: [UInt64]): @[NFT] {
    var nfts: @[NFT] <- []
    for id in ids {
        nfts.append(<- self.withdraw(withdrawID: id))
    }
    return <- nfts
}

// Batch deposit
access(all) fun batchDeposit(tokens: @[NFT]) {
    while tokens.length > 0 {
        self.deposit(token: <- tokens.removeFirst())
    }
    destroy tokens
}
```

**Ventajas**:
- ✅ Un solo standard
- ✅ API consistente
- ✅ Natural y seguro
- ✅ Type-safe operations

---

## 📊 Tabla Comparativa Final

| Feature | EVM | Cadence | Diferencia |
|---------|-----|---------|------------|
| **Reentrancy Protection** | Manual | By design | ✅ $3.34M hacks prevented |
| **Gas (5 NFTs)** | 566k → 104k (optimized) | Efficient | ✅ No optimization needed |
| **Composable NFTs** | EIP-998 (Draft 7 years) | 3 lines | ✅ 200+ LOC → 3 LOC |
| **Ownership** | Simulated (mappings) | True (Resources) | ✅ Can't duplicate/lose |
| **Approval Pattern** | Required (risky) | Not needed | ✅ No phishing risk |
| **Metadata** | Off-chain ($400/KB) | On-chain (affordable) | ✅ Truly on-chain |
| **Batch Operations** | Multiple standards | Natural | ✅ Consistent API |
| **Implementation Time** | Weeks | Hours | ✅ 10x faster |
| **Audit Complexity** | High | Low | ✅ Safer by design |
| **Bug Probability** | Medium-High | Low | ✅ Compiler prevents |

---

## 💰 Costo Total de Ownership

### EVM

**Desarrollo**:
- Desarrollo inicial: $20k-$50k
- Optimización (ERC-721A): $30k-$60k
- Auditoría: $50k-$100k
- **Total**: $100k-$210k

**Gas costs** (100 NFTs):
- ERC-721: ~$1,130
- ERC-721A: ~$200
- ERC-1155: ~$180

**Riesgo**:
- Reentrancy hacks: $3.34M en 2023-2024
- Approval exploits: Ongoing risk

### Cadence

**Desarrollo**:
- Desarrollo inicial: $5k-$10k
- Auditoría: $10k-$20k
- **Total**: $15k-$30k

**Gas costs**:
- Naturalmente eficiente
- No requiere optimización

**Riesgo**:
- Reentrancy: Imposible
- Approval exploits: No existen

---

## 🎯 Conclusión

**Cadence no es "mejor" en NFTs - es fundamentalmente diferente**:

1. **Seguridad**: By design, no manual guards
2. **Eficiencia**: Natural, no optimizaciones complejas
3. **Composabilidad**: Trivial, no EIPs de 7 años
4. **Ownership**: True ownership, no mappings
5. **Developer Experience**: Intuitivo, type-safe
6. **Time to Market**: 10x más rápido

**Resultado**: NFTs más seguros, más baratos, más fáciles de implementar.

**Trade-off**: Ecosystem más pequeño (por ahora), pero creciendo rápidamente.
