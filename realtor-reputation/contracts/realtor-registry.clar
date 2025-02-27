;; realtor-registry.clar
;; This contract handles realtor registration and profile management
;; Author: Claude
 
;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_REGISTERED (err u102))
(define-constant ERR_INVALID_LICENSE (err u103))

;; Define contract owner constant
(define-constant contract-owner tx-sender)
 
;; Data maps
 
;; Realtor profile data structure
(define-map realtors
  { principal: principal }
  {
    name: (string-utf8 100),
    license-number: (string-utf8 50),
    brokerage: (string-utf8 100),
    status: (string-utf8 20),
    registration-block: uint,
    profile-uri: (optional (string-utf8 256))
  }
)
 
;; Principal to license number mapping for quick lookup
(define-map license-registry
  { license-number: (string-utf8 50) }
  { principal: principal }
)
 
;; Functions
 
;; Register a new realtor
(define-public (register-realtor
                (name (string-utf8 100))
                (license-number (string-utf8 50))
                (brokerage (string-utf8 100))
                (profile-uri (optional (string-utf8 256))))
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? realtors {principal: caller})) ERR_ALREADY_REGISTERED)
    (asserts! (is-none (map-get? license-registry {license-number: license-number})) ERR_INVALID_LICENSE)
   
    ;; Store realtor profile
    (map-set realtors
      {principal: caller}
      {
        name: name,
        license-number: license-number,
        brokerage: brokerage,
        status: "active",
        registration-block: block-height,
        profile-uri: profile-uri
      }
    )
   
    ;; Register license
    (map-set license-registry
      {license-number: license-number}
      {principal: caller}
    )
   
    (ok true)
  )
)
 
;; Update realtor profile
(define-public (update-profile
                (name (string-utf8 100))
                (brokerage (string-utf8 100))
                (profile-uri (optional (string-utf8 256))))
  (let ((caller tx-sender)
        (realtor-data (unwrap! (map-get? realtors {principal: caller}) ERR_NOT_REGISTERED)))
   
    ;; Update profile data
    (map-set realtors
      {principal: caller}
      (merge realtor-data
        {
          name: name,
          brokerage: brokerage,
          profile-uri: profile-uri
        }
      )
    )
   
    (ok true)
  )
)
 
;; Update realtor status (admin only)
(define-public (update-status
                (realtor principal)
                (new-status (string-utf8 20)))
  (let ((caller tx-sender)
        (realtor-data (unwrap! (map-get? realtors {principal: realtor}) ERR_NOT_REGISTERED)))
   
    ;; Only contract owner can update status
    (asserts! (is-eq caller contract-owner) ERR_UNAUTHORIZED)
   
    ;; Update status
    (map-set realtors
      {principal: realtor}
      (merge realtor-data {status: new-status})
    )
   
    (ok true)
  )
)
 
;; Read-only functions
 
;; Get realtor profile
(define-read-only (get-realtor (realtor principal))
  (map-get? realtors {principal: realtor})
)
 
;; Check if a realtor is active
(define-read-only (is-active-realtor (realtor principal))
  (match (map-get? realtors {principal: realtor})
    realtor-data (is-eq (get status realtor-data) "active")
    false
  )
)
 
;; Get realtor by license number
(define-read-only (get-realtor-by-license (license-number (string-utf8 50)))
  (match (map-get? license-registry {license-number: license-number})
    license-data (get-realtor (get principal license-data))
    none
  )
)
