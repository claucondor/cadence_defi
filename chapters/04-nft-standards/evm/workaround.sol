// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/**
 * @title OptimizedNFT_ERC721A
 * @notice ✅ Solución EVM usando ERC-721A (Azuki)
 *
 * Mejoras sobre ERC-721 estándar:
 * 1. ✅ 82% menos gas: 104k gas para 5 NFTs vs 566k en ERC-721
 * 2. ✅ Batch minting optimizado
 * 3. ✅ Protección contra reentrancy con checks-effects-interactions
 *
 * Cómo funciona:
 * - Almacena ownership una sola vez por batch en lugar de por token
 * - Reduce escrituras a storage (operación más cara de EVM)
 * - Usa aux data para metadata adicional sin costo extra
 *
 * Pero aún tiene limitaciones:
 * ⚠️ Sigue siendo complejo implementar correctamente
 * ⚠️ Requiere auditoría para reentrancy en funciones custom
 * ⚠️ No elimina la posibilidad de bugs en callbacks
 */
contract OptimizedNFT_ERC721A is ERC721A, Ownable, ReentrancyGuard {
    uint256 public constant PRICE = 0.1 ether;
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_PER_TX = 10;

    mapping(address => bool) public hasMinted;

    event NFTMinted(address indexed to, uint256 quantity);

    constructor() ERC721A("OptimizedNFT", "ONFT") Ownable(msg.sender) {}

    /**
     * @notice ✅ SECURE: Protegido contra reentrancy
     *
     * Protecciones implementadas:
     * 1. nonReentrant modifier previene re-entrada
     * 2. Checks-Effects-Interactions pattern
     * 3. hasMinted actualizado ANTES de _safeMint()
     *
     * Gas savings con ERC721A:
     * - 1 NFT: ~50k gas (vs ~113k en ERC-721)
     * - 5 NFTs: ~104k gas (vs ~566k en ERC-721) = 82% ahorro
     * - 10 NFTs: ~120k gas (vs ~1,130k en ERC-721) = 89% ahorro
     */
    function mint(uint256 quantity) external payable nonReentrant {
        // ✅ CHECKS: Validaciones primero
        require(quantity > 0 && quantity <= MAX_PER_TX, "Invalid quantity");
        require(msg.value == PRICE * quantity, "Incorrect payment");
        require(!hasMinted[msg.sender], "Already minted");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Max supply reached");

        // ✅ EFFECTS: Actualizar estado ANTES de external calls
        hasMinted[msg.sender] = true;

        // ✅ INTERACTIONS: External calls al final
        _safeMint(msg.sender, quantity);

        emit NFTMinted(msg.sender, quantity);
    }

    /**
     * @notice Batch transfer (aún no optimizado)
     * Nota: ERC721A no provee batch transfer nativo
     * Cada transfer sigue costando ~50k gas
     */
    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata tokenIds
    ) external nonReentrant {
        require(recipients.length == tokenIds.length, "Length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            safeTransferFrom(msg.sender, recipients[i], tokenIds[i]);
        }
    }

    /**
     * @notice Get tokens owned by address
     * Útil para wallets y frontends
     */
    function tokensOfOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256 index = 0;

        for (uint256 i = 0; i < totalSupply(); i++) {
            if (ownerOf(i) == owner) {
                tokenIds[index++] = i;
            }
        }

        return tokenIds;
    }
}

/**
 * @title MultiTokenNFT_ERC1155
 * @notice ✅ Solución EVM usando ERC-1155
 *
 * Ventajas sobre ERC-721:
 * 1. ✅ Batch operations nativas (transferencias, mints)
 * 2. ✅ Soporta tokens fungibles Y no-fungibles
 * 3. ✅ Operaciones más eficientes en gas
 *
 * Use cases:
 * - Gaming items (fungibles + NFTs únicos)
 * - Membership tiers (different token IDs)
 * - Multiple NFT collections en un solo contrato
 *
 * Limitaciones:
 * ⚠️ Menos compatible con marketplaces existentes (mayoría usa ERC-721)
 * ⚠️ Lógica más compleja para NFTs únicos
 * ⚠️ Metadata management más complicado
 */
