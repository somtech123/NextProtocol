
# NexProtocol — Decentralized Freelance Payment Protocol

A trustless, transparent, and token-powered protocol for freelance work — eliminating middlemen, ensuring fair pay, and rewarding the community.

---

## Table of Contents

- [Overview](#overview)
- [Screenshots](#screenshots)
- [Demo](#demo)
- [Architecture](#architecture)
- [Smart Contracts](#smart-contracts)
  - [NexToken (NXT)](#nextoken-nxt)
  - [Escrow](#escrow)
  - [VestingToken](#vestingtoken)
- [Token Distribution](#token-distribution)
- [Getting Started](#getting-started)
- [Deployment](#deployment)
- [Usage Guide](#usage-guide)
- [Security](#security)
- [License](#license)

---

## overview

**NexProtocol** is a fully decentralized freelance payment system built on Ethereum. It replaces traditional freelance platforms by enabling clients and freelancers to interact directly through smart contracts — with no fees, no censorship, and no single point of failure.

Payments are made in **NXT**, the protocol's native ERC20 token. Work is broken into **milestones**, funds are held in **escrow**, and tokens are **vested** for team members and investors ensuring long-term alignment.

### Why NexProtocol?

| Traditional Platforms | NexProtocol |
|---|---|
| 20% platform fees | 0% platform fees |
| Centralized dispute resolution | Smart contract enforced |
| Fiat only | NXT token payments |
| No token ownership | Community ownership via NXT |
| Opaque fund holding | Transparent on-chain escrow |

## Screenshots
> View Screenshots for all the deployed contracts on testnet
```
nextprotocol/
└── assets/
    └── screenshots/
        ├── Screenshot (1).png.png
        ├── Screenshot (2).png.png
        └── Screenshot (3).png.png
```

## Demo

[![NexProtocol Demo](./assets/thumbnail.png)](https://drive.google.com/file/d/1w-q6SlEXO5hKhMLI3QEprET8zckfumby/view?usp=drive_link)

> Click the image above to watch the full demo
## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     NexProtocol                         │
│                                                         │
│   ┌─────────────┐     ┌──────────────┐                  │
│   │  NexToken   │────▶│    Escrow    │                  │
│   │   (NXT)     │     │  (Milestone  │                  │
│   │  ERC20 +    │     │   Payments)  │                  │
│   │  Burn 2%    │     └──────────────┘                  │
│   └─────────────┘                                       │
│          │                                              │
│          │            ┌──────────────┐                  │
│          └───────────▶│ VestingToken │                  │
│                       │  (Team &     │                  │
│                       │  Investors)  │                  │
│                       └──────────────┘                  │
│                                                         │
│   Distribution: Airdrop | Team Vesting | Ecosystem      │
└─────────────────────────────────────────────────────────┘
```

---
## Smart Contracts

### NexToken (NXT)

The core currency of the protocol. A deflationary ERC20 token with built-in burn mechanics, role-based access control, and emergency pause functionality.

**Token Details**

| Property | Value |
|---|---|
| Name | NexToken |
| Symbol | NXT |
| Max Supply | 21,000,000 NXT |
| Decimals | 18 |
| Burn Rate | 2% on every transfer |
| Standard | ERC20 + ERC20Pausable + AccessControl |

**Roles**

| Role | Permission |
|---|---|
| `DEFAULT_ADMIN_ROLE` | Grant/revoke all roles |
| `DISTRIBUTOR_ROLE` | Distribute tokens, run airdrops |
| `PAUSER_ROLE` | Pause/unpause the contract |
| `BURNER_ROLE` | Emergency burn while paused |

**Key Functions**

```solidity
// Distribute tokens to an address
distribute(address to, uint256 amount)

// Airdrop tokens to multiple addresses at once
airdrop(address[] calldata recipients, uint256 amount)

// Allocate vesting share (one-time)
allocateVesting(address to)

// Emergency burn — only when paused
emergencyBurn(uint256 amount)
```

**Burn Mechanic**

Every wallet-to-wallet transfer burns 2% of the transferred amount:

```
User sends 1000 NXT
→ 20 NXT burned 🔥
→ 980 NXT received ✅
→ total supply decreases over time
```

> Contract-to-wallet transfers (distributions, airdrops, escrow payments) are **exempt** from the burn fee.

---


### Escrow

The heart of the protocol. Clients create jobs with milestone-based payments — funds are locked in the contract and released only when milestones are completed and approved.

**Job Lifecycle**

```
1. Client creates job with milestones
   → tokens locked in escrow

2. Freelancer completes milestone
   → client reviews work

3. Client approves milestone
   → NXT released to freelancer

4. All milestones complete
   → job closed ✅
```

**Struct Definitions**

```solidity
struct Job {
    address     client;
    address     freelancer;
    uint256     totalAmount;
    bool        active;
    MileStone[] milestones;
}

struct MileStone {
    uint256 amount;
    bool    completed;
    bool    paid;
}
```

**Key Functions**

```solidity
// Create a new job with milestone amounts
createJob(address freelancer, uint256[] memory amounts)

// Mark a milestone as complete (client only)
completeMilestone(uint256 jobId, uint256 milestoneIndex)

// Release payment for completed milestone (client only)
payMilestone(uint256 jobId, uint256 milestoneIndex)

// View full job details including milestones
getJob(uint256 jobId)

// View all jobs for a freelancer
freelancerJobs(address freelancer)
```

**Before Creating a Job**

```solidity
// Step 1 — approve escrow to pull tokens
NexToken.approve(escrowAddress, totalAmount)

// Step 2 — create job
Escrow.createJob(freelancerAddress, [500, 300, 200])
// → 3 milestones: 500 NXT, 300 NXT, 200 NXT
// → 1000 NXT total locked in escrow
```

---


### VestingToken

Manages token distribution for **team members** and **investors** with configurable cliff periods and linear vesting schedules.

**How Vesting Works**

```
Deploy VestingToken
        │
        ▼
Cliff Period ──────────────────── No tokens claimable
        │
        ▼
Vesting Begins ────────────────── Tokens unlock linearly
        │
        ▼
Vesting Complete ──────────────── 100% claimable
```

**Constructor Parameters**

```solidity
constructor(
    address tokenAddress,  // NXT token address
    uint256 duration,      // total vesting length
    uint256 cliff,         // cliff period
    uint8   unit           // 1=seconds 2=minutes 3=hours 4=days
)
```

**Key Functions**

```solidity
// Add a beneficiary with percentage share
addBeneficiary(address recipient, uint256 percentShare, Role role)

// Claim vested tokens
claim()

// View vested amount for address
vestedAmount(address beneficiary)

// Full diagnostic view
diagnose(address beneficiary)
```

**Roles**

```solidity
enum Role {
    None,
    Team,       // core team members
    Investor,   // early investors
    Advisor     // protocol advisors
}
```

**Example Setup**

```solidity
// 12 month vesting, 3 month cliff, in days
VestingToken vesting = new VestingToken(NXT_ADDRESS, 365, 90, 4);

// add team member — 15% share
vesting.addBeneficiary(teamWallet, 15, Role.Team);

// add investor — 10% share
vesting.addBeneficiary(investorWallet, 10, Role.Investor);

// fund the contract
NexToken.distribute(vestingAddress, 5_000_000);
```


---

## Token Distribution

Total Supply: **21,000,000 NXT**

```
┌─────────────────────────────────────────────────────┐
│              NXT Token Distribution                  │
│                                                      │
│  Ecosystem & Escrow    ████████████████  50%         │
│  Team Vesting          ████████          20%         │
│  Investor Vesting      ██████            15%         │
│  Airdrop               ████              10%         │
│  Advisors              █                  5%         │
└─────────────────────────────────────────────────────┘

Ecosystem (10,500,000 NXT) → Powers escrow payments
Team       (4,200,000 NXT) → 12mo vest, 3mo cliff
Investors  (3,150,000 NXT) → 24mo vest, 6mo cliff
Airdrop    (2,100,000 NXT) → Community distribution
Advisors   (1,050,000 NXT) → 6mo vest, 1mo cliff
```

---

## Getting Started

### Prerequisites

```bash
node >= 20.18.3
remix
git
foundry (optional)
```

### Installation

```bash
# clone the repo
git clone https://github.com/somtech123/NextProtocol

# cd nexprotocol

```

### Run Locally

```bash
# Using Remix — DEPLOY & RUN TRANSACTIONS

# Enviroment — Remix Vm 

# Deploy Contract — Deploy at Compiled Contract

```

### Run On Testnet

```bash
# Using Remix — DEPLOY & RUN TRANSACTIONS

# Enviroment — Injected MetaMask

# Deploy Contract — Deploy at Compiled Contract

```

---


## Deployment

### Deploy to Testnet (Sepolia)

```bash
# set your private key
export PRIVATE_KEY=your_private_key_here

# deploy
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Deployment Order

```
1. Deploy NexToken
   → copy NXT_ADDRESS

2. Deploy VestingToken(NXT_ADDRESS, duration, cliff, unit)
   → copy VESTING_ADDRESS

3. Deploy Escrow(NXT_ADDRESS)
   → copy ESCROW_ADDRESS

4. NexToken.allocateVesting(VESTING_ADDRESS)
   → sends vesting allocation

5. NexToken.airdrop([addresses], amount)
   → distributes airdrop

6. NexToken.distribute(ESCROW_ADDRESS, amount)
   → funds escrow pool
```

### Contract Addresses

| Contract | Network | Address |
|---|---|---|
| NexToken | Sepolia | `0xD3b5B57193B13762a783510d8D7ca98d2494E7dA` |
| Escrow | Sepolia | `0x3bCacacAe28cAFdC84d81d9F75a9226B26d9aC89 ` |
| VestingToken | Sepolia | `0x02Fbf5d486d018D99D7209CC5cb976e02539F62F` |

---


## Usage Guide

### For Clients

```
1. Get NXT tokens via airdrop or purchase
2. Approve Escrow contract to spend NXT
3. Create a job with milestone amounts
4. Review freelancer work per milestone
5. Approve milestones to release NXT payment
```

### For Freelancers

```
1. Receive job offer from client
2. Complete milestone work off-chain
3. Notify client for review
4. Receive NXT payment on approval
```

### For Team / Investors

```
1. Wait for cliff period to pass
2. Call claim() to receive vested tokens
3. Tokens unlock linearly over vesting period
4. Call claim() anytime to collect newly vested tokens
```

---
## Security

### Key Security Features

- **Reentrancy Protection** — state updated before all token transfers
- **Access Control** — role-based permissions on all sensitive functions
- **Pause Mechanism** — emergency pause stops all transfers instantly
- **Escrow Safety** — funds locked until explicit milestone approval
- **Vesting Lock** — team tokens cannot be dumped at launch
- **Burn Mechanic** — deflationary pressure protects long-term token value
- **One-time Vesting** — vesting allocation cannot be changed after set

### Known Considerations

- Clients must approve Escrow contract before creating jobs
- Vesting allocations are permanent and cannot be modified
- Emergency burn is only callable when contract is paused
- Milestone payments are non-reversible once sent

---

## License

MIT License — see [LICENSE](https://choosealicense.com/licenses/mit/) for details.

---
## Contributing

Pull requests are welcome. For major changes please open an issue first to discuss what you would like to change.

---


Built with ❤️ using Solidity

**[Documentation](#) · [Report Bug](#) · [Request Feature](#)**

