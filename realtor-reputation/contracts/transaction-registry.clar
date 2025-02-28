;; transaction-registry.clar
;; This contract manages real estate transactions

;; Define the contract owner
(define-constant contract-owner tx-sender)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_REALTOR (err u401))
(define-constant ERR_INVALID_TRANSACTION (err u402))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_INPUT (err u405))

;; Data maps for transaction records
(define-map transactions
  { transaction-id: uint }
  {
    realtor: principal,
    property-address: (string-utf8 256),
    transaction-type: (string-utf8 20),
    transaction-amount: uint,
    transaction-date: uint,
    verified: bool,
    verification-block: (optional uint)
  }
)

;; Map to track a realtor's transactions
(define-map realtor-transactions
  { realtor: principal }
  { transaction-ids: (list 100 uint) }
)

;; Track total transaction count
(define-data-var transaction-count uint u0)

;; Read-only functions

;; Get transaction by ID
(define-read-only (get-transaction (transaction-id uint))
  (begin
    ;; Validate transaction-id
    (asserts! (> transaction-id u0) ERR_INVALID_INPUT)
    (ok (unwrap! (map-get? transactions {transaction-id: transaction-id}) ERR_NOT_FOUND))
  )
)

;; Get transactions for a realtor
(define-read-only (get-realtor-transactions (realtor principal))
  (ok (unwrap! (map-get? realtor-transactions {realtor: realtor}) ERR_NOT_FOUND))
)

;; Get verified transaction count for a realtor
(define-read-only (get-verified-transaction-count (realtor principal))
  (match (map-get? realtor-transactions {realtor: realtor})
    tx-list 
      (fold verified-count-helper (get transaction-ids tx-list) u0)
    u0
  )
)

;; Helper function to count verified transactions
(define-private (verified-count-helper (tx-id uint) (count uint))
  (match (map-get? transactions {transaction-id: tx-id})
    tx-data 
      (if (get verified tx-data)
          (+ count u1)
          count)
    count
  )
)

;; Add new transaction
(define-public (add-transaction 
                 (transaction-id uint) 
                 (property-address (string-utf8 256))
                 (transaction-type (string-utf8 20))
                 (transaction-amount uint)
                 (transaction-date uint))
  (let ((caller tx-sender))
    ;; Input validation
    (asserts! (> transaction-id u0) ERR_INVALID_INPUT)
    (asserts! (> (len property-address) u0) ERR_INVALID_INPUT)
    (asserts! (> (len transaction-type) u0) ERR_INVALID_INPUT)
    (asserts! (> transaction-amount u0) ERR_INVALID_INPUT)
    (asserts! (> transaction-date u0) ERR_INVALID_INPUT)
    
    ;; Check if caller is a valid realtor
    (asserts! (is-realtor caller) ERR_INVALID_REALTOR)
    (asserts! (is-none (map-get? transactions {transaction-id: transaction-id})) ERR_INVALID_TRANSACTION)
    
    ;; Now we can safely use the validated inputs
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
    
    ;; Update realtor's transaction list
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
    
    (var-set transaction-count (+ (var-get transaction-count) u1))
    (ok true)
  )
)

;; Helper function to check if a principal is a registered realtor
(define-private (is-realtor (realtor principal))
  ;; Implement a direct check here rather than an external call
  ;; This is a simplified version for demonstration
  true
)

;; Verify a transaction (admin function)
(define-public (verify-transaction (transaction-id uint))
  (begin
    ;; Validate transaction-id
    (asserts! (> transaction-id u0) ERR_INVALID_INPUT)
    
    ;; Authorization check
    (asserts! (is-eq tx-sender contract-owner) ERR_UNAUTHORIZED)
    
    ;; Update transaction verification status
    (match (map-get? transactions {transaction-id: transaction-id})
      tx-data 
        (ok (map-set transactions
              {transaction-id: transaction-id}
              (merge tx-data 
                     {
                       verified: true,
                       verification-block: (some block-height)
                     })
            ))
      ERR_NOT_FOUND
    )
  )
)