contract MultiTokenNFT_ERC1155 is ERC1155, Ownable, ReentrancyGuard {
    uint256 public currentTokenId;
    uint256 public constant PRICE = 0.1 ether;

    // Token ID types
    uint256 public constant NFT_TYPE_START = 0;
    uint256 public constant FUNGIBLE_TYPE_START = 1000000;

    mapping(uint256 => bool) public isNFT; // true if NFT, false if fungible
    mapping(address => bool) public hasMinted;

    event NFTMinted(address indexed to, uint256[] tokenIds);
    event FungibleMinted(address indexed to, uint256 tokenId, uint256 amount);

    constructor() ERC1155("https://api.example.com/metadata/{id}.json") Ownable(msg.sender) {
        currentTokenId = NFT_TYPE_START;
    }

    /**
     * @notice ✅ Mint único NFT (supply = 1)
     */
    function mintNFT() external payable nonReentrant {
        require(msg.value == PRICE, "Incorrect payment");
        require(!hasMinted[msg.sender], "Already minted");

        hasMinted[msg.sender] = true;

        uint256 newTokenId = currentTokenId++;
        isNFT[newTokenId] = true;

        _mint(msg.sender, newTokenId, 1, "");

        uint256[] memory ids = new uint256[](1);
        ids[0] = newTokenId;
        emit NFTMinted(msg.sender, ids);
    }

    /**
     * @notice ✅ BATCH MINT: Gas eficiente
     *
     * Ventaja de ERC-1155:
     * - Mintear 5 NFTs: ~90k gas
     * - vs ERC-721: ~566k gas
     * - vs ERC-721A: ~104k gas
     *
     * Ahorro: ~84% vs ERC-721, ~13% vs ERC-721A
     */
    function mintBatch(uint256 quantity) external payable nonReentrant {
        require(quantity > 0 && quantity <= 10, "Invalid quantity");
        require(msg.value == PRICE * quantity, "Incorrect payment");

        uint256[] memory ids = new uint256[](quantity);
        uint256[] memory amounts = new uint256[](quantity);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 newTokenId = currentTokenId++;
            isNFT[newTokenId] = true;
            ids[i] = newTokenId;
            amounts[i] = 1;
        }

        _mintBatch(msg.sender, ids, amounts, "");
        emit NFTMinted(msg.sender, ids);
    }

    /**
     * @notice ✅ BATCH TRANSFER: Operación nativa de ERC-1155
     *
     * Gas savings:
     * - 5 transfers: ~60k gas
     * - vs ERC-721: ~566k gas
     * - Ahorro: ~89%
     */
    function safeBatchTransfer(
        address to,
        uint256[] calldata tokenIds
    ) external nonReentrant {
        uint256[] memory amounts = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            amounts[i] = 1;
        }

        safeBatchTransferFrom(msg.sender, to, tokenIds, amounts, "");
    }

    /**
     * @notice Mint fungible tokens (para gaming, rewards, etc)
     */
    function mintFungible(uint256 tokenId, uint256 amount)
        external
        payable
        onlyOwner
    {
        require(tokenId >= FUNGIBLE_TYPE_START, "Invalid fungible token ID");
        require(!isNFT[tokenId], "Token is NFT");

        _mint(msg.sender, tokenId, amount, "");
        emit FungibleMinted(msg.sender, tokenId, amount);
    }

    /**
     * @notice Check if token is NFT or fungible
     */
    function tokenType(uint256 tokenId) external view returns (string memory) {
        if (isNFT[tokenId]) {
            return "NFT";
        } else if (tokenId >= FUNGIBLE_TYPE_START) {
            return "Fungible";
        } else {
            return "Unknown";
        }
    }
}

