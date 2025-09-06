;; Medical Billing Automation Smart Contract
;; This contract automates medical billing processes with robust error handling

;; Constants for error codes
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-UNAUTHORIZED (err u104))
(define-constant ERR-BILL-ALREADY-PAID (err u105))
(define-constant ERR-INSUFFICIENT-FUNDS (err u106))
(define-constant ERR-INVALID-STATUS (err u107))
(define-constant ERR-EXPIRED-BILL (err u108))
(define-constant ERR-INVALID-DISCOUNT (err u109))
(define-constant ERR-PROVIDER-NOT-AUTHORIZED (err u110))
(define-constant ERR-INVALID-INPUT (err u111))

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Bill status constants
(define-constant BILL-STATUS-PENDING u1)
(define-constant BILL-STATUS-PAID u2)
(define-constant BILL-STATUS-OVERDUE u3)
(define-constant BILL-STATUS-DISPUTED u4)
(define-constant BILL-STATUS-CANCELLED u5)

;; Provider authorization levels
(define-constant PROVIDER-LEVEL-BASIC u1)
(define-constant PROVIDER-LEVEL-PREMIUM u2)
(define-constant PROVIDER-LEVEL-ENTERPRISE u3)

;; Data structures
(define-map medical-providers principal {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    authorization-level: uint,
    is-active: bool,
    registration-block: uint
})

(define-map patients principal {
    name: (string-ascii 100),
    patient-id: (string-ascii 50),
    insurance-provider: (optional principal),
    emergency-contact: (string-ascii 100),
    is-active: bool,
    registration-block: uint
})

(define-map medical-bills uint {
    bill-id: uint,
    provider: principal,
    patient: principal,
    amount: uint,
    service-date: uint,
    due-date: uint,
    status: uint,
    description: (string-ascii 500),
    diagnosis-code: (string-ascii 20),
    treatment-code: (string-ascii 20),
    insurance-claim-id: (optional (string-ascii 50)),
    discount-applied: uint,
    created-block: uint,
    paid-block: (optional uint)
})

(define-map insurance-providers principal {
    name: (string-ascii 100),
    coverage-percentage: uint,
    max-coverage: uint,
    is-active: bool,
    authorization-codes: (list 10 (string-ascii 20))
})

(define-map bill-payments uint {
    bill-id: uint,
    payer: principal,
    amount: uint,
    payment-method: (string-ascii 50),
    transaction-id: (string-ascii 100),
    payment-block: uint
})

(define-map provider-earnings principal uint)
(define-map patient-bills principal (list 100 uint))
(define-map dispute-records uint {
    bill-id: uint,
    disputer: principal,
    reason: (string-ascii 500),
    status: (string-ascii 20),
    created-block: uint,
    resolved-block: (optional uint)
})

;; Data variables
(define-data-var bill-counter uint u0)
(define-data-var dispute-counter uint u0)
(define-data-var platform-fee-percentage uint u250) ;; 2.5%
(define-data-var late-fee-percentage uint u500) ;; 5%
(define-data-var max-bill-lifetime-blocks uint u144000) ;; ~100 days

;; Input validation functions
(define-private (is-valid-string (input (string-ascii 500)))
    (> (len input) u0))

(define-private (is-valid-short-string (input (string-ascii 100)))
    (and (> (len input) u0) (<= (len input) u100)))

(define-private (is-valid-medium-string (input (string-ascii 500)))
    (and (> (len input) u0) (<= (len input) u500)))

(define-private (is-valid-code (input (string-ascii 50)))
    (and (> (len input) u0) (<= (len input) u50)))

(define-private (is-valid-principal (input principal))
    (not (is-eq input 'SP000000000000000000002Q6VF78)))

(define-private (is-valid-authorization-level (level uint))
    (and (>= level PROVIDER-LEVEL-BASIC) (<= level PROVIDER-LEVEL-ENTERPRISE)))

(define-private (is-valid-coverage-percentage (percentage uint))
    (and (> percentage u0) (<= percentage u10000))) ;; 0.01% to 100%

(define-private (is-valid-fee-percentage (percentage uint))
    (<= percentage u2000)) ;; Max 20%

(define-private (is-valid-amount (amount uint))
    (> amount u0))

(define-private (is-valid-date (date uint))
    (and (> date u0) (<= date (+ stacks-block-height u1000000)))) ;; Reasonable future limit

(define-private (is-valid-dispute-id (dispute-id uint))
    (and (> dispute-id u0) (<= dispute-id (var-get dispute-counter))))

;; Authorization functions
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner)))

