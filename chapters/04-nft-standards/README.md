# Capítulo 4: NFT Standards Evolution

> **Duración estimada del video**: 30 minutos
> **Dificultad**: Intermedio-Avanzado
> **Prerequisitos**: Entender ERC-20, conceptos básicos de NFTs

---

## 📋 Índice

1. [Introducción](#introducción)
2. [El Problema](#el-problema)
3. [Evolución de Estándares EVM](#evolución-de-estándares-evm)
4. [EIPs Relacionados](#eips-relacionados)
5. [Solución en Cadence](#solución-en-cadence)
6. [Comparación](#comparación)
7. [Demo Práctica](#demo-práctica)
8. [Recursos Adicionales](#recursos-adicionales)

---

## 🎯 Introducción

### ¿Qué aprenderás?

En este capítulo aprenderás:
- [ ] Por qué ERC-721 tiene costos de gas prohibitivos
- [ ] Vulnerabilidades críticas: safeMint reentrancy, NFT Trader hack ($3M)
- [ ] Evolución: ERC-721 → ERC-721A → ERC-1155
- [ ] ERC-998 Composable NFTs (todavía Draft desde 2018)
- [ ] Cómo Cadence resuelve NFTs con Resources y MetadataViews

### Contexto

Los NFTs explotaron en popularidad en 2021, pero el estándar ERC-721 original (2017) **no fue diseñado para escala masiva**. Los proyectos enfrentaron:

**2024 Statistics**:
- **43%** de proyectos NFT lanzan con vulnerabilidades críticas
- **$118M** perdidos en NFT hacks y fraud (2024)
- **82%** gas savings con ERC-721A vs ERC-721 original
- **$35M** cuesta guardar 1GB on-chain (17,500 ETH)

**Hacks recientes**:
- **NFT Trader** (Dic 2023): $3M robados por reentrancy
- **The Idols** (2024): $340K explotados por bug en `_beforeTokenTransfer`

---

## ❌ El Problema

### Descripción Teórica: ERC-721 Original

**Problema 1: Gas Costs Prohibitivos**

```solidity
// OpenZeppelin ERC721Enumerable
function _mint(address to, uint256 tokenId) internal {
    // Guarda owner
    _owners[tokenId] = to;  // SSTORE: 20,000 gas

    // Actualiza balance
    _balances[to] += 1;  // SSTORE: 20,000 gas

    // Enumerable tracking (peor parte)
    _addTokenToOwnerEnumeration(to, tokenId);  // 40,000+ gas
    _addTokenToAllTokensEnumeration(tokenId);  // 40,000+ gas
}
```

**Gas Costs REALES**:
| Operación | ERC-721 Enumerable | ERC-721A (Azuki) | Ahorro |
|-----------|-------------------|------------------|--------|
| Mint 1 NFT | 104,138 gas | 93,704 gas | 10% |
| Mint 5 NFTs | **566,090 gas** | 103,736 gas | **82%** 🔥 |
| Transfer | ~60,000 gas | ~67,000 gas | -12% |

**Resultado**: Minting 5 NFTs con ERC-721 = **$170** (a 30 gwei, ETH $3000)

---

**Problema 2: No Batch Operations**

```solidity
// ❌ Para mintear 10 NFTs necesitas 10 transacciones
for (uint i = 0; i < 10; i++) {
    nft.mint(recipient, tokenId + i);  // 10 tx separadas!
}
```

**Consecuencias**:
- 10x gas costs
- 10x tiempo de espera
- Mal UX para usuarios

---

**Problema 3: Vulnerabilidad safeMint Reentrancy**

```solidity
// OpenZeppelin ERC721
function _safeMint(address to, uint256 tokenId) internal {
    _mint(to, tokenId);

    // ⚠️ VULNERABLE: Llama código externo ANTES de actualizar estado
    require(_checkOnERC721Received(address(0), to, tokenId, ""),
        "ERC721: transfer to non ERC721Receiver implementer");
}

function _checkOnERC721Received(...) private returns (bool) {
    // ⚠️ External call al receiver
    return IERC721Receiver(to).onERC721Received(...) ==
           IERC721Receiver.onERC721Received.selector;
}
```

**Attack vector**:
```solidity
// Atacante implementa onERC721Received malicioso
contract MaliciousReceiver is IERC721Receiver {
    function onERC721Received(...) external returns (bytes4) {
        // ⚠️ REENTRANCY: Vuelve a llamar mint!
        VulnerableNFT(msg.sender).mint();
        return this.onERC721Received.selector;
    }
}
```

---

### Ejemplo del Mundo Real

#### **NFT Trader Hack** (Diciembre 2023): **$3M robados**

**El exploit:**
```solidity
// Contrato vulnerable de NFT Trader
contract OldNFTSwap {
    mapping(uint256 => SwapOffer) public offers;

    function acceptOffer(uint256 offerId) external {
        SwapOffer memory offer = offers[offerId];

        // ⚠️ VULNERABLE: External call ANTES de state update
        IERC721(offer.nftContract).safeTransferFrom(
            offer.owner,
            msg.sender,
            offer.tokenId
        );

        // ❌ Demasiado tarde - el atacante ya reentranceó
        delete offers[offerId];
    }
}
```

**Tokens robados**:
- Bored Ape Yacht Club NFTs
- World of Women NFTs
- VeeFriends NFTs
- Art Blocks NFTs

**Total**: $3 millones

---

#### **The Idols NFT** (2024): **$340K robados**

**Bug en _beforeTokenTransfer:**
```solidity
contract TheIdols is ERC721 {
    mapping(uint256 => uint256) public stakedRewards;

    // ⚠️ VULNERABLE
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        // Claim rewards on transfer
        if (from != address(0)) {
            uint256 rewards = stakedRewards[tokenId];
            // ⚠️ External call durante transfer!
            stETH.transfer(from, rewards);
        }
    }
}
```

**Attack**: Transferir mismo NFT múltiples veces en una tx → Claim rewards múltiples veces

---

**Problema 4: Metadata Storage**

**On-chain storage costs**:
- 1 byte en Ethereum = ~640 gas
- 1 KB = ~640,000 gas
- **1 GB = 17,500 ETH** (~$35M a $2000/ETH)

**Imagen JPG típica**: 2-4 MB

**Resultado**: 99% de NFTs usan off-chain storage

```solidity
// ❌ Mayoría de NFTs
function tokenURI(uint256 tokenId) public view returns (string) {
    // ⚠️ Centralizado, puede desaparecer
    return string.concat("https://api.myproject.com/token/", tokenId);
    // o
    return string.concat("ipfs://QmHash.../", tokenId);  // IPFS puede GC
}
```

**Problemas**:
- ❌ Metadata puede desaparecer (IPFS garbage collection)
- ❌ Servidores centralizados pueden caerse
- ❌ Metadata es mutable (puede cambiar después de venta)

---

## 🔧 Evolución de Estándares EVM

### Workaround 1: ERC-1155 Multi-Token Standard (2018)

**Descripción**: Un contrato para tokens fungibles Y no-fungibles

```solidity
// ERC-1155 - Enjin
contract ERC1155 {
    // ⭐ Un balance mapping para TODO
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // ✅ BATCH OPERATIONS!
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external {
        for (uint256 i = 0; i < ids.length; ++i) {
            _balances[ids[i]][from] -= amounts[i];
            _balances[ids[i]][to] += amounts[i];
        }
        // Una sola external call al final
        _doSafeBatchTransferAcceptanceCheck(from, to, ids, amounts, data);
    }
}
```

**Ventajas**:
- ✅ Batch transfers: 10 NFTs en UNA transacción
- ✅ ~80% menos gas que ERC-721 para batches
- ✅ Fungible + Non-fungible en mismo contrato
- ✅ Usado en gaming: Enjin, Decentraland, The Sandbox

**Desventajas**:
- ❌ Menos soporte en marketplaces (OpenSea solo agregó en 2021)
- ❌ No es "true NFT" (puede tener supply > 1)
- ❌ Metadata más compleja

**Casos de uso**: Gaming items, semi-fungibles, colecciones masivas

---

### Workaround 2: ERC-721A (Azuki, 2022)

**Descripción**: Optimización de ERC-721 para batch minting

**Innovación clave**: Guardar owner UNA vez por batch

```solidity
// ERC-721A - Azuki
contract ERC721A {
    // Ownership comprimido
    struct TokenOwnership {
        address addr;
        uint64 startTimestamp;
        bool burned;
    }

    mapping(uint256 => TokenOwnership) internal _ownerships;

    // ⭐ Batch mint: Guarda owner solo para el primer token
    function _mint(address to, uint256 quantity) internal {
        uint256 startTokenId = _currentIndex;

        // SOLO guarda el primer owner!
        _ownerships[startTokenId] = TokenOwnership(
            to,
            uint64(block.timestamp),
            false
        );

        // Los siguientes tokens "heredan" el owner
        _currentIndex += quantity;

        // Emite eventos para todos
        for (uint256 i = 0; i < quantity; i++) {
            emit Transfer(address(0), to, startTokenId + i);
        }
    }

    // Para encontrar owner: busca hacia atrás hasta encontrar uno set
    function ownerOf(uint256 tokenId) public view returns (address) {
        TokenOwnership memory ownership = _ownerships[tokenId];
        if (ownership.addr != address(0)) {
            return ownership.addr;
        }
        // Busca hacia atrás
        while (true) {
            tokenId--;
            ownership = _ownerships[tokenId];
            if (ownership.addr != address(0)) {
                return ownership.addr;
            }
        }
    }
}
```

**Gas Savings**:
```
Minting 5 NFTs:
- ERC-721:  566,090 gas  ($170 @ 30gwei, ETH$3k)
- ERC-721A: 103,736 gas  ($31 @ 30gwei, ETH$3k)
Ahorro: 82%! 🔥
```

**Trade-offs**:
- ✅ Minting: 82% más barato
- ❌ Transfer: 10-15% más caro (búsqueda hacia atrás)
- ❌ `ownerOf()`: O(n) en peor caso

**Usado por**: Azuki, Beanz, Elemental, Pixelmon

---

### Workaround 3: ERC-998 Composable NFTs (Draft)

**Descripción**: NFTs que pueden "poseer" otros NFTs/tokens

```solidity
// ERC-998 - Composable
interface IERC998ERC721TopDown {
    // Top-down: Parent owns children
    function safeTransferChild(
        uint256 fromTokenId,
        address to,
        address childContract,
        uint256 childTokenId
    ) external;

    function childContractsFor(uint256 tokenId)
        external view returns (address[] memory);
}
```

**Ejemplo real**:
```
CryptoKitty #123
├── Scratching Post (ERC-721)
├── Food Bowl (ERC-721)
└── 500 Chow Tokens (ERC-20)

// Transferir el kitty = transferir TODO
transfer(recipient, cryptoKitty#123);
→ Recipient recibe: kitty + post + bowl + 500 chow
```

**Status**:
- Propuesto: 2018 (hace 6 años!)
- Estado: **Draft** (nunca finalized)
- Adopción: **Muy baja** (<1% de proyectos)

**Por qué no se adoptó**:
- Complejidad alta
- Gas costs todavía muy altos
- Marketplaces no lo soportan

---

### Workaround 4: Protección contra Reentrancy

```solidity
// OpenZeppelin después de hacks
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SafeNFT is ERC721, ReentrancyGuard {
    function mint() external nonReentrant {
        _safeMint(msg.sender, nextTokenId++);
    }

    // ✅ También protege funciones relacionadas
    function acceptOffer(uint256 offerId) external nonReentrant {
        // Safe
    }
}
```

**Recomendaciones**:
- ✅ Use `nonReentrant` en TODAS las funciones con external calls
- ✅ Follow Checks-Effects-Interactions pattern
- ✅ Prefer `_mint()` sobre `_safeMint()` cuando sea seguro

---

## 📜 EIPs Relacionados

### EIP-721: Non-Fungible Token Standard (2018)

- **Status**: Final
- **Autores**: William Entriken, Dieter Shirley, Jacob Evans, Nastassia Sachs
- **Problema original**: No existía estándar para unique assets
- **Limitación**: No contempló batch operations ni gas optimization

### EIP-1155: Multi Token Standard (2018)

- **Status**: Final
- **Autor**: Witek Radomski (Enjin)
- **Innovación**: Batch operations, fungible + non-fungible
- **Adopción**: Gaming (alta), Art NFTs (baja)

### EIP-998: Composable Non-Fungible Token (2018)

- **Status**: Draft (6 años!)
- **Autores**: Matt Lockyer, Nick Mudge
- **Problema**: Complejidad, falta de demanda real
- **Estado**: Probablemente nunca será Final

### EIP-2309: ERC-721 Consecutive Transfer Extension (2019)

- **Status**: Final
- **Propósito**: Emit batch events eficientemente
- **Usado por**: ERC-721A para batch minting

```solidity
event ConsecutiveTransfer(
    uint256 indexed fromTokenId,
    uint256 toTokenId,
    address indexed fromAddress,
    address indexed toAddress
);
```

### EIP-4906: Metadata Update Extension (2022)

- **Status**: Final
- **Propósito**: Notificar cuando metadata cambia

```solidity
event MetadataUpdate(uint256 _tokenId);
event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
```

---

## ✨ Solución en Cadence

### ¿Cómo Cadence resuelve esto nativamente?

**Cadence NFTs = Resources** (no mappings centralizados)

**Diferencias fundamentales**:

| Aspecto | ERC-721 | Cadence NFT |
|---------|---------|-------------|
| **Storage** | Central ledger (mapping) | User's account (Resource) |
| **Ownership** | `_owners[tokenId] = address` | Direct possession |
| **Duplicación** | Posible con bugs | **Imposible** (compiler) |
| **Pérdida** | Posible con bugs | **Imposible** (can't vanish) |
| **Reentrancy** | Vulnerable | **Imposible** (Resources can't be in 2 places) |
| **Metadata** | External JSON | **MetadataViews** (on-chain) |

---

### Ejemplo: Flow NFT Standard

```cadence
// Flow NFT Standard
import NonFungibleToken from 0x1d7e57aa55817448

access(all) contract ExampleNFT: NonFungibleToken {

    // ⭐ NFT como Resource (no puede duplicarse)
    access(all) resource NFT: NonFungibleToken.NFT {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let description: String
        access(all) let thumbnail: String

        // ⭐ MetadataViews on-chain
        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(url: self.thumbnail)
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties([
                        MetadataViews.Royalty(
                            receiver: creatorCapability,
                            cut: 0.05  // 5% royalty
                        )
                    ])
            }
            return nil
        }
    }

    // ⭐ Collection guardada EN la cuenta del usuario
    access(all) resource Collection: NonFungibleToken.Collection {
        access(all) var ownedNFTs: @{UInt64: NFT}

        access(all) fun deposit(token: @NFT) {
            let id = token.id
            self.ownedNFTs[id] <-! token
        }

        // ✅ NO reentrancy possible - Resource movido directamente
        access(all) fun withdraw(withdrawID: UInt64): @NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("NFT not found")
            return <- token
        }
    }
}
```

---

### MetadataViews: Unified Standard

**Problema ERC-721**: Cada proyecto inventa su JSON schema

**Solución Cadence**: MetadataViews (FLIP-0636)

```cadence
// Standard views que TODOS los NFTs implementan
access(all) struct interface Resolver {
    access(all) fun resolveView(_ view: Type): AnyStruct?
    access(all) fun getViews(): [Type]
}

// Views disponibles:
// - Display: nombre, descripción, thumbnail
// - Royalties: creator royalties standardizados
// - Editions: cual edición es (3 of 100)
// - Serial: número serial
// - Media: imagen, video, audio
// - ExternalURL: website del proyecto
// - NFTCollectionData: info de la colección
// - NFTCollectionDisplay: como mostrar la colección
// - Traits: atributos/rasgos
```

**Ventajas**:
- ✅ Todos los marketplaces muestran igual
- ✅ Metadata on-chain (más eficiente que ETH)
- ✅ Royalties estandarizados (no puede evadirse)
- ✅ Composable: Nuevas views sin romper contratos

---

### Ventajas del Modelo Resource

**1. No Reentrancy Possible**

```cadence
// ✅ Imposible por diseño
transaction {
    prepare(signer: auth(BorrowValue) &Account) {
        let collection = signer.storage.borrow<&ExampleNFT.Collection>(
            from: /storage/NFTCollection
        )!

        // Withdraw mueve el Resource FUERA de la collection
        let nft <- collection.withdraw(withdrawID: 1)

        // ⚠️ El siguiente código NO COMPILA:
        // let nft2 <- collection.withdraw(withdrawID: 1)
        // ERROR: "loss of resource `nft`"

        // ✅ Debes manejar `nft` primero
        destroy nft
    }
}
```

**2. No puede perderse**

```cadence
transaction {
    prepare(signer: &Account) {
        let nft <- mintNFT()

        // ⚠️ Si olvidas hacer algo con `nft`, no compila!
        // ERROR: "loss of resource"

        // ✅ DEBES:
        // - depositarlo: collection.deposit(<-nft)
        // - transferirlo: recipient.deposit(<-nft)
        // - destruirlo: destroy nft
    }
}
```

**3. No puede duplicarse**

```solidity
// ❌ En Solidity esto es posible con bug:
_owners[tokenId] = alice;
_owners[tokenId] = bob;  // Alice y Bob "poseen" mismo NFT!
```

```cadence
// ✅ En Cadence es IMPOSIBLE
let nft <- collection.withdraw(id: 1)
// El NFT ya NO está en `collection`
// No puede estar en dos lugares a la vez
```

---

## ⚖️ Comparación

| Aspecto | ERC-721 | ERC-721A | ERC-1155 | Cadence NFT |
|---------|---------|----------|----------|-------------|
| **Mint 5 NFTs gas** | 566k | 104k | ~100k | ~60k |
| **Batch operations** | ❌ | ❌ | ✅ | ✅ |
| **Reentrancy vulnerable** | ✅ | ✅ | ✅ | ❌ |
| **Can be duplicated** | Con bugs | Con bugs | Con bugs | **Imposible** |
| **Can be lost** | Con bugs | Con bugs | Con bugs | **Imposible** |
| **Metadata** | Off-chain | Off-chain | Off-chain | On-chain |
| **Royalties** | No standard | No standard | No standard | **Standardized** |
| **Marketplace support** | Universal | Universal | Parcial | Flow markets |

---

## 💻 Demo Práctica

Ver archivos en:
- `evm/problema.sol` - ERC-721 vulnerable (safeMint reentrancy)
- `evm/workaround.sol` - ERC-721A, ERC-1155, protecciones
- `cadence/NFTStandard.cdc` - Flow NFT con MetadataViews

Tests:
```bash
# Solidity
cd evm && forge test -vv

# Cadence
cd cadence && flow test tests/NFTStandard_test.cdc
```

---

## 📚 Recursos Adicionales

### Documentación Oficial
- [EIP-721](https://eips.ethereum.org/EIPS/eip-721)
- [EIP-1155](https://eips.ethereum.org/EIPS/eip-1155)
- [ERC-721A by Azuki](https://www.erc721a.org/)
- [Flow NFT Standard](https://github.com/onflow/flow-nft)
- [Cadence MetadataViews](https://developers.flow.com/build/advanced-concepts/metadata-views)

### Análisis de Hacks
- [NFT Trader Hack Analysis](https://www.halborn.com/blog/post/explained-the-nft-trader-hack-december-2023)
- [The Idols NFT Exploit](https://rekt.news/the-idols-rekt/)

### Herramientas
- [OpenSea Metadata Standards](https://docs.opensea.io/docs/metadata-standards)
- [NFT Standards Wiki](https://www.nftstandards.wtf/)

---

## 🔗 Enlaces Rápidos

- [← Capítulo Anterior: ERC20 Approval](../03-approval-pattern/)
- [↑ Índice General](../../INDEX.md)
- [→ Siguiente Capítulo: Account Abstraction](../05-account-abstraction/)

---

**Tags**: `#NFT` `#ERC721` `#ERC1155` `#ERC721A` `#MetadataViews` `#Reentrancy`

**Fecha de creación**: 2025-11-14
**Última actualización**: 2025-11-14
**Estado**: 🟢 Completo
