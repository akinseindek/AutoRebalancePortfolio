;; Auto-Rebalancing Token Portfolio
;; A smart contract that manages a multi-token portfolio with automatic rebalancing
;; capabilities. Users can deposit funds, and the contract maintains target allocations
;; across different tokens through periodic rebalancing operations.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-percentage (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-portfolio-full (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-rebalance-threshold (err u107))
(define-constant err-token-not-in-portfolio (err u108))

(define-constant max-tokens u10)
(define-constant percentage-base u10000) ;; 100.00% = 10000 (basis points)
(define-constant rebalance-threshold u200) ;; 2% deviation triggers rebalancing

;; data maps and vars
;; Track each token in the portfolio with its target allocation
(define-map portfolio-tokens
  { token-id: uint }
  {
    token-contract: principal,
    target-percentage: uint,
    current-balance: uint,
    is-active: bool
  }
)

;; Track user deposits in the portfolio
(define-map user-shares
  { user: principal }
  { shares: uint }
)

;; Portfolio metadata
(define-data-var total-portfolio-value uint u0)
(define-data-var total-shares uint u0)
(define-data-var token-count uint u0)
(define-data-var last-rebalance-block uint u0)
(define-data-var is-paused bool false)

;; private functions
;; Calculate the percentage deviation between current and target allocation
(define-private (calculate-deviation (current uint) (target uint) (total uint))
  (let (
    (current-percentage (if (is-eq total u0) u0 (/ (* current percentage-base) total)))
    (deviation (if (> current-percentage target)
                  (- current-percentage target)
                  (- target current-percentage)))
  )
    deviation
  )
)

;; Check if a token exists in the portfolio
(define-private (token-exists (token-id uint))
  (match (map-get? portfolio-tokens { token-id: token-id })
    token-data (get is-active token-data)
    false
  )
)

;; Validate that total allocations equal 100%
(define-private (validate-total-allocation (token-id uint) (sum-so-far uint))
  (match (map-get? portfolio-tokens { token-id: token-id })
    token-data (if (get is-active token-data)
                   (some (+ sum-so-far (get target-percentage token-data)))
                   (some sum-so-far))
    (some sum-so-far)
  )
)

;; Calculate user's share of portfolio based on deposit
(define-private (calculate-shares (deposit-amount uint))
  (let (
    (current-total (var-get total-portfolio-value))
    (current-shares (var-get total-shares))
  )
    (if (is-eq current-total u0)
      deposit-amount ;; First deposit: 1:1 ratio
      (/ (* deposit-amount current-shares) current-total)
    )
  )
)

;; Update portfolio value based on all token balances
(define-private (update-portfolio-value)
  (let (
    (total-value (fold + (map get-token-value (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)) u0))
  )
    (var-set total-portfolio-value total-value)
    (ok total-value)
  )
)

;; Helper to get token value (simplified - in production would query price oracle)
(define-private (get-token-value (token-id uint))
  (match (map-get? portfolio-tokens { token-id: token-id })
    token-data (if (get is-active token-data) (get current-balance token-data) u0)
    u0
  )
)

;; public functions
;; Initialize or add a new token to the portfolio with target allocation
(define-public (add-token (token-id uint) (token-contract principal) (target-percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (token-exists token-id)) err-already-exists)
    (asserts! (< (var-get token-count) max-tokens) err-portfolio-full)
    (asserts! (<= target-percentage percentage-base) err-invalid-percentage)
    
    (map-set portfolio-tokens
      { token-id: token-id }
      {
        token-contract: token-contract,
        target-percentage: target-percentage,
        current-balance: u0,
        is-active: true
      }
    )
    (var-set token-count (+ (var-get token-count) u1))
    (ok true)
  )
)

;; Update the target allocation for a specific token
(define-public (update-target-allocation (token-id uint) (new-percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (token-exists token-id) err-token-not-in-portfolio)
    (asserts! (<= new-percentage percentage-base) err-invalid-percentage)
    
    (match (map-get? portfolio-tokens { token-id: token-id })
      token-data (begin
        (map-set portfolio-tokens
          { token-id: token-id }
          (merge token-data { target-percentage: new-percentage })
        )
        (ok true)
      )
      err-not-found
    )
  )
)

;; Allow users to deposit funds and receive portfolio shares
(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (not (var-get is-paused)) err-owner-only)
    
    (let (
      (new-shares (calculate-shares amount))
      (current-user-shares (default-to { shares: u0 } 
        (map-get? user-shares { user: tx-sender })))
    )
      ;; Update user shares
      (map-set user-shares
        { user: tx-sender }
        { shares: (+ (get shares current-user-shares) new-shares) }
      )
      
      ;; Update total shares and portfolio value
      (var-set total-shares (+ (var-get total-shares) new-shares))
      (var-set total-portfolio-value (+ (var-get total-portfolio-value) amount))
      
      (ok new-shares)
    )
  )
)

;; Allow users to withdraw their share of the portfolio
(define-public (withdraw (shares-amount uint))
  (let (
    (user-data (unwrap! (map-get? user-shares { user: tx-sender }) err-insufficient-balance))
    (user-share-balance (get shares user-data))
    (total-shares-supply (var-get total-shares))
    (total-value (var-get total-portfolio-value))
    (withdrawal-amount (/ (* shares-amount total-value) total-shares-supply))
  )
    (asserts! (>= user-share-balance shares-amount) err-insufficient-balance)
    (asserts! (not (var-get is-paused)) err-owner-only)
    
    ;; Update user shares
    (map-set user-shares
      { user: tx-sender }
      { shares: (- user-share-balance shares-amount) }
    )
    
    ;; Update totals
    (var-set total-shares (- total-shares-supply shares-amount))
    (var-set total-portfolio-value (- total-value withdrawal-amount))
    
    (ok withdrawal-amount)
  )
)

;; Emergency pause function for security
(define-public (pause-portfolio (pause bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set is-paused pause)
    (ok true)
  )
)

;; Get user's share balance
(define-read-only (get-user-shares (user principal))
  (ok (get shares (default-to { shares: u0 } (map-get? user-shares { user: user }))))
)

;; Get token information from portfolio
(define-read-only (get-token-info (token-id uint))
  (ok (map-get? portfolio-tokens { token-id: token-id }))
)

;; Helper function to find maximum deviation across all tokens
(define-private (check-max-deviation (token-id uint) (current-max uint))
  (match (map-get? portfolio-tokens { token-id: token-id })
    token-data (if (get is-active token-data)
      (let (
        (current-balance (get current-balance token-data))
        (target-percentage (get target-percentage token-data))
        (total-value (var-get total-portfolio-value))
        (deviation (calculate-deviation current-balance target-percentage total-value))
      )
        (if (> deviation current-max) deviation current-max)
      )
      current-max
    )
    current-max
  )
)

;; Helper function for rebalancing individual tokens
(define-private (check-and-rebalance-token (token-id uint))
  (match (map-get? portfolio-tokens { token-id: token-id })
    token-data (if (get is-active token-data)
      (let (
        (current-balance (get current-balance token-data))
        (target-percentage (get target-percentage token-data))
        (total-value (var-get total-portfolio-value))
        (target-value (/ (* total-value target-percentage) percentage-base))
        (deviation (calculate-deviation current-balance target-percentage total-value))
      )
        ;; If deviation exceeds threshold, adjust the balance
        (if (>= deviation rebalance-threshold)
          (begin
            (map-set portfolio-tokens
              { token-id: token-id }
              (merge token-data { current-balance: target-value })
            )
            true
          )
          true
        )
      )
      true
    )
    true
  )
)