(define-private (is-authorized-provider (provider principal))
    (match (map-get? medical-providers provider)
        provider-data (get is-active provider-data)
        false))

(define-private (is-valid-patient (patient principal))
    (match (map-get? patients patient)
        patient-data (get is-active patient-data)
        false))

;; Administrative functions
(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-contract-owner) ERR-OWNER-ONLY)
        (asserts! (is-valid-principal new-owner) ERR-INVALID-INPUT)
        (var-set contract-owner new-owner)
        (ok true)))

(define-public (update-platform-fee (new-fee-percentage uint))
    (begin
        (asserts! (is-contract-owner) ERR-OWNER-ONLY)
        (asserts! (<= new-fee-percentage u1000) ERR-INVALID-AMOUNT) ;; Max 10%
        (var-set platform-fee-percentage new-fee-percentage)
        (ok true)))

(define-public (update-late-fee (new-late-fee-percentage uint))
    (begin
        (asserts! (is-contract-owner) ERR-OWNER-ONLY)
        (asserts! (is-valid-fee-percentage new-late-fee-percentage) ERR-INVALID-AMOUNT)
        (var-set late-fee-percentage new-late-fee-percentage)
        (ok true)))

;; Provider management
(define-public (register-provider (name (string-ascii 100)) (license-number (string-ascii 50)) (authorization-level uint))
    (let ((provider tx-sender))
        (asserts! (is-valid-short-string name) ERR-INVALID-INPUT)
        (asserts! (is-valid-code license-number) ERR-INVALID-INPUT)
        (asserts! (is-valid-authorization-level authorization-level) ERR-INVALID-STATUS)
        (asserts! (is-none (map-get? medical-providers provider)) ERR-ALREADY-EXISTS)
        (map-set medical-providers provider {
            name: name,
            license-number: license-number,
            authorization-level: authorization-level,
            is-active: true,
            registration-block: stacks-block-height
        })
        (ok true)))

(define-public (update-provider-status (provider principal) (is-active bool))
    (begin
        (asserts! (is-contract-owner) ERR-OWNER-ONLY)
        (asserts! (is-valid-principal provider) ERR-INVALID-INPUT)
        (asserts! (is-some (map-get? medical-providers provider)) ERR-NOT-FOUND)
        (map-set medical-providers provider 
            (merge (unwrap-panic (map-get? medical-providers provider)) {is-active: is-active}))
        (ok true)))

;; Patient management
(define-public (register-patient (name (string-ascii 100)) (patient-id (string-ascii 50)) (insurance-provider (optional principal)) (emergency-contact (string-ascii 100)))
    (let ((patient tx-sender))
        (asserts! (is-valid-short-string name) ERR-INVALID-INPUT)
        (asserts! (is-valid-code patient-id) ERR-INVALID-INPUT)
        (asserts! (is-valid-short-string emergency-contact) ERR-INVALID-INPUT)
        (asserts! (match insurance-provider
            some-provider (is-valid-principal some-provider)
            true) ERR-INVALID-INPUT)
        (asserts! (is-none (map-get? patients patient)) ERR-ALREADY-EXISTS)
        (map-set patients patient {
            name: name,
            patient-id: patient-id,
            insurance-provider: insurance-provider,
            emergency-contact: emergency-contact,
            is-active: true,
            registration-block: stacks-block-height
        })
        (ok true)))

(define-public (update-patient-insurance (insurance-provider (optional principal)))
    (let ((patient tx-sender))
        (asserts! (match insurance-provider
            some-provider (is-valid-principal some-provider)
            true) ERR-INVALID-INPUT)
        (asserts! (is-some (map-get? patients patient)) ERR-NOT-FOUND)
        (map-set patients patient 
            (merge (unwrap-panic (map-get? patients patient)) {insurance-provider: insurance-provider}))
        (ok true)))

