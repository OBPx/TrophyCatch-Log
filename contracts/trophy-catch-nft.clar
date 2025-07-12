;; trophy-catch-nft.clar
;; This contract allows certified guides to mint non-fungible tokens (NFTs)
;; that represent verified trophy catches for anglers.
;; It serves as an immutable, on-chain record of significant fishing achievements.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants and Contract Owner
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED u101)
(define-constant ERR_GUIDE_NOT_CERTIFIED u102)
(define-constant ERR_ALREADY_CERTIFIED u103)
(define-constant ERR_MINTING_FAILED u104)
(define-constant ERR_NFT_NOT_FOUND u105)
(define-constant ERR_SENDER_NOT_OWNER u106)
(define-constant ERR_METADATA_LOCKED u107)
(define-constant ERR_METADATA_INVALID u108)
(define-constant ERR_INVALID_WEIGHT u109)
(define-constant ERR_INVALID_LENGTH u110)
(define-constant ERR_INVALID_RECIPIENT u111)

;; Validation constants
(define-constant MAX_WEIGHT_GRAMS u1000000) ;; 1000kg max
(define-constant MAX_LENGTH_CM u1000) ;; 10 meters max
(define-constant MIN_WEIGHT_GRAMS u1) ;; 1 gram min
(define-constant MIN_LENGTH_CM u1) ;; 1 cm min

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Data Storage
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Define the NFT for Trophy Catches
(define-non-fungible-token trophy-catch uint)

;; Map to store certified guide principals
(define-map certified-guides principal bool)

;; Map to store metadata for each trophy catch NFT
(define-map trophy-metadata uint {
  species: (string-ascii 32),
  weight-grams: uint,
  length-cm: uint,
  catch-location: (string-ascii 64),
  angler-note: (string-utf8 256),
  media-url: (string-ascii 128),
  verified-guide: principal
})

;; Map to track NFT count per owner for efficient querying
(define-map owner-nft-count principal uint)

;; Variable to track the last token ID
(define-data-var last-token-id uint u0)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Administrative Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --- Certify a new guide ---
;; Only the contract owner can certify a new guide.
;; Certified guides are authorized to mint trophy catch NFTs.
(define-public (certify-guide (guide principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-none (map-get? certified-guides guide)) (err ERR_ALREADY_CERTIFIED))
    (ok (map-set certified-guides guide true))
  )
)

