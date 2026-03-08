# 🏢 PrestigeTowers Smart Contract

A blockchain-based **real estate booking & settlement system** built with Solidity `^0.8.24`.  
This project demonstrates **state-driven contract design**, **secure fund handling**, and **on-chain voting mechanics** — audited and hardened against common vulnerabilities.

---

## 📌 Project Overview

The **PrestigeTowers Smart Contract** models a real-world apartment booking scenario where:

- A contractor (owner) deploys the contract with configurable flat count, price, booking deadline, and voting duration
- Buyers book flats and make staged payments during the booking phase
- Funds are securely locked in the contract
- Buyers vote **for** or **against** the contractor receiving funds
- Funds are released or refunded based on the voting outcome

---

## 🧠 Core Design Philosophy

This contract is built around **explicit state management** and **defensive programming**.

### Principles:

- Clear, auditable business logic
- Checks-effects-interactions pattern for all ETH transfers
- Reentrancy protection on all payout functions
- Constructor validation for all parameters
- Structured events for off-chain traceability

---

## 🔁 Project Lifecycle (State Machine)

```text
Booking  →  Voting  →  Settled
```

### States:

| State       | What happens                                                                | Who can act         |
| ----------- | --------------------------------------------------------------------------- | ------------------- |
| **Booking** | Buyers book flats (`buyFlat`) and deposit remaining amounts (`depositFund`) | Buyers              |
| **Voting**  | Buyers vote for (`putVote`) or against (`voteAgainst`) the contractor       | Buyers              |
| **Settled** | Funds released to contractor or refunded to buyers based on vote outcome    | Contractor / Buyers |

- **Booking → Voting**: Anyone can trigger via `moveToVoting()` once the booking deadline passes
- **Voting → Settled**: Automatically transitions via `_autoSettleIfNeeded()` when a claim is made after the voting window closes

---

## 🏗️ Constructor Parameters

```solidity
constructor(
    uint _totalFlats,       // Number of flats available
    uint _flatPrice,        // Price per flat in wei
    string memory _projectName, // Human-readable project name
    uint _endTime,          // Booking duration in seconds
    uint _votingDuration    // Voting duration in seconds
)
```

All parameters are validated to be non-zero at deployment.

---

## 👥 Buyer Identity Design

Buyer existence is tracked explicitly using:

```solidity
mapping(address => bool) buyerExists;
```

### Why this matters:

- Never infers existence from array indices
- Prevents duplicate bookings (one flat per address)
- Makes buyer checks explicit and readable
- `getAllBuyers()` getter returns only real buyers (skips internal index 0)

---

## 🗳️ Voting Mechanism

The voting system supports **two-sided voting**:

| Function        | Action                              |
| --------------- | ----------------------------------- |
| `putVote()`     | Vote **in favor** of the contractor |
| `voteAgainst()` | Vote **against** the contractor     |

### Rules:

- Only verified buyers can vote
- Owner (contractor) cannot vote
- Each buyer can vote exactly once (for or against)
- Voting window is configurable via `votingDuration`
- Vote outcome: `totalVote > totalVoteAgainst` → contractor wins

---

## 💸 Fund Handling Logic

Funds follow a strict lifecycle:

- **Locked** during Booking and Voting phases
- **Released** only after voting ends and state is Settled

| Outcome                   | Function                | Action                                       |
| ------------------------- | ----------------------- | -------------------------------------------- |
| Votes for > Votes against | `claimFundContractor()` | Entire contract balance sent to contractor   |
| Votes for ≤ Votes against | `claimFundUser()`       | Each buyer claims their own deposited amount |

### ETH Transfer Safety:

- Uses `call{value: amount}("")` (recommended pattern)
- State updated **before** external calls (checks-effects-interactions)
- `nonReentrant` modifier on both claim functions
- Double-claim prevention via `fundClaimed` / `contractFundClaimed` flags
- `receive()` function accepts force-sent ETH

---

## 🔐 Security Features

| Protection                | Implementation                                                 |
| ------------------------- | -------------------------------------------------------------- |
| Reentrancy guard          | Custom `nonReentrant` modifier with `_locked` flag             |
| State machine enforcement | All functions gated by `ProjectState` checks                   |
| No owner lock-in          | `moveToVoting()` is public — anyone can trigger after deadline |
| Auto-settlement           | `_autoSettleIfNeeded()` called in both claim paths             |
| Constructor validation    | All parameters validated `> 0`                                 |
| CEI pattern               | State zeroed before ETH transfer in all payouts                |
| No vote deadband          | `<=` condition prevents fund-locking edge cases                |

---

## 📡 Events

| Event                                   | Emitted When              |
| --------------------------------------- | ------------------------- |
| `FlatBooked(buyer, amount, flatIndex)`  | A buyer books a flat      |
| `VoteCast(voter)`                       | A buyer votes in favor    |
| `VoteCastAgainst(voter)`                | A buyer votes against     |
| `ContractorClaimed(contractor, amount)` | Contractor claims funds   |
| `BuyerRefunded(buyer, amount)`          | A buyer claims a refund   |
| `StateChanged(from, to)`                | Project state transitions |

---

## 🧪 How to Run

1. Open [Remix IDE](https://remix.ethereum.org)
2. Create a new file: `PrestigeTowers.sol`
3. Paste the contract code
4. Compile using **Solidity ^0.8.24**
5. Deploy with constructor parameters, e.g.:
   - `_totalFlats`: `10`
   - `_flatPrice`: `10000000000000000000` (10 ETH)
   - `_projectName`: `"Prestige Towers"`
   - `_endTime`: `3600` (1 hour)
   - `_votingDuration`: `1800` (30 minutes)
6. Interact using different accounts for Owner and Buyers

---

## 📂 Project Structure

```
├── PrestigeTowers.sol   # Main smart contract
└── README.md            # Documentation
```

---

## 📘 Learning Outcomes

By studying this project, you learn:

- How to design state-machine-driven smart contracts
- Checks-effects-interactions pattern for safe ETH transfers
- Reentrancy protection without external libraries
- On-chain voting with two-sided vote tracking
- Constructor parameter validation and defensive programming
- Event-driven architecture for off-chain indexing

---

## ⚠️ Disclaimer

This project has been **internally audited and hardened** but has **not undergone a formal third-party audit**. It is intended for **educational and demonstration purposes**.

For production deployment, additionally consider:

- Formal verification
- Third-party security audit
- Integration with battle-tested libraries (e.g., OpenZeppelin)
- Off-chain data storage for sensitive information

---

## 👨‍💻 Author

Built as part of a **Solidity smart contract learning journey**.  
Feel free to fork, experiment, and improve.

---
