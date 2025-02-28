;; transaction-registry-trait.clar
;; Trait definition for the transaction registry contract

(define-trait transaction-registry-trait
  (
    ;; Get a transaction by ID
    (get-transaction (uint) (response {
      realtor: principal,
      property-address: (string-utf8 256),
      transaction-type: (string-utf8 20),
      transaction-amount: uint,
      transaction-date: uint,
      verified: bool,
      verification-block: (optional uint)
    } uint))
    
    ;; Get verified transaction count for a realtor
    (get-verified-transaction-count (principal) (response uint uint))
  )
)
