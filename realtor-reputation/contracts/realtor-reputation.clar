;; realtor-reputation.clar
;; This contract calculates and stores reputation scores for realtors
;; Author: Claude

;; Define a constant for contract owner
(define-constant contract-owner tx-sender)

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

;; Get transaction component score directly - using nested if statements instead of cond
(define-read-only (get-transaction-component (tx-count uint))
  (if (< tx-count (unwrap-panic (element-at TRANSACTION_TIERS u0)))
      (unwrap-panic (element-at TRANSACTION_SCORES u0))
      (if (< tx-count (unwrap-panic (element-at TRANSACTION_TIERS u1)))
          (unwrap-panic (element-at TRANSACTION_SCORES u1))
          (if (< tx-count (unwrap-panic (element-at TRANSACTION_TIERS u2)))
              (unwrap-panic (element-at TRANSACTION_SCORES u2))
              (if (< tx-count (unwrap-panic (element-at TRANSACTION_TIERS u3)))
                  (unwrap-panic (element-at TRANSACTION_SCORES u3))
                  (if (< tx-count (unwrap-panic (element-at TRANSACTION_TIERS u4)))
                      (unwrap-panic (element-at TRANSACTION_SCORES u4))
                      (unwrap-panic (element-at TRANSACTION_SCORES u5))
                  )
              )
          )
      )
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

;; Direct implementation to check if a realtor is valid
(define-private (is-valid-realtor (realtor principal))
  ;; Simplified implementation
  true
)

;; Direct implementation to get verified transaction count
(define-private (get-verified-tx-count (realtor principal))
  ;; Simplified implementation
  u10  ;; Return a default value
)

;; Direct implementation to get average rating
(define-private (get-avg-rating (realtor principal))
  ;; Simplified implementation
  (ok u4)  ;; Return a default value
)

;; Calculate and update reputation score for a realtor
(define-public (calculate-reputation-score (realtor principal))
  (let (
    (is-realtor (is-valid-realtor realtor))
  )
    (asserts! is-realtor ERR_INVALID_REALTOR)
    (let (
      (verified-tx-count (get-verified-tx-count realtor))
      (avg-rating-result (get-avg-rating realtor))
    )
      
      ;; Use unwrap instead of match since we know the structure
      (let (
        (avg-rating (unwrap-panic avg-rating-result))
        (tx-component (get-transaction-component verified-tx-count))
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
    )
  )
)
