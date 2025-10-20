AutoRebalancePortfolio
======================

A comprehensive Clarity smart contract designed to manage a multi-token portfolio, ensuring **automatic rebalancing** to maintain predetermined target allocations. This contract allows users to deposit funds in exchange for portfolio shares and includes robust owner-only functions for portfolio management and emergency pausing.

* * * * *

🚀 Overview
-----------

The `AutoRebalancePortfolio` contract acts as a decentralized fund manager. It accepts deposits and issues shares based on the portfolio's net asset value (NAV). Its core utility is the `rebalance-portfolio` function, which is protected by a deviation threshold and a block-height cooldown period. When triggered, the function checks the current allocation of each token against its target and virtually adjusts the balances to bring the portfolio back into alignment.

***Note**: This is a simplified model. In a production environment, the `update-portfolio-value` and `get-token-value` functions would integrate with **decentralized price oracles** to accurately reflect the real-time, external value of the token holdings, and the rebalancing would involve actual token swaps (e.g., using a decentralized exchange contract).*

* * * * *

🛠️ Contract Details
--------------------

### **Constants**

| Constant Name | Value | Description |
| --- | --- | --- |
| `contract-owner` | `tx-sender` | The principal that deployed the contract. |
| `max-tokens` | `u10` | Maximum number of tokens the portfolio can hold. |
| `percentage-base` | `u10000` | Defines 100.00% for basis point calculations (100.00% = 10,000 basis points). |
| `rebalance-threshold` | `u200` | The deviation (200 basis points or 2.00%) required to trigger a rebalance. |
| `err-owner-only` | `u100` | Returned when a function is called by a non-owner. |
| `err-rebalance-threshold` | `u107` | Rebalancing cooldown period has not elapsed or deviation is too low. |

Export to Sheets

### **Data Variables and Maps**

| Type | Name | Purpose |
| --- | --- | --- |
| **`define-map`** | `portfolio-tokens` | Tracks the contract, target allocation, balance, and status of each token by a unique `token-id`. |
| **`define-map`** | `user-shares` | Stores the number of portfolio shares held by each user principal. |
| **`define-data-var`** | `total-portfolio-value` | The total value of all tokens held by the portfolio (Simplified: sum of all current-balances). |
| **`define-data-var`** | `total-shares` | The total supply of portfolio shares issued to users. |
| **`define-data-var`** | `last-rebalance-block` | The block height of the last successful rebalance operation, used for the cooldown. |
| **`define-data-var`** | `is-paused` | Boolean flag to globally pause and prevent critical functions (`deposit`, `withdraw`, `rebalance-portfolio`). |

Export to Sheets

* * * * *

🔑 Public Functions (API)
-------------------------

### **Administrator/Owner Functions**

#### `add-token`

Code snippet

```
(define-public (add-token (token-id uint) (token-contract principal) (target-percentage uint))

```

Adds a new token to the portfolio with a starting target allocation.

-   **Authorization:** Must be called by the `contract-owner`.

-   **Pre-conditions:**

    -   `token-id` must not already exist.

    -   `token-count` must be less than `max-tokens` (`u10`).

    -   `target-percentage` must be `<= percentage-base` (`u10000`).

#### `update-target-allocation`

Code snippet

```
(define-public (update-target-allocation (token-id uint) (new-percentage uint))

```

Modifies the target allocation for an existing token in the portfolio.

-   **Authorization:** Must be called by the `contract-owner`.

-   **Pre-conditions:**

    -   `token-id` must exist and be active.

    -   `new-percentage` must be `<= percentage-base` (`u10000`). ***Note:** This contract does not enforce that the *sum* of all active target allocations equals 100% (`u10000`). The owner is responsible for managing the allocations to ensure they sum correctly. The private `validate-total-allocation` function is included but not used in the public API, suggesting it's reserved for internal use or future implementation.*

#### `pause-portfolio`

Code snippet

```
(define-public (pause-portfolio (pause bool))

```

Allows the owner to pause or unpause critical portfolio operations (`deposit`, `withdraw`, `rebalance-portfolio`). This is a **security failsafe**.

-   **Authorization:** Must be called by the `contract-owner`.

### **User Functions**

#### `deposit`

Code snippet

```
(define-public (deposit (amount uint))

```

Deposits funds into the portfolio and issues portfolio shares to the user.

-   **Logic:**

    -   If `total-portfolio-value` is `u0` (first deposit), shares are issued 1:1 with the deposit amount.

    -   Otherwise, shares are calculated based on the current NAV (Net Asset Value) per share:

        SharesIssued=TotalPortfolioValueDepositAmount×TotalShares​

-   **Pre-conditions:**

    -   Portfolio must **not** be paused (`is-paused` must be `false`).

    -   `amount` must be greater than `u0`.