;; Insurance provider management
(define-public (register-insurance-provider (name (string-ascii 100)) (coverage-percentage uint) (max-coverage uint) (authorization-codes (list 10 (string-ascii 20))))
    (begin
        (asserts! (is-contract-owner) ERR-OWNER-ONLY)
        (asserts! (is-valid-short-string name) ERR-INVALID-INPUT)
        (asserts! (is-valid-coverage-percentage coverage-percentage) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-amount max-coverage) ERR-INVALID-AMOUNT)
        (asserts! (> (len authorization-codes) u0) ERR-INVALID-INPUT)
        (map-set insurance-providers tx-sender {
            name: name,
            coverage-percentage: coverage-percentage,
            max-coverage: max-coverage,
            is-active: true,
            authorization-codes: authorization-codes
        })
        (ok true)))

;; Bill creation and management
(define-public (create-bill (patient principal) (amount uint) (service-date uint) (due-date uint) (description (string-ascii 500)) (diagnosis-code (string-ascii 20)) (treatment-code (string-ascii 20)))
    (let (
        (provider tx-sender)
        (bill-id (+ (var-get bill-counter) u1))
    )
        (asserts! (is-authorized-provider provider) ERR-PROVIDER-NOT-AUTHORIZED)
        (asserts! (is-valid-principal patient) ERR-INVALID-INPUT)
        (asserts! (is-valid-patient patient) ERR-NOT-FOUND)
        (asserts! (is-valid-amount amount) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-date due-date) ERR-INVALID-AMOUNT)
        (asserts! (> due-date stacks-block-height) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-date service-date) ERR-INVALID-AMOUNT)
        (asserts! (<= service-date stacks-block-height) ERR-INVALID-AMOUNT)
        (asserts! (is-valid-medium-string description) ERR-INVALID-INPUT)
        (asserts! (is-valid-string diagnosis-code) ERR-INVALID-INPUT)
        (asserts! (is-valid-string treatment-code) ERR-INVALID-INPUT)
        
        ;; Create the bill
        (map-set medical-bills bill-id {
            bill-id: bill-id,
            provider: provider,
            patient: patient,
            amount: amount,
            service-date: service-date,
            due-date: due-date,
            status: BILL-STATUS-PENDING,
            description: description,
            diagnosis-code: diagnosis-code,
            treatment-code: treatment-code,
            insurance-claim-id: none,
            discount-applied: u0,
            created-block: stacks-block-height,
            paid-block: none
        })
        
        ;; Update patient's bill list
        (match (map-get? patient-bills patient)
            existing-bills 
                (map-set patient-bills patient (unwrap-panic (as-max-len? (append existing-bills bill-id) u100)))
            (map-set patient-bills patient (list bill-id))
        )
        
        (var-set bill-counter bill-id)
        (ok bill-id)))

(define-public (apply-discount (bill-id uint) (discount-percentage uint))
    (let (
        (bill (unwrap! (map-get? medical-bills bill-id) ERR-NOT-FOUND))
        (provider tx-sender)
    )
        (asserts! (> bill-id u0) ERR-INVALID-INPUT)
        (asserts! (is-eq provider (get provider bill)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status bill) BILL-STATUS-PENDING) ERR-INVALID-STATUS)
        (asserts! (<= discount-percentage u10000) ERR-INVALID-DISCOUNT) ;; Max 100%
        (asserts! (is-eq (get discount-applied bill) u0) ERR-ALREADY-EXISTS)
        
        (map-set medical-bills bill-id 
            (merge bill {discount-applied: discount-percentage}))
        (ok true)))

