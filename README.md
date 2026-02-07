# 🏢 PrestigeTowers Smart Contract

A blockchain-based **real estate booking & settlement system** built using Solidity.  
This project demonstrates **state-driven contract design**, **secure fund handling**, and **on-chain voting mechanics** in an educational, interview-friendly manner.

---

## 📌 Project Overview

The **PrestigeTowers Smart Contract** models a real-world apartment booking scenario where:

- Buyers book flats and make staged payments
- Funds are securely locked in the contract
- Buyers vote on project completion
- Funds are released based on majority voting

The contract is intentionally designed to prioritize **clarity, safety, and explainability** over extreme optimization.

---

## 🧠 Core Design Philosophy

This contract is built around **explicit state management** and **defensive programming**.

### This ensures:
- Clear business logic
- Easier reasoning and debugging
- Safer access control
- Interview-friendly explanations

---

## 🔁 Project Lifecycle (State Machine)

```text
Booking  →  Voting  →  Settled
````

### States Explained:

* **Booking**

  * Buyers can book flats
  * Buyers can deposit remaining amounts
  * No voting allowed

* **Voting**

  * Booking is closed
  * Verified buyers can vote
  * One vote per buyer
  * Voting lasts for a fixed duration

* **Settled**

  * Final state
  * Funds are released based on voting result
  * No further interaction allowed

State transitions are explicit and guarded.

---

## 👥 Buyer Identity Design

Buyer existence is tracked explicitly using:

```solidity
mapping(address => bool) buyerExists;
```

### Why this matters:

* Avoids unsafe array index assumptions
* Prevents duplicate buyers
* Makes buyer checks explicit and readable
* Improves auditability and reasoning

---

## 🗳️ Voting Mechanism

The voting system enforces strict rules:

* Only verified buyers can vote
* Owner cannot vote
* One vote per buyer
* Voting automatically expires after a fixed duration
* Majority rule decides fund flow

Voting is time-bound and enforced using an on-chain timestamp window.

---

## 💸 Fund Handling Logic

Funds follow a strict lifecycle:

* Locked during **Booking** and **Voting**
* Released only after voting ends
* Majority approval sends funds to contractor
* Otherwise, buyers can claim refunds

### ETH Transfer Safety:

* Uses `call{value: amount}` (modern & safe)
* State is updated **before** transfers
* Double-claim prevention enforced

---

## 🔐 Security & Safety Considerations

This contract intentionally avoids common pitfalls:

* No early fund withdrawal
* No reentrancy risk in payout logic
* No loops during fund distribution
* No reliance on external automation
* All critical actions are state-guarded

Settlement happens via **lazy evaluation**, ensuring correctness without background execution.

---

## 🧪 How to Run the Contract

1. Open **Remix IDE**
2. Create a new file: `PrestigeTowers.sol`
3. Paste the contract code
4. Compile using **Solidity ^0.8.x**
5. Deploy with constructor parameters
6. Interact using different accounts:

   * Owner (contractor)
   * Buyers (multiple addresses)

---

## 📘 Learning Outcomes

By building this project, you learn:

* How to design real-world smart contracts
* Why state machines matter in Solidity
* How to manage shared funds safely
* How on-chain voting works
* How to reason about trust boundaries
* How Ethereum contracts handle time and execution

---


## 📌 Final Notes

This contract focuses on:

* Clarity over complexity
* Explicit logic over magic
* Learning over optimization

It is intentionally **not over-engineered**, making it ideal for understanding, teaching, and interviews.

---

## 👨‍💻 Author

Built as part of a **Solidity smart contract learning journey**.
Feel free to fork, experiment, and improve.

---