-   **Post-conditions:** Updates `user-shares`, `total-shares`, and `total-portfolio-value`.

#### `withdraw`

Code snippet

```
(define-public (withdraw (shares-amount uint))

```

Redeems portfolio shares for an equivalent withdrawal amount from the portfolio.

-   **Logic:** The withdrawal amount is calculated based on the user's share of the total portfolio value:

    WithdrawalAmount=TotalSharesSharesRedeemed×TotalPortfolioValue​

-   **Pre-conditions:**

    -   Portfolio must **not** be paused (`is-paused` must be `false`).

    -   `shares-amount` must be less than or equal to the user's share balance.

-   **Post-conditions:** Updates `user-shares`, `total-shares`, and `total-portfolio-value`.

### **Core Rebalancing Function**

#### `rebalance-portfolio`

Code snippet

```
(define-public (rebalance-portfolio))

```

The central mechanism for automated portfolio rebalancing.

-   **Process:**

    1.  **Security/Pause Check:** Ensures the contract is not paused.

    2.  **Cooldown Check:** Asserts that at least `u144` blocks (approx. 1 day) have passed since the `last-rebalance-block`.

    3.  **Deviation Check:** Iterates through all active tokens, calculates the percentage deviation of their `current-balance` from their `target-percentage` using `calculate-deviation`.

    4.  **Threshold Enforcement:** Asserts that the `max-deviation` found is `>= rebalance-threshold` (`u200` or 2.00%).

    5.  **Execution:** If the threshold is met, it calls `check-and-rebalance-token` for each token.

        -   For tokens above or below the target allocation by the threshold, their `current-balance` is *virtually* updated in the `portfolio-tokens` map to match the `target-value`.

    6.  **Value Update:** Calls `update-portfolio-value` to recalculate the new `total-portfolio-value` after the virtual adjustments.

    7.  **Timestamp:** Updates `last-rebalance-block` to `block-height`.

* * * * *

🔒 Private Functions (Internal Logic)
-------------------------------------

| Function | Purpose |
| --- | --- |
| `(calculate-deviation (current uint) (target uint) (total uint))` | Calculates the absolute difference (in basis points) between the token's current percentage of the portfolio and its target percentage. |
| `(calculate-shares (deposit-amount uint))` | Calculates the number of new portfolio shares to issue for a given deposit amount. |
| `(update-portfolio-value)` | Iterates through all tokens and recalculates the `total-portfolio-value` based on their current balances. (Simplified: sums token balances). |
| `(get-token-value (token-id uint))` | Helper function to retrieve an active token's current balance from the map. (Simplified: returns `current-balance` as value). |
| `(check-max-deviation (token-id uint) (current-max uint))` | Used by `fold` in `rebalance-portfolio` to find the largest percentage deviation among all active tokens. |
| `(check-and-rebalance-token (token-id uint))` | Performs the core rebalancing adjustment for an individual token by setting its `current-balance` to the calculated `target-value` if the deviation threshold is met. |

Export to Sheets

* * * * *

📚 Read-Only Functions (Getters)
--------------------------------

| Function | Purpose |
| --- | --- |
| `(get-user-shares (user principal))` | Retrieves the share balance for any given user principal. |
| `(get-token-info (token-id uint))` | Retrieves the full data record for a specific token from the `portfolio-tokens` map. |

Export to Sheets

* * * * *

⚖️ License
----------

The `AutoRebalancePortfolio` smart contract is released under the **MIT License**.

```
MIT License

Copyright (c) 2025 AutoRebalancePortfolio

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```

* * * * *

🤝 Contributing
---------------

We welcome contributions to the `AutoRebalancePortfolio` contract. This includes feature suggestions, bug reports, security audits, and code improvements.

### **How to Contribute**

1.  **Fork** the repository.

2.  **Create** a new feature branch (`git checkout -b feature/AmazingFeature`).

3.  **Commit** your changes (`git commit -m 'Add amazing feature'`).

4.  **Push** to the branch (`git push origin feature/AmazingFeature`).

5.  **Open** a Pull Request, describing your changes in detail and explaining why they are necessary or beneficial.

### **Security**

Security is paramount for smart contracts. If you discover any security vulnerabilities, please do **not** disclose them publicly. Instead, report them immediately via a private channel (e.g., email the contract owner) so they can be addressed discreetly before public exploitation is possible.

* * * * *

☎️ Support and Contact
----------------------

For general inquiries, collaboration opportunities, or technical support related to the contract, please reach out to the project maintainer.

-   **Maintainer:** akinseindek@gmail.com

* * * * *

Disclaimer
----------

This smart contract is provided "as is," without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software. **Users are advised to perform their own due diligence and security audits before deploying or interacting with this contract, especially in a production environment with real assets.**
