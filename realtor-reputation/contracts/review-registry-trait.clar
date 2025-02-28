;; review-registry-trait.clar
;; Trait definition for the review registry contract

(define-trait review-registry-trait
  (
    ;; Get average rating for a realtor
    (get-average-rating (principal) (response uint uint))
  )
)
