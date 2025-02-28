;; realtor-registry.clar
;; This contract manages realtor information and registration
 
;; Define a constant for contract owner
(define-constant contract-owner tx-sender)
;; Error codes
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_ALREADY_REGISTERED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_INVALID_INPUT (err u405))
 
;; Data maps to store realtor information
(define-map realtors
  { realtor: principal }
  {
    name: (string-utf8 100),
    license-number: (string-utf8 50),
    brokerage: (string-utf8 100),
    status: (string-utf8 20),
    profile-uri: (optional (string-utf8 256)),
    registration-block: uint
  }
)
 
;; Count of registered realtors
(define-data-var realtor-count uint u0)
 
;; Read-only functions
 
;; Check if a realtor is active
(define-read-only (is-active-realtor (realtor principal))
  (match (map-get? realtors {realtor: realtor})
    realtor-data (is-eq (get status realtor-data) u"ACTIVE")
    false
  )
)
 
;; Get realtor information
(define-read-only (get-realtor-info (realtor principal))
  (ok (unwrap! (map-get? realtors {realtor: realtor}) ERR_NOT_FOUND))
)
 
;; Register a new realtor
(define-public (register-realtor (name (string-utf8 100))
                              (license-number (string-utf8 50))
                              (brokerage (string-utf8 100))
                              (profile-uri (optional (string-utf8 256))))
  (let ((caller tx-sender))
    ;; Input validation
    (asserts! (> (len name) u0) ERR_INVALID_INPUT)
    (asserts! (> (len license-number) u0) ERR_INVALID_INPUT)
    (asserts! (> (len brokerage) u0) ERR_INVALID_INPUT)
    (asserts! (match profile-uri
                some-uri (> (len some-uri) u0)
                true)
              ERR_INVALID_INPUT)
              
    ;; Check if already registered
    (asserts! (is-none (map-get? realtors {realtor: caller})) ERR_ALREADY_REGISTERED)
   
    ;; Now we can safely use the validated inputs
    (map-set realtors
      {realtor: caller}
      {
        name: name,
        license-number: license-number,
        brokerage: brokerage,
        status: u"ACTIVE",
        profile-uri: profile-uri,
        registration-block: block-height
      }
    )
   
    (var-set realtor-count (+ (var-get realtor-count) u1))
    (ok true)
  )
)
 
;; Update realtor status
(define-public (update-status (realtor principal) (new-status (string-utf8 20)))
  (begin
    ;; Input validation for new-status
    (asserts! (> (len new-status) u0) ERR_INVALID_INPUT)
    (asserts! (or (is-eq new-status u"ACTIVE") 
                 (is-eq new-status u"INACTIVE") 
                 (is-eq new-status u"SUSPENDED"))
              ERR_INVALID_INPUT)
    
    ;; Validate the realtor exists first - this is crucial for the warning
    (match (map-get? realtors {realtor: realtor})
      realtor-data (begin
        ;; Only contract owner can change status
        (asserts! (is-eq tx-sender contract-owner) ERR_UNAUTHORIZED)
        
        ;; Now we can safely use the validated realtor
        (ok (map-set realtors
              {realtor: realtor}
              (merge realtor-data {status: new-status})
            ))
      )
      ERR_NOT_FOUND  ;; Return not found error if realtor doesn't exist
    )
  )
)
