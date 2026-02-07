import { createPublicClient, createWalletClient, http, parseAbi, type Address, type Hex } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { loadOracleConfig, type ChainOracleConfig, type OracleConfig } from './config.js';
import { Logger } from '../lib/logger.js';
import { withRetry } from '../lib/retry.js';
import type { ILogger } from './types.js';

type BlockData = { gasUsed: bigint; gasLimit: bigint };

const COMPONENT = 'OracleUpdater';
const ORACLE_ABI = parseAbi([
  'function setUtilizationFromBot(uint256 utilization, uint256 timestamp) external',
]);

export interface UpdateCycleDeps {
  fetchBlocks: (rpcUrl: string, window: number) => Promise<BlockData[]>;
  pushUpdate: (
    rpcUrl: string,
    chain: ChainOracleConfig,
    utilization: number,
    timestamp: number,
    privateKey: Hex,
  ) => Promise<Hex>;
}

export function calculateEmaUtilization(blocks: BlockData[]): number {
  if (blocks.length === 0) {
    return 0;
  }

  const window = blocks.length;
  const alpha = 2 / (window + 1);

  let ema = Number(blocks[0].gasUsed) / Number(blocks[0].gasLimit);
  for (let i = 1; i < blocks.length; i++) {
    const ratio = Number(blocks[i].gasUsed) / Number(blocks[i].gasLimit);
    ema = alpha * ratio + (1 - alpha) * ema;
  }

  const utilization = Math.round(ema * 100);
  return Math.max(0, Math.min(100, utilization));
}

export async function fetchRecentBlocks(rpcUrl: string, window: number): Promise<BlockData[]> {
  const client = createPublicClient({ transport: http(rpcUrl) });
  const latest = await client.getBlockNumber();
  const blocks: BlockData[] = [];

  for (let i = 0; i < window; i++) {
    const block = await client.getBlock({ blockNumber: latest - BigInt(i) });
    blocks.push({ gasUsed: block.gasUsed, gasLimit: block.gasLimit });
  }

  return blocks;
}

export async function pushOracleUpdate(
  rpcUrl: string,
  chain: ChainOracleConfig,
  utilization: number,
  timestamp: number,
  privateKey: Hex,
): Promise<Hex> {
  const account = privateKeyToAccount(privateKey);
  const client = createWalletClient({
    account,
    transport: http(rpcUrl),
  });

  return client.writeContract({
    address: chain.oracleAddress as Address,
    abi: ORACLE_ABI,
    functionName: 'setUtilizationFromBot',
    args: [BigInt(utilization), BigInt(timestamp)],
    chain: undefined,
  });
}

export async function runUpdateCycle(
  chain: ChainOracleConfig,
  privateKey: Hex,
  logger: ILogger,
  deps: UpdateCycleDeps = {
    fetchBlocks: fetchRecentBlocks,
    pushUpdate: pushOracleUpdate,
  },
): Promise<{ chain: string; utilization: number; txHash: Hex; usedFallback: boolean }> {
  let usedFallback = false;
  let blocks: BlockData[];

  try {
    blocks = await deps.fetchBlocks(chain.primaryRpc, chain.emaWindow);
  } catch (primaryErr) {
    usedFallback = true;
    logger.warn(COMPONENT, 'Primary RPC failed, switching to fallback RPC', {
      chain: chain.chainName,
      primaryRpc: chain.primaryRpc,
      fallbackRpc: chain.fallbackRpc,
      error: primaryErr instanceof Error ? primaryErr.message : String(primaryErr),
    });
    blocks = await deps.fetchBlocks(chain.fallbackRpc, chain.emaWindow);
  }

  const utilization = calculateEmaUtilization(blocks);
  const timestamp = Math.floor(Date.now() / 1000);
  const rpcForWrite = usedFallback ? chain.fallbackRpc : chain.primaryRpc;

  const txHash = await withRetry(
    () => deps.pushUpdate(rpcForWrite, chain, utilization, timestamp, privateKey),
    {
      maxRetries: 2,
      baseDelayMs: 500,
      maxDelayMs: 2_000,
      backoffMultiplier: 2,
    },
    logger,
    COMPONENT,
  );

  logger.info(COMPONENT, 'Oracle utilization updated from bot', {
    chain: chain.chainName,
    source: 'bot',
    utilization,
    txHash,
    usedFallback,
  });

  return {
    chain: chain.chainName,
    utilization,
    txHash,
    usedFallback,
  };
}

export class OracleUpdaterBot {
  private readonly config: OracleConfig;
  private readonly logger: ILogger;
  private readonly deps: UpdateCycleDeps;
  private timers: NodeJS.Timeout[] = [];
  private running = false;

  constructor(config: OracleConfig, logger: ILogger, deps?: UpdateCycleDeps) {
    this.config = config;
    this.logger = logger;
    this.deps = deps ?? {
      fetchBlocks: fetchRecentBlocks,
      pushUpdate: pushOracleUpdate,
    };
  }

  async start(): Promise<void> {
    if (this.running) {
      return;
    }
    if (!this.config.deployerPrivateKey) {
      throw new Error('DEPLOYER_PRIVATE_KEY is required for oracle updater');
    }

    this.running = true;
    const privateKey = this.config.deployerPrivateKey as Hex;

    for (const chain of Object.values(this.config.chains)) {
      const execute = async () => {
        try {
          await runUpdateCycle(chain, privateKey, this.logger, this.deps);
        } catch (err) {
          this.logger.error(COMPONENT, 'Oracle update cycle failed', {
            chain: chain.chainName,
            source: 'bot',
            error: err instanceof Error ? err.message : String(err),
          });
        }
      };

      await execute();
      const timer = setInterval(() => {
        void execute();
      }, chain.botUpdateInterval);
      this.timers.push(timer);
    }
  }

  stop(): void {
    for (const timer of this.timers) {
      clearInterval(timer);
    }
    this.timers = [];
    this.running = false;
  }
}

async function main(): Promise<void> {
  const config = loadOracleConfig();
  const logger = new Logger('INFO');
  const bot = new OracleUpdaterBot(config, logger);
  await bot.start();
}

if (process.argv[1]?.endsWith('oracle-updater.ts')) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
