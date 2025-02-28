;; review-registry.clar
;; This contract manages reviews for realtors

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INVALID_REALTOR (err u401))
(define-constant ERR_INVALID_RATING (err u402))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_INPUT (err u405))

;; Data maps for reviews
(define-map reviews
  { review-id: uint }
  {
    realtor: principal,
    reviewer: principal,
    rating: uint,  ;; 1-5 rating
    transaction-id: (optional uint),
    comment: (optional (string-utf8 500)),
    review-date: uint,
    verified: bool
  }
)

;; Map to track realtor's reviews
(define-map realtor-reviews
  { realtor: principal }
  { review-ids: (list 100 uint) }
)

;; Track total review count
(define-data-var review-count uint u0)

;; Read-only functions

;; Get a review by ID
(define-read-only (get-review (review-id uint))
  (begin
    ;; Validate review-id
    (asserts! (> review-id u0) ERR_INVALID_INPUT)
    (ok (unwrap! (map-get? reviews {review-id: review-id}) ERR_NOT_FOUND))
  )
)

;; Get reviews for a realtor
(define-read-only (get-realtor-reviews (realtor principal))
  (ok (unwrap! (map-get? realtor-reviews {realtor: realtor}) ERR_NOT_FOUND))
)

;; Calculate average rating for a realtor
(define-read-only (get-average-rating (realtor principal))
  (match (map-get? realtor-reviews {realtor: realtor})
    review-list
      (let ((result (fold rating-sum-helper (get review-ids review-list) {sum: u0, count: u0})))
        (if (> (get count result) u0)
            (ok (/ (+ (get sum result) (/ (get count result) u2)) (get count result)))
            (ok u0)))
    (ok u0)
  )
)

;; Helper function to sum ratings
(define-private (rating-sum-helper (review-id uint) (result {sum: uint, count: uint}))
  (match (map-get? reviews {review-id: review-id})
    review-data 
      {
        sum: (+ (get sum result) (get rating review-data)),
        count: (+ (get count result) u1)
      }
    result
  )
)

;; Add new review
(define-public (add-review 
                 (review-id uint) 
                 (realtor principal)
                 (rating uint)
                 (transaction-id (optional uint))
                 (comment (optional (string-utf8 500))))
  (let ((caller tx-sender))
    ;; Input validation
    (asserts! (> review-id u0) ERR_INVALID_INPUT)
    ;; Verify rating is between 1-5
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    ;; Check comment if provided
    (asserts! (match comment
                some-comment (> (len some-comment) u0)
                true)
              ERR_INVALID_INPUT)
    ;; Check transaction-id if provided
    (asserts! (match transaction-id
                some-tx-id (> some-tx-id u0)
                true)
              ERR_INVALID_INPUT)
              
    ;; Verify realtor is valid - modified to simplify
    (asserts! (is-valid-realtor realtor) ERR_INVALID_REALTOR)
    ;; Verify transaction if provided - modified to simplify
    (asserts! (match transaction-id
                some-tx-id (verify-transaction some-tx-id realtor)
                true)
              ERR_INVALID_REALTOR)
              
    ;; Store the review
    (map-set reviews
      {review-id: review-id}
      {
        realtor: realtor,
        reviewer: caller,
        rating: rating,
        transaction-id: transaction-id,
        comment: comment,
        review-date: block-height,
        verified: false
      }
    )
    
    ;; Update realtor's review list
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
    
    (var-set review-count (+ (var-get review-count) u1))
    (ok true)
  )
)

;; Helper function to verify transaction belongs to a realtor
(define-private (verify-transaction (tx-id uint) (realtor principal))
  ;; Simplified implementation that doesn't rely on external contracts
  true
)

;; Helper function to check if a principal is a registered realtor
(define-private (is-valid-realtor (realtor principal))
  ;; Simplified implementation
  true
)