;; Payment processing
(define-public (pay-bill (bill-id uint) (payment-method (string-ascii 50)) (transaction-id (string-ascii 100)))
    (let (
        (bill (unwrap! (map-get? medical-bills bill-id) ERR-NOT-FOUND))
        (payer tx-sender)
        (final-amount (calculate-final-amount bill-id))
        (platform-fee (/ (* final-amount (var-get platform-fee-percentage)) u10000))
        (provider-amount (- final-amount platform-fee))
    )
        (asserts! (> bill-id u0) ERR-INVALID-INPUT)
        (asserts! (is-valid-code payment-method) ERR-INVALID-INPUT)
        (asserts! (is-valid-short-string transaction-id) ERR-INVALID-INPUT)
        (asserts! (is-eq (get status bill) BILL-STATUS-PENDING) ERR-BILL-ALREADY-PAID)
        (asserts! (or (is-eq payer (get patient bill)) (is-eq payer (get provider bill))) ERR-UNAUTHORIZED)
        
        ;; Record payment
        (map-set bill-payments bill-id {
            bill-id: bill-id,
            payer: payer,
            amount: final-amount,
            payment-method: payment-method,
            transaction-id: transaction-id,
            payment-block: stacks-block-height
        })
        
        ;; Update bill status
        (map-set medical-bills bill-id 
            (merge bill {
                status: BILL-STATUS-PAID,
                paid-block: (some stacks-block-height)
            }))
        
        ;; Update provider earnings
        (map-set provider-earnings (get provider bill)
            (+ (default-to u0 (map-get? provider-earnings (get provider bill))) provider-amount))
        
        (ok true)))

;; Insurance claim processing
(define-public (process-insurance-claim (bill-id uint) (claim-id (string-ascii 50)))
    (let (
        (bill (unwrap! (map-get? medical-bills bill-id) ERR-NOT-FOUND))
        (patient-data (unwrap! (map-get? patients (get patient bill)) ERR-NOT-FOUND))
        (insurance-provider (unwrap! (get insurance-provider patient-data) ERR-NOT-FOUND))
        (insurance-data (unwrap! (map-get? insurance-providers insurance-provider) ERR-NOT-FOUND))
    )
        (asserts! (> bill-id u0) ERR-INVALID-INPUT)
        (asserts! (is-valid-code claim-id) ERR-INVALID-INPUT)
        (asserts! (or (is-eq tx-sender (get provider bill)) (is-eq tx-sender insurance-provider)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get status bill) BILL-STATUS-PENDING) ERR-INVALID-STATUS)
        (asserts! (get is-active insurance-data) ERR-UNAUTHORIZED)
        
        (map-set medical-bills bill-id 
            (merge bill {insurance-claim-id: (some claim-id)}))
        (ok true)))

;; Dispute management
(define-public (create-dispute (bill-id uint) (reason (string-ascii 500)))
    (let (
        (bill (unwrap! (map-get? medical-bills bill-id) ERR-NOT-FOUND))
        (dispute-id (+ (var-get dispute-counter) u1))
        (disputer tx-sender)
    )
        (asserts! (> bill-id u0) ERR-INVALID-INPUT)
        (asserts! (is-valid-medium-string reason) ERR-INVALID-INPUT)
        (asserts! (or (is-eq disputer (get patient bill)) (is-eq disputer (get provider bill))) ERR-UNAUTHORIZED)
        (asserts! (not (is-eq (get status bill) BILL-STATUS-PAID)) ERR-BILL-ALREADY-PAID)
        
        (map-set dispute-records dispute-id {
            bill-id: bill-id,
            disputer: disputer,
            reason: reason,
            status: "OPEN",
            created-block: stacks-block-height,
            resolved-block: none
        })
        
        (map-set medical-bills bill-id 
            (merge bill {status: BILL-STATUS-DISPUTED}))
        
        (var-set dispute-counter dispute-id)
        (ok dispute-id)))

(define-public (resolve-dispute (dispute-id uint) (resolution (string-ascii 20)))
    (let (
        (dispute (unwrap! (map-get? dispute-records dispute-id) ERR-NOT-FOUND))
        (bill (unwrap! (map-get? medical-bills (get bill-id dispute)) ERR-NOT-FOUND))
    )
        (asserts! (is-contract-owner) ERR-OWNER-ONLY)
        (asserts! (is-valid-dispute-id dispute-id) ERR-INVALID-INPUT)
        (asserts! (is-valid-string resolution) ERR-INVALID-INPUT)
        
        (map-set dispute-records dispute-id 
            (merge dispute {
                status: resolution,
                resolved-block: (some stacks-block-height)
            }))
        
        (map-set medical-bills (get bill-id dispute)
            (merge bill {status: BILL-STATUS-PENDING}))
        
        (ok true)))

