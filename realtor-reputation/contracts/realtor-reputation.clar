;; realtor-reputation.clar
;; This contract calculates and stores reputation scores for realtors
;; Author: Claude

;; Define contract dependencies with proper principals
(use-trait realtor-registry-trait .realtor-registry-trait.realtor-registry-trait)
(use-trait transaction-registry-trait .transaction-registry-trait.transaction-registry-trait)
(use-trait review-registry-trait .review-registry-trait.review-registry-trait)

;; Contract references
(define-constant contract-owner tx-sender)
(define-constant realtor-registry-contract (as-contract (contract-call? .contract-manager get-contract-address "realtor-registry")))
(define-constant transaction-registry-contract (as-contract (contract-call? .contract-manager get-contract-address "transaction-registry")))
(define-constant review-registry-contract (as-contract (contract-call? .contract-manager get-contract-address "review-registry")))

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_REALTOR (err u401))
(define-constant ERR_CALCULATION_FAILED (err u402))

;; Constants for reputation calculation
(define-constant TRANSACTION_WEIGHT u60)  ;; 60% weight for transactions
(define-constant REVIEW_WEIGHT u40)       ;; 40% weight for reviews
(define-constant MAX_TRANSACTION_SCORE u100)
(define-constant MAX_REVIEW_SCORE u100)
(define-constant TRANSACTION_TIERS (list u5 u15 u30 u50 u75 u100))
(define-constant TRANSACTION_SCORES (list u10 u30 u50 u70 u90 u100))

;; Data maps

;; Reputation score data structure
(define-map reputation-scores
  { realtor: principal }
  {
    score: uint,
    transaction-component: uint,
    review-component: uint,
    verified-transactions: uint,
    average-rating: uint,
    last-updated: uint
  }
)

;; Read-only functions

;; Get transaction component score directly - using cond statement consistently
(define-read-only (get-transaction-component (tx-count uint))
  (cond
    (< tx-count (unwrap-panic (element-at TRANSACTION_TIERS u0))) (unwrap-panic (element-at TRANSACTION_SCORES u0))
    (< tx-count (unwrap-panic (element-at TRANSACTION_TIERS u1))) (unwrap-panic (element-at TRANSACTION_SCORES u1))
    (< tx-count (unwrap-panic (element-at TRANSACTION_TIERS u2))) (unwrap-panic (element-at TRANSACTION_SCORES u2))
    (< tx-count (unwrap-panic (element-at TRANSACTION_TIERS u3))) (unwrap-panic (element-at TRANSACTION_SCORES u3))
    (< tx-count (unwrap-panic (element-at TRANSACTION_TIERS u4))) (unwrap-panic (element-at TRANSACTION_SCORES u4))
    true (unwrap-panic (element-at TRANSACTION_SCORES u5))
  )
)

;; Get review component score directly
(define-read-only (get-review-component (avg-rating uint))
  (* (- avg-rating u1) u25)
)

;; Get reputation score for a realtor
(define-read-only (get-reputation-score (realtor principal))
  (map-get? reputation-scores {realtor: realtor})
)

;; Calculate and update reputation score for a realtor
(define-public (calculate-reputation-score (realtor principal) (registry-trait <realtor-registry-trait>) (tx-registry-trait <transaction-registry-trait>) (review-registry-trait <review-registry-trait>))
  (let (
    (is-realtor (contract-call? registry-trait is-active-realtor realtor))
  )
    (asserts! is-realtor ERR_INVALID_REALTOR)
    (let (
      (verified-tx-count (contract-call? tx-registry-trait get-verified-transaction-count realtor))
      (avg-rating-result (contract-call? review-registry-trait get-average-rating realtor))
    )
      
      ;; Calculate components
      (match avg-rating-result
        avg-rating-ok 
        (let (
          (avg-rating (unwrap! avg-rating-ok ERR_CALCULATION_FAILED))
          ;; Using cond for tx-component calculation to be consistent
          (tx-component (get-transaction-component verified-tx-count))
          ;; Inline review component calculation directly
          (review-component (get-review-component avg-rating))
        )
          
          ;; Calculate final score
          (let (
            (final-score (+ 
              (/ (* tx-component TRANSACTION_WEIGHT) u100)
              (/ (* review-component REVIEW_WEIGHT) u100)
            ))
          )
            
            ;; Store reputation score
            (map-set reputation-scores
              {realtor: realtor}
              {
                score: final-score,
                transaction-component: tx-component,
                review-component: review-component,
                verified-transactions: verified-tx-count,
                average-rating: avg-rating,
                last-updated: block-height
              }
            )
            
            (ok final-score)
          )
        )
        (err error-code) (err error-code)
      )
    )
  )
)
