(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED u1000)
(define-constant ERR-PERMIT-NOT-FOUND u1001)
(define-constant ERR-PERMIT-EXPIRED u1002)
(define-constant ERR-PERMIT-ALREADY-EXISTS u1003)
(define-constant ERR-INVALID-DURATION u1004)
(define-constant ERR-PERMIT-REVOKED u1005)
(define-constant ERR-AUTHORITY-NOT-FOUND u1006)

(define-data-var permit-counter uint u0)
(define-data-var contract-active bool true)

(define-map permits
  uint
  {
    applicant: principal,
    permit-type: (string-ascii 50),
    property-address: (string-ascii 100),
    description: (string-ascii 200),
    issue-block: uint,
    expiry-block: uint,
    status: (string-ascii 20),
    authority: principal,
    fee-paid: uint
  }
)

(define-map authorities
  principal
  {
    name: (string-ascii 50),
    active: bool,
    permits-issued: uint
  }
)

(define-map permit-history
  { permit-id: uint, action: (string-ascii 20) }
  {
    block-height: uint,
    actor: principal,
    details: (string-ascii 100)
  }
)

(define-map applicant-permits
  principal
  (list 50 uint)
)

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-authority (authority principal))
  (match (map-get? authorities authority)
    auth-data (get active auth-data)
    false
  )
)

(define-private (add-to-history (permit-id uint) (action (string-ascii 20)) (details (string-ascii 100)))
  (begin
    (map-set permit-history
      { permit-id: permit-id, action: action }
      {
        block-height: stacks-block-height,
        actor: tx-sender,
        details: details
      }
    )
    (ok true)
  )
)

(define-private (update-applicant-permits (applicant principal) (permit-id uint))
  (let ((current-permits (default-to (list) (map-get? applicant-permits applicant))))
    (match (as-max-len? (append current-permits permit-id) u50)
      updated-permits (begin (map-set applicant-permits applicant updated-permits) (ok true))
      (ok false)
    )
  )
)

(define-public (add-authority (authority principal) (name (string-ascii 50)))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (map-set authorities authority { name: name, active: true, permits-issued: u0 })
    (ok true)
  )
)

(define-public (deactivate-authority (authority principal))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (match (map-get? authorities authority)
      auth-data (begin
        (map-set authorities authority (merge auth-data { active: false }))
        (ok true)
      )
      (err ERR-AUTHORITY-NOT-FOUND)
    )
  )
)

(define-public (issue-permit
  (applicant principal)
  (permit-type (string-ascii 50))
  (property-address (string-ascii 100))
  (description (string-ascii 200))
  (duration-blocks uint)
  (fee uint)
)
  (let (
    (permit-id (+ (var-get permit-counter) u1))
    (current-block stacks-block-height)
    (expiry-block (+ current-block duration-blocks))
  )
    (asserts! (var-get contract-active) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-authorized-authority tx-sender) (err ERR-NOT-AUTHORIZED))
    (asserts! (> duration-blocks u0) (err ERR-INVALID-DURATION))
    
    (map-set permits permit-id {
      applicant: applicant,
      permit-type: permit-type,
      property-address: property-address,
      description: description,
      issue-block: current-block,
      expiry-block: expiry-block,
      status: "active",
      authority: tx-sender,
      fee-paid: fee
    })
    
    (var-set permit-counter permit-id)
    (unwrap! (update-applicant-permits applicant permit-id) (err ERR-NOT-AUTHORIZED))
    (unwrap! (add-to-history permit-id "issued" "Permit issued") (err ERR-NOT-AUTHORIZED))
    
    (match (map-get? authorities tx-sender)
      auth-data (map-set authorities tx-sender (merge auth-data { permits-issued: (+ (get permits-issued auth-data) u1) }))
      false
    )
    
    (ok permit-id)
  )
)

(define-public (renew-permit (permit-id uint) (additional-blocks uint))
  (match (map-get? permits permit-id)
    permit-data (begin
      (asserts! (is-authorized-authority tx-sender) (err ERR-NOT-AUTHORIZED))
      (asserts! (is-eq (get status permit-data) "active") (err ERR-PERMIT-REVOKED))
      (asserts! (> additional-blocks u0) (err ERR-INVALID-DURATION))
      
      (let ((new-expiry (+ (get expiry-block permit-data) additional-blocks)))
        (map-set permits permit-id (merge permit-data { expiry-block: new-expiry }))
        (unwrap! (add-to-history permit-id "renewed" "Permit renewed") (err ERR-NOT-AUTHORIZED))
        (ok new-expiry)
      )
    )
    (err ERR-PERMIT-NOT-FOUND)
  )
)

