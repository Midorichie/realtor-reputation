;; review-registry.clar
;; This contract manages client reviews for realtors
;; Author: Claude

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_REALTOR (err u301))
(define-constant ERR_INVALID_RATING (err u302))
(define-constant ERR_INVALID_REVIEW (err u303))
(define-constant ERR_INVALID_REVIEWER (err u304))
(define-constant ERR_NOT_TRANSACTION_PARTICIPANT (err u305))
(define-constant ERR_CALCULATION_FAILED (err u306))

;; Define contract owner constant
(define-constant contract-owner tx-sender)

;; Data maps

;; Review data structure
(define-map reviews
  { review-id: (string-utf8 64) }
  {
    realtor: principal,
    reviewer: principal,
    rating: uint,  ;; 1-5 stars
    comment: (string-utf8 1000),
    transaction-id: (optional (string-utf8 64)),
    review-date: uint,
    verified: bool
  }
)

;; Track reviews by realtor
(define-map realtor-reviews
  { realtor: principal }
  { review-ids: (list 100 (string-utf8 64)) }
)

;; Track review statistics by realtor
(define-map review-stats
  { realtor: principal }
  {
    total-reviews: uint,
    verified-reviews: uint,
    total-rating-sum: uint,
    verified-rating-sum: uint
  }
)

;; Variables
(define-data-var review-count uint u0)

;; Functions

;; Submit a review for a realtor
(define-public (submit-review
                (review-id (string-utf8 64))
                (realtor principal)
                (rating uint)
                (comment (string-utf8 1000))
                (transaction-id (optional (string-utf8 64))))
  (let ((caller tx-sender))
    ;; Verify realtor is registered and active
    (asserts! (contract-call? .realtor-registry is-active-realtor realtor) ERR_INVALID_REALTOR)
    
    ;; Verify rating is between 1-5
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    
    ;; Verify review doesn't already exist
    (asserts! (is-none (map-get? reviews {review-id: review-id})) ERR_INVALID_REVIEW)
    
    ;; If transaction ID provided, verify caller is a participant
    (if (is-some transaction-id)
      (asserts! (verify-transaction-participant 
                  realtor
                  caller
                  (unwrap! transaction-id ERR_INVALID_REVIEW))
                ERR_NOT_TRANSACTION_PARTICIPANT)
      true)
    
    ;; Store review data
    (map-set reviews
      {review-id: review-id}
      {
        realtor: realtor,
        reviewer: caller,
        rating: rating,
        comment: comment,
        transaction-id: transaction-id,
        review-date: block-height,
        verified: (is-some transaction-id)
      }
    )
    
    ;; Add to realtor's review list
    (match (map-get? realtor-reviews {realtor: realtor})
      existing-data (map-set realtor-reviews
                      {realtor: realtor}
                      {review-ids: (unwrap! (as-max-len? 
                                              (append (get review-ids existing-data) review-id)
                                              u100)
                                            ERR_UNAUTHORIZED)})
      ;; First review for this realtor
      (map-set realtor-reviews
        {realtor: realtor}
        {review-ids: (list review-id)}
      )
    )
    
    ;; Update review statistics
    (update-review-stats realtor rating (is-some transaction-id))
    
    ;; Increment review count
    (var-set review-count (+ (var-get review-count) u1))
    
    (ok true)
  )
)

;; Verify a review (admin only)
(define-public (verify-review
                (review-id (string-utf8 64)))
  (let ((caller tx-sender)
        (review-data (unwrap! (map-get? reviews {review-id: review-id}) ERR_INVALID_REVIEW)))
    
    ;; Only admin can verify reviews for now
    (asserts! (is-eq caller contract-owner) ERR_UNAUTHORIZED)
    
    ;; Only update if not already verified
    (if (not (get verified review-data))
      (begin
        ;; Update review to verified
        (map-set reviews
          {review-id: review-id}
          (merge review-data {verified: true})
        )
        
        ;; Update review stats
        (match (map-get? review-stats {realtor: (get realtor review-data)})
          existing-stats (map-set review-stats
                          {realtor: (get realtor review-data)}
                          (merge existing-stats 
                            {
                              verified-reviews: (+ (get verified-reviews existing-stats) u1),
                              verified-rating-sum: (+ (get verified-rating-sum existing-stats) (get rating review-data))
                            }
                          ))
          ;; Should not happen if review exists
          (err ERR_INVALID_REALTOR)
        )
      )
      true
    )
    
    (ok true)
  )
)

;; Private helper function to update review statistics
(define-private (update-review-stats (realtor principal) (rating uint) (verified bool))
  (match (map-get? review-stats {realtor: realtor})
    existing-stats (map-set review-stats
                    {realtor: realtor}
                    {
                      total-reviews: (+ (get total-reviews existing-stats) u1),
                      verified-reviews: (+ (get verified-reviews existing-stats) (if verified u1 u0)),
                      total-rating-sum: (+ (get total-rating-sum existing-stats) rating),
                      verified-rating-sum: (+ (get verified-rating-sum existing-stats) (if verified rating u0))
                    })
    ;; First review for this realtor
    (map-set review-stats
      {realtor: realtor}
      {
        total-reviews: u1,
        verified-reviews: (if verified u1 u0),
        total-rating-sum: rating,
        verified-rating-sum: (if verified rating u0)
      }
    )
  )
)

;; Helper function to verify if a user participated in a transaction
(define-private (verify-transaction-participant 
                 (realtor principal)
                 (reviewer principal)
                 (tx-id (string-utf8 64)))
  (match (contract-call? .transaction-registry get-transaction tx-id)
    tx-data (is-eq (get realtor tx-data) realtor)
    false
  )
)

;; Read-only functions

;; Get review details
(define-read-only (get-review (review-id (string-utf8 64)))
  (map-get? reviews {review-id: review-id})
)

;; Get all reviews for a realtor
(define-read-only (get-realtor-review-ids (realtor principal))
  (match (map-get? realtor-reviews {realtor: realtor})
    existing-data (get review-ids existing-data)
    (list)
  )
)

;; Get review statistics for a realtor
(define-read-only (get-review-stats (realtor principal))
  (map-get? review-stats {realtor: realtor})
)

;; Get total number of reviews
(define-read-only (get-review-count)
  (var-get review-count)
)

;; Get average rating for a realtor (considers all reviews)
(define-read-only (get-average-rating (realtor principal))
  (match (map-get? review-stats {realtor: realtor})
    stats (if (> (get total-reviews stats) u0)
            (ok (/ (get total-rating-sum stats) (get total-reviews stats)))
            (err ERR_CALCULATION_FAILED))
    (err ERR_CALCULATION_FAILED)
  )
)

;; Get verified average rating for a realtor (considers only verified reviews)
(define-read-only (get-verified-average-rating (realtor principal))
  (match (map-get? review-stats {realtor: realtor})
    stats (if (> (get verified-reviews stats) u0)
            (ok (/ (get verified-rating-sum stats) (get verified-reviews stats)))
            (err ERR_CALCULATION_FAILED))
    (err ERR_CALCULATION_FAILED)
  )
)