/**
 * @title SecureNFTMarketplace
 * @notice ✅ Marketplace con protección contra reentrancy
 *
 * Fixes aplicados:
 * 1. ✅ nonReentrant modifier en funciones críticas
 * 2. ✅ Checks-Effects-Interactions pattern
 * 3. ✅ Estado actualizado ANTES de external calls
 *
 * Protege contra:
 * - NFT Trader style attacks ($3M hack)
 * - Reentrancy en onERC721Received callback
 * - Multiple withdrawal attacks
 */
contract SecureNFTMarketplace is ReentrancyGuard {
    struct Offer {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Offer) public offers;
    uint256 public offerCount;

    event OfferCreated(uint256 indexed offerId, address seller, uint256 price);
    event OfferAccepted(uint256 indexed offerId, address buyer);
    event OfferCancelled(uint256 indexed offerId);

    /**
     * @notice Create an offer to sell an NFT
     */
    function createOffer(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external nonReentrant returns (uint256) {
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        uint256 offerId = offerCount++;
        offers[offerId] = Offer({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            active: true
        });

        emit OfferCreated(offerId, msg.sender, price);
        return offerId;
    }

    /**
     * @notice ✅ SECURE: Accept offer con protección contra reentrancy
     *
     * Cambios vs código vulnerable:
     * 1. ✅ nonReentrant modifier
     * 2. ✅ Offer marcada como inactive ANTES de external calls
     * 3. ✅ Checks-Effects-Interactions pattern
     *
     * Previene:
     * - Attacker no puede re-entrar porque offer.active = false
     * - Múltiples aceptaciones de la misma oferta imposibles
     */
    function acceptOffer(uint256 offerId) external payable nonReentrant {
        Offer storage offer = offers[offerId];

        // ✅ CHECKS: Validaciones
        require(offer.active, "Offer not active");
        require(msg.value == offer.price, "Incorrect payment");

        // ✅ EFFECTS: Update state BEFORE external calls
        offer.active = false;

        // ✅ INTERACTIONS: External calls al final
        IERC721(offer.nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            offer.tokenId
        );

        // Transfer payment
        payable(offer.seller).transfer(msg.value);

        emit OfferAccepted(offerId, msg.sender);
    }

    /**
     * @notice Cancel an offer
     */
    function cancelOffer(uint256 offerId) external nonReentrant {
        Offer storage offer = offers[offerId];
        require(offer.active, "Offer not active");
        require(offer.seller == msg.sender, "Not seller");

        offer.active = false;

        IERC721(offer.nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            offer.tokenId
        );

        emit OfferCancelled(offerId);
    }

    /**
     * @notice Get offer details
     */
    function getOffer(uint256 offerId) external view returns (Offer memory) {
        return offers[offerId];
    }
}

/**
 * @title ComposableNFT_ERC998
 * @notice 📝 Concepto de composable NFTs (aún en Draft desde 2018)
 *
 * Idea: NFTs que pueden "poseer" otros NFTs/tokens
 * - Parent NFT puede contener child NFTs
 * - Útil para gaming (character + items)
 * - Bundles de assets
 *
 * Problemas en EVM:
 * ⚠️ EIP-998 aún es Draft después de 7 años
 * ⚠️ Poca adopción (complejidad, gas costs)
 * ⚠️ No hay standard de facto
 * ⚠️ Difícil de implementar correctamente
 *
 * En Cadence esto es trivial con Resources anidados
 */
interface IERC998 {
    /**
     * @dev Transfer child token to parent NFT
     */
    function safeTransferChild(
        uint256 fromTokenId,
        address to,
        address childContract,
        uint256 childTokenId
    ) external;

    /**
     * @dev Get child contracts
     */
    function childContractsFor(uint256 tokenId)
        external
        view
        returns (address[] memory);
}