(define-public (revoke-permit (permit-id uint) (reason (string-ascii 100)))
  (match (map-get? permits permit-id)
    permit-data (begin
      (asserts! (or (is-contract-owner) (is-authorized-authority tx-sender)) (err ERR-NOT-AUTHORIZED))
      (asserts! (is-eq (get status permit-data) "active") (err ERR-PERMIT-REVOKED))
      
      (map-set permits permit-id (merge permit-data { status: "revoked" }))
      (unwrap! (add-to-history permit-id "revoked" reason) (err ERR-NOT-AUTHORIZED))
      (ok true)
    )
    (err ERR-PERMIT-NOT-FOUND)
  )
)

(define-public (transfer-permit (permit-id uint) (new-applicant principal))
  (match (map-get? permits permit-id)
    permit-data (begin
      (asserts! (is-eq tx-sender (get applicant permit-data)) (err ERR-NOT-AUTHORIZED))
      (asserts! (is-eq (get status permit-data) "active") (err ERR-PERMIT-REVOKED))
      (asserts! (< stacks-block-height (get expiry-block permit-data)) (err ERR-PERMIT-EXPIRED))
      
      (map-set permits permit-id (merge permit-data { applicant: new-applicant }))
      (unwrap! (update-applicant-permits new-applicant permit-id) (err ERR-NOT-AUTHORIZED))
      (unwrap! (add-to-history permit-id "transferred" "Permit ownership transferred") (err ERR-NOT-AUTHORIZED))
      (ok true)
    )
    (err ERR-PERMIT-NOT-FOUND)
  )
)

(define-public (set-contract-status (active bool))
  (begin
    (asserts! (is-contract-owner) (err ERR-NOT-AUTHORIZED))
    (var-set contract-active active)
    (ok active)
  )
)

(define-read-only (get-permit (permit-id uint))
  (map-get? permits permit-id)
)

(define-read-only (get-authority (authority principal))
  (map-get? authorities authority)
)

(define-read-only (get-permit-history (permit-id uint) (action (string-ascii 20)))
  (map-get? permit-history { permit-id: permit-id, action: action })
)

(define-read-only (get-applicant-permits (applicant principal))
  (map-get? applicant-permits applicant)
)

(define-read-only (is-permit-valid (permit-id uint))
  (match (map-get? permits permit-id)
    permit-data (and
      (is-eq (get status permit-data) "active")
      (< stacks-block-height (get expiry-block permit-data))
    )
    false
  )
)

(define-read-only (get-permit-status (permit-id uint))
  (match (map-get? permits permit-id)
    permit-data (if (< stacks-block-height (get expiry-block permit-data))
      (get status permit-data)
      "expired"
    )
    "not-found"
  )
)

(define-read-only (get-permits-by-type (permit-type (string-ascii 50)))
  (let ((total-permits (var-get permit-counter)))
    (filter check-permit-type (generate-sequence total-permits))
  )
)

(define-read-only (get-permits-expiring-soon (blocks-ahead uint))
  (let ((total-permits (var-get permit-counter)))
    (filter check-expiring-soon-helper (generate-sequence total-permits))
  )
)

(define-read-only (get-contract-stats)
  {
    total-permits: (var-get permit-counter),
    contract-active: (var-get contract-active),
    current-block: stacks-block-height
  }
)

(define-private (check-permit-type (permit-id uint))
  (match (map-get? permits permit-id)
    permit-data true
    false
  )
)

(define-private (check-expiring-soon-helper (permit-id uint))
  (match (map-get? permits permit-id)
    permit-data (and
      (is-eq (get status permit-data) "active")
      (<= (get expiry-block permit-data) (+ stacks-block-height u144))
      (> (get expiry-block permit-data) stacks-block-height)
    )
    false
  )
)

(define-private (generate-sequence (max-num uint))
  (if (<= max-num u0)
    (list)
    (unwrap-panic (as-max-len? (map + (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50) (list (- max-num u49) (- max-num u48) (- max-num u47) (- max-num u46) (- max-num u45) (- max-num u44) (- max-num u43) (- max-num u42) (- max-num u41) (- max-num u40) (- max-num u39) (- max-num u38) (- max-num u37) (- max-num u36) (- max-num u35) (- max-num u34) (- max-num u33) (- max-num u32) (- max-num u31) (- max-num u30) (- max-num u29) (- max-num u28) (- max-num u27) (- max-num u26) (- max-num u25) (- max-num u24) (- max-num u23) (- max-num u22) (- max-num u21) (- max-num u20) (- max-num u19) (- max-num u18) (- max-num u17) (- max-num u16) (- max-num u15) (- max-num u14) (- max-num u13) (- max-num u12) (- max-num u11) (- max-num u10) (- max-num u9) (- max-num u8) (- max-num u7) (- max-num u6) (- max-num u5) (- max-num u4) (- max-num u3) (- max-num u2) (- max-num u1) (- max-num u0))) u50))
  )
)
