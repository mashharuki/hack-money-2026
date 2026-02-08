# Technology Stack & Architecture

## Architecture
- **Contracts**: Solidity (Foundry) in `contract/`
  - CPT Token, Operator Vault, Uniswap v4 utilization hooks.
- **Frontend**: Next.js 16 (App Router), React 19, Tailwind 4 in `frontend/`
  - Uses Biome for linting/formatting.
  - Shadcn/ui for components.
- **Scripts**: TypeScript (`tsx`, `viem`, `jose`) in `scripts/`
  - Arbitrage logic, Arc transfer, Setup scripts.
- **Documentation**: `.kiro/steering/` (Source of Truth).

## Key Technologies
- **Protocol**: Uniswap v4 (Hooks), Yellow Network (State Channels), Circle/Arc (USDC/CCTP)
- **Dev Tools**: Foundry, Biome, Bun (Frontend package manager), Jose (JWE/JWS)

## Development Standards
- **Language**: English for internal thought/code, Japanese for Markdown output (docs).
- **Workflow**: Kiro Spec Driven Development (Steering -> Specs -> Implementation).
  - 3-phase approval: Requirements -> Design -> Tasks.
- **Code Style**: 
  - Strict TypeScript.
  - Conventional Commits.
  - NatSpec for Solidity.
  - `biome` for frontend, `forge fmt` for contracts.