;; Utility functions
(define-private (calculate-final-amount (bill-id uint))
    (let (
        (bill (unwrap-panic (map-get? medical-bills bill-id)))
        (base-amount (get amount bill))
        (discount-amount (/ (* base-amount (get discount-applied bill)) u10000))
        (discounted-amount (- base-amount discount-amount))
        (is-overdue (> stacks-block-height (get due-date bill)))
        (late-fee (if is-overdue (/ (* discounted-amount (var-get late-fee-percentage)) u10000) u0))
    )
        (+ discounted-amount late-fee)))

(define-public (update-overdue-bills (bill-ids (list 50 uint)))
    (begin
        (asserts! (is-contract-owner) ERR-OWNER-ONLY)
        (fold update-single-overdue-bill bill-ids (ok true))))

(define-private (update-single-overdue-bill (bill-id uint) (prev-result (response bool uint)))
    (match prev-result
        success
        (match (map-get? medical-bills bill-id)
            bill
            (if (and (is-eq (get status bill) BILL-STATUS-PENDING) (> stacks-block-height (get due-date bill)))
                (begin
                    (map-set medical-bills bill-id (merge bill {status: BILL-STATUS-OVERDUE}))
                    (ok true))
                (ok true))
            (ok true))
        error (err error)))

;; Read-only functions
(define-read-only (get-bill (bill-id uint))
    (map-get? medical-bills bill-id))

(define-read-only (get-provider (provider principal))
    (map-get? medical-providers provider))

(define-read-only (get-patient (patient principal))
    (map-get? patients patient))

(define-read-only (get-patient-bills (patient principal))
    (map-get? patient-bills patient))

(define-read-only (get-provider-earnings (provider principal))
    (default-to u0 (map-get? provider-earnings provider)))

(define-read-only (get-bill-payment (bill-id uint))
    (map-get? bill-payments bill-id))

(define-read-only (get-dispute (dispute-id uint))
    (map-get? dispute-records dispute-id))

(define-read-only (calculate-bill-amount (bill-id uint))
    (match (map-get? medical-bills bill-id)
        bill (ok (calculate-final-amount bill-id))
        ERR-NOT-FOUND))

(define-read-only (get-platform-stats)
    {
        total-bills: (var-get bill-counter),
        total-disputes: (var-get dispute-counter),
        platform-fee-percentage: (var-get platform-fee-percentage),
        late-fee-percentage: (var-get late-fee-percentage),
        contract-owner: (var-get contract-owner)
    })

(define-read-only (is-bill-overdue (bill-id uint))
    (match (map-get? medical-bills bill-id)
        bill (ok (> stacks-block-height (get due-date bill)))
        ERR-NOT-FOUND))

;; Emergency functions
(define-public (emergency-cancel-bill (bill-id uint))
    (let (
        (bill (unwrap! (map-get? medical-bills bill-id) ERR-NOT-FOUND))
    )
        (asserts! (is-contract-owner) ERR-OWNER-ONLY)
        (asserts! (> bill-id u0) ERR-INVALID-INPUT)
        (asserts! (not (is-eq (get status bill) BILL-STATUS-PAID)) ERR-BILL-ALREADY-PAID)
        
        (map-set medical-bills bill-id 
            (merge bill {status: BILL-STATUS-CANCELLED}))
        (ok true)))

(define-public (emergency-pause-provider (provider principal))
    (begin
        (asserts! (is-contract-owner) ERR-OWNER-ONLY)
        (asserts! (is-valid-principal provider) ERR-INVALID-INPUT)
        (asserts! (is-some (map-get? medical-providers provider)) ERR-NOT-FOUND)
        (map-set medical-providers provider 
            (merge (unwrap-panic (map-get? medical-providers provider)) {is-active: false}))
        (ok true)))

;; Initialize contract
(begin
    (print "Medical Billing Automation Contract Deployed")
    (print {contract-owner: (var-get contract-owner)})
)