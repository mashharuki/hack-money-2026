# Project Overview: Ghost Yield

**Ghost Yield** is a financial layer that tokenizes computational resources of underutilized Ethereum L2 chains as **CPT (Compute Token)** and generates USDC revenue via gasless arbitrage.

## Core Value
- **For L2 Operators**: Monetize idle capacity as a stable revenue source (USDC).
- **For Traders**: Arbitrage gas price volatility.
- **For Developers**: Future cost hedging.

## Key Components
1.  **Compute Token (CPT)**: ERC20 representing gas units (GSU).
    - 1 CPT = 1,000,000 GSU (Gas Standard Unit).
    - Has Expiration Epoch.
2.  **Uniswap v4 Market**: CPT/USDC pool with **Hooks** that dynamicsally adjust fees/spread based on L2 utilization.
    - Uses "Utilization Hook" to price idle capacity cheaper.
3.  **Yellow Network**: Gasless, high-speed intent-based arbitrage.
4.  **Arc + Circle**: Settlement of arbitrage profits into USDC managed in an **Operator Vault**.

## Target Chains
- Base Sepolia
- WorldCoin Sepolia

## Problem Solved
Addresses the "Valley of Death" for L2s where lack of users leads to zero revenue but constant fixed costs. Ghost Yield creates a market for execution capacity independent of immediate user demand.
