;; realtor-registry-trait.clar
;; Trait definition for the realtor registry contract

(define-trait realtor-registry-trait
  (
    ;; Check if a realtor is active
    (is-active-realtor (principal) (response bool uint))
    
    ;; Get realtor information
    (get-realtor-info (principal) (response 
      {
        name: (string-utf8 100),
        license-number: (string-utf8 50),
        brokerage: (string-utf8 100),
        status: (string-utf8 20),
        profile-uri: (optional (string-utf8 256)),
        registration-block: uint
      } 
      uint))
  )
)
