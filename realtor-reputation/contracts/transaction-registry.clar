;; transaction-registry.clar
;; This contract records verified real estate transactions
;; Author: Claude

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_REALTOR (err u201))
(define-constant ERR_INVALID_TRANSACTION (err u202))
(define-constant ERR_ALREADY_VERIFIED (err u203))

;; Define contract owner constant
(define-constant contract-owner tx-sender)

;; Data maps

;; Transaction data structure
(define-map transactions
  { transaction-id: (string-utf8 64) }
  {
    realtor: principal,
    property-address: (string-utf8 256),
    transaction-type: (string-utf8 20), ;; "sale", "purchase", "rental"
    transaction-amount: uint,
    transaction-date: uint,
    verified: bool,
    verification-block: (optional uint)
  }
)

;; Track transactions by realtor
(define-map realtor-transactions
  { realtor: principal }
  { transaction-ids: (list 100 (string-utf8 64)) }
)

;; Variables
(define-data-var transaction-count uint u0)

;; Functions

;; Register a new real estate transaction
(define-public (register-transaction
                (transaction-id (string-utf8 64))
                (property-address (string-utf8 256))
                (transaction-type (string-utf8 20))
                (transaction-amount uint)
                (transaction-date uint))
  (let ((caller tx-sender))
    ;; Verify caller is a registered realtor
    (asserts! (contract-call? .realtor-registry is-active-realtor caller) ERR_INVALID_REALTOR)
    
    ;; Verify transaction doesn't already exist
    (asserts! (is-none (map-get? transactions {transaction-id: transaction-id})) ERR_INVALID_TRANSACTION)
    
    ;; Store transaction data
    (map-set transactions
      {transaction-id: transaction-id}
      {
        realtor: caller,
        property-address: property-address,
        transaction-type: transaction-type,
        transaction-amount: transaction-amount,
        transaction-date: transaction-date,
        verified: false,
        verification-block: none
      }
    )
    
    ;; Add to realtor's transaction list
    (match (map-get? realtor-transactions {realtor: caller})
      existing-data (map-set realtor-transactions
                      {realtor: caller}
                      {transaction-ids: (unwrap! (as-max-len? 
                                                    (append (get transaction-ids existing-data) transaction-id)
                                                    u100)
                                                  ERR_UNAUTHORIZED)})
      ;; First transaction for this realtor
      (map-set realtor-transactions
        {realtor: caller}
        {transaction-ids: (list transaction-id)}
      )
    )
    
    ;; Increment transaction count
    (var-set transaction-count (+ (var-get transaction-count) u1))
    
    (ok true)
  )
)

;; Verify a transaction (by admin or third-party verifier)
(define-public (verify-transaction
                (transaction-id (string-utf8 64)))
  (let ((caller tx-sender)
        (tx-data (unwrap! (map-get? transactions {transaction-id: transaction-id}) ERR_INVALID_TRANSACTION)))
    
    ;; Only admin can verify transactions for now
    (asserts! (is-eq caller contract-owner) ERR_UNAUTHORIZED)
    
    ;; Check if already verified
    (asserts! (not (get verified tx-data)) ERR_ALREADY_VERIFIED)
    
    ;; Update transaction to verified
    (map-set transactions
      {transaction-id: transaction-id}
      (merge tx-data 
        {
          verified: true,
          verification-block: (some block-height)
        }
      )
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get transaction details
(define-read-only (get-transaction (transaction-id (string-utf8 64)))
  (map-get? transactions {transaction-id: transaction-id})
)

;; Get all transactions for a realtor
(define-read-only (get-realtor-transaction-ids (realtor principal))
  (match (map-get? realtor-transactions {realtor: realtor})
    existing-data (get transaction-ids existing-data)
    (list)
  )
)

;; Get total number of transactions
(define-read-only (get-transaction-count)
  (var-get transaction-count)
)

;; Get verified transaction count for a realtor
(define-read-only (get-verified-transaction-count (realtor principal))
  (fold count-if-verified 
        u0
        (get-realtor-transaction-ids realtor))
)

;; Helper function to count verified transactions
(define-private (count-if-verified (id (string-utf8 64)) (count uint))
  (match (map-get? transactions {transaction-id: id})
    tx-data (if (get verified tx-data)
              (+ count u1)
              count)
    count
  )
)
