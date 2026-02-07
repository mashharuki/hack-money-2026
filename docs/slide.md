---
marp: true
theme: gaia
paginate: true
backgroundColor: "#0f172a"
color: "#f8fafc"
size: 16:9
style: |
  /* Custom Palette */
  :root {
    --highlight: #38bdf8;
    --accent: #a855f7;
    --bg-dark: #0f172a;
    --card-bg: rgba(30, 41, 59, 0.85);
  }
  
  /* Global Resets */
  section {
    font-family: 'Inter', system-ui, sans-serif;
    letter-spacing: -0.01em;
    font-size: 28px; /* Slightly smaller base font to prevent overflow */
    padding: 30px 50px; /* More padding */
  }
  
  h1, h2, h3 {
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 0.5em;
  }
  
  h1 {
    background: linear-gradient(135deg, var(--highlight), var(--accent));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    font-size: 2.5em;
  }
  
  strong {
    color: var(--highlight);
    font-weight: 700;
  }
  
  /* Tables */
  table {
    width: 100%;
    font-size: 0.8em; /* Prevent table overflow */
    border-collapse: separate;
    border-spacing: 0 8px; /* Row spacing */
  }
  th, td {
    padding: 12px 20px;
    border: none;
    background: rgba(255, 255, 255, 0.05);
  }
  th {
    background: rgba(255, 255, 255, 0.1);
    color: var(--highlight);
    text-align: left;
    border-radius: 8px 8px 0 0;
  }
  tr td:first-child { border-radius: 8px 0 0 8px; }
  tr td:last-child { border-radius: 0 8px 8px 0; }
  
  /* Layouts with safer gaps */
  section.split {
    display: grid;
    grid-template-columns: 48% 48%; /* Explicit width to prevent overflow */
    gap: 4%;
    align-items: center;
  }
  section.split-3 {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 1rem;
    align-content: center;
  }
  
  /* Components */
  div.card {
    background: var(--card-bg);
    backdrop-filter: blur(12px);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 16px;
    padding: 1.5rem;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
    height: 100%; /* Fill container */
    box-sizing: border-box;
  }
  div.card h3 {
    margin-top: 0;
    color: var(--highlight);
    font-size: 1.1em;
    border-bottom: 1px solid rgba(255,255,255,0.1);
    padding-bottom: 0.5em;
  }
  
  /* Utilities */
  .text-center { text-align: center; }
  .text-right { text-align: right; }
  .small { font-size: 0.7em; opacity: 0.8; }
  .center-content { align-content: center; justify-items: center; }

  /* Diagram fixes */
  .mermaid svg { max-height: 400px; }

---

<!-- _class: lead -->

# Zombie L2 Clearinghouse
## Turning "Dead" Compute into Revenue

**ETH Global HackMoney 2026**
*Uniswap v4 × Yellow × Arc*

![bg opacity:0.3 blur:8px](https://images.unsplash.com/photo-1639322537228-f710d846310a?auto=format&fit=crop&w=1920&q=80)

---

<!-- _class: split -->

<div class="card">

### 💀 The Crisis
**"L2s are bleeding."**

*   **No Users** = Zero Revenue
*   **Fixed Costs** (Sequencers, Nodes) remain monthly
*   **Result**: Chains die before finding Product-Market Fit

</div>

<div class="card">

### 💎 The Opportunity
**"Idle Compute is an Asset."**

*   Low activity chains offer **Record Low Fees**
*   We tokenize this capacity into **Compute Tokens (CPT)**
*   We arbitrage it for stable profit

</div>

---

# <!-- fit --> The Solution: **Financialize L2 Compute**

Zombie L2 Clearinghouse creates a market where:

1.  **L2s** mint idle capacity as **Compute Tokens (CPT)**.
2.  **Uniswap v4** prices CPT dynamically based on utilization.
3.  **Bots** arbitrage price gaps across chains via **Yellow**.
4.  **Profits** are settled in **USDC** via **Arc** to fund L2 ops.

> "Don't just scale Ethereum. **Survive.**"

---

<!-- _class: split-3 -->

<div class="card text-center">

### 1. Price
**Uniswap v4**
<br>
CPT / USDC Pools
<br><br>
<span class="small">Dynamic fees via Hooks adjust spread based on real-time chain utilization signaling.</span>

</div>

<div class="card text-center">

### 2. Execute
**Yellow Network**
<br>
State Channels
<br><br>
<span class="small">Gasless, high-frequency arbitrage sessions between liquidity pools.</span>

</div>

<div class="card text-center">

### 3. Settle
**Arc + Circle**
<br>
USDC Vaults
<br><br>
<span class="small">Real revenue settled in stablecoins to cover operational expenses.</span>

</div>

---

## Token Flow Architecture

```mermaid
flowchart LR
    L2[L2 Operator] -->|Mint CPT| UNI[Uniswap v4]
    TRADER[Traders] -->|Speculate| UNI
    
    UNI -.->|Arb Signal| YELLOW[Yellow Session]
    
    YELLOW -->|Gasless Trade| UNI
    YELLOW -->|Net Profit| ARC[Arc Settlement]
    ARC -->|USDC| VAULT[Operator Vault]
    
    style UNI fill:#ff007a,stroke:#fff
    style YELLOW fill:#facc15,stroke:#fff,color:#000
    style ARC fill:#3b82f6,stroke:#fff
```

---

<div class="card">

### Why Tokenize Compute?
**From "Cloud" to "Commodity"**

Just like oil or wheat, **blockspace** is a resource. <br/> Standardizing it as **CPT (1M Gas Units)** enables:

*   **For Devs**: Pre-purchase budget (Hedging)
*   **For Traders**: Short/Long congestion
*   **For L2s**: Monetize empty blocks immediately

</div>

---

## The Tech Stack (HackMoney Stack)

<div class="card">

| Component | Technology | Role |
| :--- | :--- | :--- |
| **Pricing** | **Uniswap v4 Hooks** | Adjusts spread/fees based on real-time chain utilization. |
| **Execution** | **Yellow SDK** | Off-chain "Sessions" for 1000x faster, gas-free arbitrage. |
| **Settlement** | **Arc + CCTP** | Cross-chain USDC finality to consolidate revenue. |
| **Targets** | **Base / WorldCoin** | Deploying CPT contracts on sepola testnets. |

</div>

---

<!-- _class: lead -->

## ⚡️ Demo Scenario

1.  **Base Sepolia** gets busy (High Usage) → **CPT ↑ Price Up**
2.  **WorldCoin** is empty (Low Usage) → **CPT ↓ Price Down**
3.  **Yellow Bot** detects gap & executes arb cycle
4.  **USDC Profit** lands in the Operator Vault

---

# Impact

<div class="split">

<div class="card">

### For L2 Operators
*   **Immediate Revenue** from idle hardware.
*   Extends runway during "Zombie" phases.
*   Turns fixed costs into variable assets.

</div>

<div class="card">

### For Ethereum
*   Prevents L2 centralization/death.
*   Creates a decentralized compute market.
*   **Values Diversity** over raw throughput.

</div>

</div>

---

<!-- _class: lead -->
<!-- _footer: "ETH Global HackMoney 2026" -->

# Thank You
**Zombie L2 Clearinghouse**

*Code & Demo Available on Github*

![bg opacity:0.1](https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=1920&q=80)
