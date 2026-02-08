/**
 * Debug script: Check on-chain pool state for all deployed chains
 * Usage: pnpm tsx scripts/debug/check-pool-state.ts
 */
import 'dotenv/config';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createPublicClient, http, formatUnits } from 'viem';

const __dirname = dirname(fileURLToPath(import.meta.url));
const CONTRACT_DIR = resolve(__dirname, '../../contract');

const STATE_VIEW_ABI = [
  {
    type: 'function',
    name: 'getSlot0',
    inputs: [{ name: 'poolId', type: 'bytes32', internalType: 'PoolId' }],
    outputs: [
      { name: 'sqrtPriceX96', type: 'uint160', internalType: 'uint160' },
      { name: 'tick', type: 'int24', internalType: 'int24' },
      { name: 'protocolFee', type: 'uint24', internalType: 'uint24' },
      { name: 'lpFee', type: 'uint24', internalType: 'uint24' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getLiquidity',
    inputs: [{ name: 'poolId', type: 'bytes32', internalType: 'PoolId' }],
    outputs: [
      { name: 'liquidity', type: 'uint128', internalType: 'uint128' },
    ],
    stateMutability: 'view',
  },
] as const;

const ERC20_ABI = [
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'decimals',
    inputs: [],
    outputs: [{ name: '', type: 'uint8' }],
    stateMutability: 'view',
  },
] as const;

interface DeployedAddresses {
  [chain: string]: {
    cpt?: string;
    oracle?: string;
    hook?: string;
    poolId?: string;
  };
}

const STATE_VIEW_ADDRESSES: Record<string, `0x${string}`> = {
  'base-sepolia': '0x571291b572ed32ce6751a2cb2486ebee8defb9b4',
  'unichain-sepolia': '0xc199f1072a74d4e905aba1a84d9a45e2546b6222',
  'sepolia': '0xe1dd9c3fa50edb962e442f60dfbc432e24537e4c',
};

const RPC_URLS: Record<string, string> = {
  'base-sepolia': process.env.BASE_SEPOLIA_RPC_URL || process.env.CHAIN_A_RPC_URL || 'https://sepolia.base.org',
  'unichain-sepolia': process.env.UNICHAIN_SEPOLIA_RPC_URL || process.env.CHAIN_B_RPC_URL || 'https://sepolia.unichain.org',
  'sepolia': process.env.SEPOLIA_RPC_URL || 'https://eth-sepolia.g.alchemy.com/v2/demo',
};

function sqrtPriceX96ToPrice(
  sqrtPriceX96: bigint,
  cptAddress: string,
  usdcAddress: string,
  cptDecimals: number,
  usdcDecimals: number,
): number {
  const Q96 = 2n ** 96n;
  const Q192 = Q96 * Q96;
  const cptIsToken0 = cptAddress.toLowerCase() < usdcAddress.toLowerCase();
  const sqrtPriceSq = sqrtPriceX96 * sqrtPriceX96;

  if (cptIsToken0) {
    const decimalAdjust = 10n ** BigInt(cptDecimals - usdcDecimals);
    const scaled = (sqrtPriceSq * decimalAdjust * 10n ** 18n) / Q192;
    return Number(scaled) / 1e18;
  } else {
    const decimalAdjust = 10n ** BigInt(cptDecimals - usdcDecimals);
    const scaled = (Q192 * decimalAdjust * 10n ** 18n) / sqrtPriceSq;
    return Number(scaled) / 1e18;
  }
}

async function checkChain(chainName: string) {
  const deployed = JSON.parse(readFileSync(resolve(CONTRACT_DIR, 'deployed-addresses.json'), 'utf-8')) as DeployedAddresses;
  const usdcAddresses = JSON.parse(readFileSync(resolve(CONTRACT_DIR, 'usdc-addresses.json'), 'utf-8')) as Record<string, string>;
  const poolManagerAddresses = JSON.parse(readFileSync(resolve(CONTRACT_DIR, 'uniswap-v4-addresses.json'), 'utf-8')) as Record<string, string>;

  const chainData = deployed[chainName];
  if (!chainData?.poolId) {
    console.log(`  ⚠️  No poolId for ${chainName}, skipping`);
    return;
  }

  const stateView = STATE_VIEW_ADDRESSES[chainName];
  if (!stateView) {
    console.log(`  ⚠️  No StateView for ${chainName}, skipping`);
    return;
  }

  const rpcUrl = RPC_URLS[chainName];
  if (!rpcUrl) {
    console.log(`  ⚠️  No RPC URL for ${chainName}, skipping`);
    return;
  }

  const client = createPublicClient({ transport: http(rpcUrl) });
  const poolId = chainData.poolId as `0x${string}`;
  const cptAddress = chainData.cpt as `0x${string}`;
  const usdcAddress = usdcAddresses[chainName] as `0x${string}`;
  const poolManager = poolManagerAddresses[chainName] as `0x${string}`;

  console.log(`\n${'─'.repeat(60)}`);
  console.log(`  Chain: ${chainName}`);
  console.log(`${'─'.repeat(60)}`);
  console.log(`  CPT:         ${cptAddress}`);
  console.log(`  USDC:        ${usdcAddress}`);
  console.log(`  Hook:        ${chainData.hook}`);
  console.log(`  Oracle:      ${chainData.oracle}`);
  console.log(`  PoolManager: ${poolManager}`);
  console.log(`  PoolId:      ${poolId}`);
  console.log(`  StateView:   ${stateView}`);

  const cptIsToken0 = cptAddress.toLowerCase() < usdcAddress.toLowerCase();
  console.log(`  Token order: CPT is token${cptIsToken0 ? '0' : '1'}`);

  try {
    const [slot0, liquidity] = await Promise.all([
      client.readContract({
        address: stateView,
        abi: STATE_VIEW_ABI,
        functionName: 'getSlot0',
        args: [poolId],
      }),
      client.readContract({
        address: stateView,
        abi: STATE_VIEW_ABI,
        functionName: 'getLiquidity',
        args: [poolId],
      }),
    ]);

    const [sqrtPriceX96, tick, protocolFee, lpFee] = slot0;

    console.log(`\n  Pool State:`);
    console.log(`    sqrtPriceX96: ${sqrtPriceX96}`);
    console.log(`    tick:         ${tick}`);
    console.log(`    protocolFee:  ${protocolFee}`);
    console.log(`    lpFee:        ${lpFee}`);
    console.log(`    liquidity:    ${liquidity}`);

    if (sqrtPriceX96 === 0n) {
      console.log(`\n  ❌ Pool NOT initialized (sqrtPriceX96 = 0)`);
      return;
    }

    if (liquidity === 0n) {
      console.log(`\n  ⚠️  Pool has ZERO liquidity - swaps will fail!`);
    }

    const priceUsdcPerCpt = sqrtPriceX96ToPrice(sqrtPriceX96, cptAddress, usdcAddress, 18, 6);
    console.log(`    Price (USDC/CPT): ${priceUsdcPerCpt.toFixed(8)}`);

    // Check deployer balances
    const deployerAddress = '0x51908F598A5e0d8F1A3bAbFa6DF76F9704daD072';
    const [cptBalance, usdcBalance] = await Promise.all([
      client.readContract({
        address: cptAddress,
        abi: ERC20_ABI,
        functionName: 'balanceOf',
        args: [deployerAddress as `0x${string}`],
      }),
      client.readContract({
        address: usdcAddress,
        abi: ERC20_ABI,
        functionName: 'balanceOf',
        args: [deployerAddress as `0x${string}`],
      }),
    ]);

    console.log(`\n  Deployer Balances (${deployerAddress}):`);
    console.log(`    CPT:  ${formatUnits(cptBalance, 18)}`);
    console.log(`    USDC: ${formatUnits(usdcBalance, 6)}`);

    // Check PoolManager balances (to see if liquidity is locked)
    const [pmCptBalance, pmUsdcBalance] = await Promise.all([
      client.readContract({
        address: cptAddress,
        abi: ERC20_ABI,
        functionName: 'balanceOf',
        args: [poolManager],
      }),
      client.readContract({
        address: usdcAddress,
        abi: ERC20_ABI,
        functionName: 'balanceOf',
        args: [poolManager],
      }),
    ]);

    console.log(`\n  PoolManager Balances:`);
    console.log(`    CPT:  ${formatUnits(pmCptBalance, 18)}`);
    console.log(`    USDC: ${formatUnits(pmUsdcBalance, 6)}`);

  } catch (err) {
    console.log(`\n  ❌ Error: ${err instanceof Error ? err.message : String(err)}`);
  }
}

async function main() {
  console.log('╔══════════════════════════════════════════════════════════╗');
  console.log('║          Pool State Checker - Ghost Yield                ║');
  console.log('╚══════════════════════════════════════════════════════════╝');

  const chainsToCheck = ['base-sepolia', 'unichain-sepolia', 'sepolia'];

  for (const chain of chainsToCheck) {
    await checkChain(chain);
  }

  console.log(`\n${'═'.repeat(60)}`);
}

main().catch(console.error);
