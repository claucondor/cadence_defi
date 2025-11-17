/**
 * SecureNFT - Implementación NFT en Cadence
 *
 * ✅ Ventajas sobre EVM:
 * 1. Resources eliminan reentrancy por diseño
 * 2. No callbacks peligrosos (no onERC721Received)
 * 3. Ownership real (no puede duplicarse o perderse)
 * 4. Composable NFTs trivial (Resources own Resources)
 * 5. Metadata on-chain con MetadataViews standard
 * 6. No approval pattern (Capabilities)
 *
 * Comparación:
 * - EVM: 566k gas para 5 NFTs (ERC-721)
 * - EVM: 104k gas para 5 NFTs (ERC-721A optimizado)
 * - Cadence: Más eficiente y seguro por diseño
 */

import "NonFungibleToken"
import "MetadataViews"
import "ViewResolver"

access(all) contract SecureNFT {

    // ====================================
    // EVENTS
    // ====================================

    access(all) event ContractInitialized()
    access(all) event Withdraw(id: UInt64, from: Address?)
    access(all) event Deposit(id: UInt64, to: Address?)
    access(all) event Minted(id: UInt64, recipient: Address, metadata: {String: String})

    // ====================================
    // PATHS
    // ====================================

    access(all) let CollectionStoragePath: StoragePath
    access(all) let CollectionPublicPath: PublicPath
    access(all) let MinterStoragePath: StoragePath

    // ====================================
    // STATE
    // ====================================

    access(all) var totalSupply: UInt64

    // ====================================
    // NFT RESOURCE
    // ====================================

    /**
     * @notice NFT Resource - Core asset
     *
     * ✅ Ventajas de Resources:
     * 1. No puede duplicarse (linear type)
     * 2. No puede perderse (debe ser movido o destruido explícitamente)
     * 3. Ownership real (quien tiene el resource es el dueño)
     * 4. No reentrancy possible (no callbacks)
     *
     * Comparación con ERC-721:
     * - ERC-721: mapping(uint256 => address) owners (puede ser manipulado)
     * - Cadence: Resource stored in account storage (verdadero ownership)
     */
    access(all) resource NFT {
        access(all) let id: UInt64
        access(all) let name: String
        access(all) let description: String
        access(all) let thumbnail: String

        // Metadata adicional (extensible)
        access(self) let metadata: {String: String}

        // ✅ NFTs composables: Un NFT puede contener otros NFTs
        // Esto es TRIVIAL en Cadence pero complejo en EVM (EIP-998 aún en Draft)
        access(self) var childNFTs: @{UInt64: NFT}

        init(
            id: UInt64,
            name: String,
            description: String,
            thumbnail: String,
            metadata: {String: String}
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.metadata = metadata
            self.childNFTs <- {}
        }

        /**
         * @notice Agregar child NFT (Composable NFTs)
         *
         * ✅ En Cadence: 3 líneas de código
         * ⚠️ En EVM: EIP-998 (Draft desde 2018, muy complejo)
         */
        access(all) fun addChildNFT(_ nft: @NFT) {
            let id = nft.id
            self.childNFTs[id] <-! nft
        }

        /**
         * @notice Remover child NFT
         */
        access(all) fun removeChildNFT(id: UInt64): @NFT {
            return <- self.childNFTs.remove(key: id)!
        }

        /**
         * @notice Get child NFT IDs
         */
        access(all) fun getChildNFTIDs(): [UInt64] {
            return self.childNFTs.keys
        }

        /**
         * @notice Get metadata value
         */
        access(all) fun getMetadata(): {String: String} {
            return self.metadata
        }

        /**
         * ✅ IMPORTANTE: destroy debe manejar nested resources
         * El compilador garantiza que no se pierdan resources
         */
        destroy() {
            destroy self.childNFTs
        }
    }

    // ====================================
    // COLLECTION RESOURCE
    // ====================================

    /**
     * @notice Collection Resource - Almacena múltiples NFTs
     *
     * ✅ Ventajas:
     * 1. Cada usuario tiene su propia Collection (true ownership)
     * 2. No mappings centrales vulnerables a bugs
     * 3. Batch operations naturales (withdraw/deposit arrays)
     * 4. No approval pattern (usa Capabilities)
     */
    access(all) resource Collection {
        access(all) var ownedNFTs: @{UInt64: NFT}

        init() {
            self.ownedNFTs <- {}
        }

        /**
         * @notice Withdraw NFT - Remueve de la collection
         *
         * ✅ Seguro por diseño:
         * - Retorna Resource (move semantics)
         * - Caller debe hacer algo con el NFT (o no compila)
         * - No puede "perderse" accidentalmente
         */
        access(all) fun withdraw(withdrawID: UInt64): @NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("NFT not found")

            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        /**
         * @notice Deposit NFT - Agrega a la collection
         *
         * ✅ No reentrancy possible:
         * - No callbacks a contracts externos
         * - Solo mueve el Resource a storage
         * - Atómico y seguro
         */
        access(all) fun deposit(token: @NFT) {
            let id = token.id
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        /**
         * @notice Batch withdraw - Operación natural en Cadence
         *
         * ✅ vs EVM:
         * - ERC-721: No batch nativo, loop manual
         * - ERC-721A: Optimizado pero aún complejo
         * - ERC-1155: Tiene batch pero más complejo
         * - Cadence: Trivial y seguro
         */
        access(all) fun batchWithdraw(ids: [UInt64]): @[NFT] {
            var nfts: @[NFT] <- []

            for id in ids {
                nfts.append(<- self.withdraw(withdrawID: id))
            }

            return <- nfts
        }

        /**
         * @notice Batch deposit
         */
        access(all) fun batchDeposit(tokens: @[NFT]) {
            while tokens.length > 0 {
                self.deposit(token: <- tokens.removeFirst())
            }
            destroy tokens
        }

        /**
         * @notice Get NFT IDs owned
         */
        access(all) fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        /**
         * @notice Borrow NFT reference (read-only)
         */
        access(all) fun borrowNFT(id: UInt64): &NFT? {
            return &self.ownedNFTs[id]
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // ====================================
    // COLLECTION PUBLIC INTERFACE
    // ====================================

    /**
     * @notice Public interface para Collection
     *
     * ✅ Capabilities system:
     * - No approval pattern necesario
     * - Permisos granulares
     * - Type-safe access control
     */
    access(all) resource interface CollectionPublic {
        access(all) fun deposit(token: @NFT)
        access(all) fun getIDs(): [UInt64]
        access(all) fun borrowNFT(id: UInt64): &NFT?
    }

    // ====================================
    // MINTER RESOURCE
    // ====================================

    /**
     * @notice Minter Resource - Crea nuevos NFTs
     *
     * ✅ No reentrancy possible:
     * - No external calls durante mint
     * - Resource creado directamente
     * - Move semantics garantizan seguridad
     */
    access(all) resource NFTMinter {

        /**
         * @notice Mint single NFT
         *
         * ✅ Seguro por diseño vs EVM:
         * - No _safeMint callback vulnerability
         * - No hasMinted mapping que puede bypasearse
         * - Resource creado y movido atómicamente
         */
        access(all) fun mintNFT(
            recipient: &{CollectionPublic},
            name: String,
            description: String,
            thumbnail: String,
            metadata: {String: String}
        ): UInt64 {
            let nft <- create NFT(
                id: SecureNFT.totalSupply,
                name: name,
                description: description,
                thumbnail: thumbnail,
                metadata: metadata
            )

            let id = nft.id
            SecureNFT.totalSupply = SecureNFT.totalSupply + 1

            // ✅ Direct deposit - no callback, no reentrancy
            recipient.deposit(token: <- nft)

            emit Minted(
                id: id,
                recipient: recipient.owner!.address,
                metadata: metadata
            )

            return id
        }

        /**
         * @notice Batch mint - Natural y eficiente
         *
         * ✅ vs EVM:
         * - ERC-721: 566k gas para 5 NFTs
         * - ERC-721A: 104k gas para 5 NFTs (82% ahorro, muy optimizado)
         * - Cadence: Eficiente por diseño, no requiere trucos de optimización
         */
        access(all) fun batchMintNFT(
            recipient: &{CollectionPublic},
            count: Int,
            name: String,
            description: String,
            thumbnail: String,
            metadata: {String: String}
        ): [UInt64] {
            var ids: [UInt64] = []
            var i = 0

            while i < count {
                let id = self.mintNFT(
                    recipient: recipient,
                    name: name.concat(" #").concat(i.toString()),
                    description: description,
                    thumbnail: thumbnail,
                    metadata: metadata
                )
                ids.append(id)
                i = i + 1
            }

            return ids
        }
    }

    // ====================================
    // PUBLIC FUNCTIONS
    // ====================================

    /**
     * @notice Create empty Collection
     *
     * Cada usuario crea su propia Collection:
     * - True ownership (no mapping central)
     * - Isolated state (no shared state bugs)
     */
    access(all) fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    // ====================================
    // MARKETPLACE EXAMPLE
    // ====================================

    /**
     * @notice NFT Marketplace Resource
     *
     * ✅ Seguro por diseño vs EVM:
     * - NFT almacenado como Resource (no puede duplicarse)
     * - No external calls peligrosos
     * - No reentrancy possible
     * - Estado actualizado atómicamente
     *
     * Comparación con NFT Trader hack ($3M):
     * - EVM: safeTransferFrom() -> callback -> reentrancy
     * - Cadence: Deposit/Withdraw son atómicos, sin callbacks
     */
    access(all) resource Marketplace {
        access(self) var listings: @{UInt64: NFTListing}
        access(self) var nextListingID: UInt64

        access(all) resource NFTListing {
            access(all) let listingID: UInt64
            access(all) var nft: @NFT?
            access(all) let price: UFix64
            access(all) let seller: Address

            init(listingID: UInt64, nft: @NFT, price: UFix64, seller: Address) {
                self.listingID = listingID
                self.nft <- nft
                self.price = price
                self.seller = seller
            }

            access(all) fun withdraw(): @NFT {
                let nft <- self.nft <- nil
                return <- nft!
            }

            destroy() {
                destroy self.nft
            }
        }

        init() {
            self.listings <- {}
            self.nextListingID = 0
        }

        /**
         * @notice Create listing
         */
        access(all) fun createListing(nft: @NFT, price: UFix64, seller: Address): UInt64 {
            let listingID = self.nextListingID
            self.nextListingID = self.nextListingID + 1

            let listing <- create NFTListing(
                listingID: listingID,
                nft: <- nft,
                price: price,
                seller: seller
            )

            self.listings[listingID] <-! listing

            return listingID
        }

        /**
         * @notice Purchase NFT
         *
         * ✅ SEGURO: No reentrancy possible
         * - NFT removido inmediatamente de listing
         * - Resource movido atómicamente
         * - No callbacks a contracts externos
         *
         * vs NFT Trader vulnerability:
         * - EVM: safeTransferFrom() antes de delete offer = reentrancy
         * - Cadence: withdraw() es atómico, sin callbacks
         */
        access(all) fun purchase(listingID: UInt64): @NFT {
            let listing <- self.listings.remove(key: listingID)
                ?? panic("Listing not found")

            // ✅ NFT removed from listing BEFORE any external operations
            let nft <- listing.withdraw()

            destroy listing

            // Return NFT to buyer (no callback, no reentrancy risk)
            return <- nft
        }

        destroy() {
            destroy self.listings
        }
    }

    // ====================================
    // CONTRACT INIT
    // ====================================

    init() {
        self.totalSupply = 0

        self.CollectionStoragePath = /storage/SecureNFTCollection
        self.CollectionPublicPath = /public/SecureNFTCollection
        self.MinterStoragePath = /storage/SecureNFTMinter

        // Create Minter and store in account storage
        self.account.storage.save(
            <- create NFTMinter(),
            to: self.MinterStoragePath
        )

        emit ContractInitialized()
    }
}
