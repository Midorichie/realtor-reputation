;; contract-manager.clar
;; This contract manages addresses of deployed contracts

(define-data-var contract-owner principal tx-sender)

;; Map for contract addresses
(define-map contract-addresses
  { contract-name: (string-utf8 100) }
  { contract-address: principal }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u403))
(define-constant ERR_NOT_FOUND (err u404))

;; Get contract address by name
(define-read-only (get-contract-address (contract-name (string-utf8 100)))
  (default-to (err ERR_NOT_FOUND)
    (ok (get contract-address (unwrap! (map-get? contract-addresses { contract-name: contract-name }) ERR_NOT_FOUND)))
  )
)

;; Register contract address
(define-public (register-contract (contract-name (string-utf8 100)) (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set contract-addresses
      { contract-name: contract-name }
      { contract-address: contract-address }
    ))
  )
)

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))
  )
)