;; --- Decertify a guide ---
;; Only the contract owner can remove a guide's certification.
(define-public (decertify-guide (guide principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_NOT_AUTHORIZED))
    (asserts! (is-some (map-get? certified-guides guide)) (err ERR_GUIDE_NOT_CERTIFIED))
    (ok (map-delete certified-guides guide))
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helper Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --- Update owner NFT count ---
;; Internal function to maintain accurate NFT counts per owner
(define-private (update-owner-count (owner principal) (increment bool))
  (let ((current-count (default-to u0 (map-get? owner-nft-count owner))))
    (if increment
      (map-set owner-nft-count owner (+ current-count u1))
      (if (> current-count u0)
        (map-set owner-nft-count owner (- current-count u1))
        (map-delete owner-nft-count owner)
      )
    )
  )
)

;; --- Validate input parameters ---
(define-private (validate-trophy-data (species (string-ascii 32)) (weight-grams uint) (length-cm uint) (catch-location (string-ascii 64)) (media-url (string-ascii 128)))
  (begin
    (asserts! (> (len species) u0) (err ERR_METADATA_INVALID))
    (asserts! (> (len media-url) u0) (err ERR_METADATA_INVALID))
    (asserts! (> (len catch-location) u0) (err ERR_METADATA_INVALID))
    (asserts! (and (>= weight-grams MIN_WEIGHT_GRAMS) (<= weight-grams MAX_WEIGHT_GRAMS)) (err ERR_INVALID_WEIGHT))
    (asserts! (and (>= length-cm MIN_LENGTH_CM) (<= length-cm MAX_LENGTH_CM)) (err ERR_INVALID_LENGTH))
    (ok true)
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --- Mint a new Trophy Catch NFT ---
;; A certified guide can mint a new trophy NFT and assign it to an angler.
(define-public (mint-trophy (angler principal) (species (string-ascii 32)) (weight-grams uint) (length-cm uint) (catch-location (string-ascii 64)) (angler-note (string-utf8 256)) (media-url (string-ascii 128)))
  (let
    ((guide tx-sender)
     (is-certified (default-to false (map-get? certified-guides guide))))

    (asserts! is-certified (err ERR_GUIDE_NOT_CERTIFIED))
    (unwrap! (validate-trophy-data species weight-grams length-cm catch-location media-url) (err ERR_METADATA_INVALID))

    (let ((token-id (+ (var-get last-token-id) u1)))
      (match (nft-mint? trophy-catch token-id angler)
        success (begin
          (map-set trophy-metadata token-id {
            species: species,
            weight-grams: weight-grams,
            length-cm: length-cm,
            catch-location: catch-location,
            angler-note: angler-note,
            media-url: media-url,
            verified-guide: guide
          })
          (update-owner-count angler true)
          (var-set last-token-id token-id)
          (ok token-id)
        )
        error (err ERR_MINTING_FAILED)
      )
    )
  )
)

;; --- Transfer a Trophy NFT ---
;; The owner of an NFT can transfer it to another principal.
(define-public (transfer-trophy (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_NOT_AUTHORIZED))
    (asserts! (not (is-eq sender recipient)) (err ERR_INVALID_RECIPIENT))
    (asserts! (is-some (nft-get-owner? trophy-catch token-id)) (err ERR_NFT_NOT_FOUND))
    (asserts! (is-eq (some sender) (nft-get-owner? trophy-catch token-id)) (err ERR_SENDER_NOT_OWNER))

    (match (nft-transfer? trophy-catch token-id sender recipient)
      success (begin
        (update-owner-count sender false)
        (update-owner-count recipient true)
        (ok success)
      )
      error (err error)
    )
  )
)

;; --- Update Angler's Note ---
;; The current owner of the trophy NFT can update the personal note.
;; Other metadata remains locked to preserve the integrity of the catch record.
(define-public (update-angler-note (token-id uint) (new-note (string-utf8 256)))
  (let
    ((current-owner (unwrap! (nft-get-owner? trophy-catch token-id) (err ERR_NFT_NOT_FOUND)))
     (current-metadata (unwrap! (map-get? trophy-metadata token-id) (err ERR_NFT_NOT_FOUND))))

    (asserts! (is-eq tx-sender current-owner) (err ERR_SENDER_NOT_OWNER))

    (map-set trophy-metadata token-id (merge current-metadata { angler-note: new-note }))
    (ok true)
  )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Read-Only Functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --- Get Trophy Metadata ---
;; Returns all metadata associated with a specific trophy NFT.
(define-read-only (get-trophy-details (token-id uint))
  (map-get? trophy-metadata token-id)
)

;; --- Get NFT Owner ---
;; Returns the owner of a specific trophy NFT.
(define-read-only (get-owner (token-id uint))
  (nft-get-owner? trophy-catch token-id)
)

;; --- Check if a guide is certified ---
(define-read-only (is-guide-certified (guide principal))
  (is-some (map-get? certified-guides guide))
)

;; --- Get the total number of trophies minted ---
(define-read-only (get-last-token-id)
  (var-get last-token-id)
)

;; --- Get the NFT count of a specific owner ---
;; Returns the number of trophy NFTs owned by a principal
(define-read-only (get-balance (owner principal))
  (default-to u0 (map-get? owner-nft-count owner))
)

;; --- Get contract owner ---
;; Returns the contract owner principal
(define-read-only (get-contract-owner)
  CONTRACT_OWNER
)

;; --- Get validation constants ---
;; Returns the validation limits for trophy data
(define-read-only (get-validation-limits)
  {
    max-weight-grams: MAX_WEIGHT_GRAMS,
    min-weight-grams: MIN_WEIGHT_GRAMS,
    max-length-cm: MAX_LENGTH_CM,
    min-length-cm: MIN_LENGTH_CM
  }
)