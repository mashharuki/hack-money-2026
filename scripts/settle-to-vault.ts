import { execSync } from 'child_process';
import * as fs from 'fs';

interface WalletBalance {
  token: {
    id: string;
    blockchain: string;
    name: string;
    symbol: string;
    decimals: number;
  };
  amount: string;
}

interface SettlementResult {
  success: boolean;
  transactionId?: string;
  txHash?: string;
  amount?: string;
  error?: string;
}

class VaultSettlementService {
  private apiKey: string;
  private sourceWalletId: string;
  private vaultWalletId: string;
  private entitySecretHex: string;
  private pubKeyPath: string;

  constructor() {
    this.apiKey = process.env.ARC_API_KEY || '';
    this.sourceWalletId = process.env.ARC_WALLET_ID_SOURCE || '';
    this.vaultWalletId = process.env.ARC_WALLET_ID_OPERATOR_VAULT || '';
    this.entitySecretHex = process.env.ENTITY_SECRET_HEX || '';
    this.pubKeyPath = '/tmp/arc_pubkey.pem';

    if (!this.apiKey || !this.sourceWalletId || !this.vaultWalletId) {
      throw new Error('Missing required environment variables');
    }

    if (!this.entitySecretHex) {
      throw new Error('ENTITY_SECRET_HEX not set in .env');
    }
  }

  private async fetchPublicKey(): Promise<void> {
    try {
      const response = execSync(
        `curl -s -H "Authorization: Bearer ${this.apiKey}" "https://api.circle.com/v1/w3s/config/entity/publicKey"`,
        { encoding: 'utf-8' }
      );
      const data = JSON.parse(response);
      fs.writeFileSync(this.pubKeyPath, data.data.publicKey);
      console.log('✓ Public key fetched');
    } catch (error) {
      throw new Error(`Failed to fetch public key: ${error}`);
    }
  }

  private encryptEntitySecret(): string {
    try {
      const secretBinPath = '/tmp/secret_vault.bin';
      const secretEncPath = '/tmp/secret_vault.enc';

      execSync(`printf "${this.entitySecretHex}" | xxd -r -p > ${secretBinPath}`);
      execSync(
        `openssl pkeyutl -encrypt -pubin -inkey ${this.pubKeyPath} -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 -pkeyopt rsa_mgf1_md:sha256 -in ${secretBinPath} -out ${secretEncPath}`
      );
      const ciphertext = execSync(`openssl base64 -A -in ${secretEncPath}`, {
        encoding: 'utf-8',
      }).trim();

      console.log('✓ Entity secret encrypted');
      return ciphertext;
    } catch (error) {
      throw new Error(`Failed to encrypt entity secret: ${error}`);
    }
  }

  async getBalance(walletId: string): Promise<WalletBalance[]> {
    try {
      const response = execSync(
        `curl -s -H "Authorization: Bearer ${this.apiKey}" "https://api.circle.com/v1/w3s/wallets/${walletId}/balances"`,
        { encoding: 'utf-8' }
      );
      const data = JSON.parse(response);

      if (data.code) {
        throw new Error(`API Error: ${data.message}`);
      }

      return data.data.tokenBalances || [];
    } catch (error) {
      throw new Error(`Failed to get balance: ${error}`);
    }
  }

  async getVaultAddress(): Promise<string> {
    try {
      const response = execSync(
        `curl -s -H "Authorization: Bearer ${this.apiKey}" "https://api.circle.com/v1/w3s/wallets/${this.vaultWalletId}"`,
        { encoding: 'utf-8' }
      );
      const data = JSON.parse(response);
      return data.data.wallet.address;
    } catch (error) {
      throw new Error(`Failed to get vault address: ${error}`);
    }
  }

  async settleToVault(
    tokenId: string,
    amount: string,
    vaultAddress: string
  ): Promise<SettlementResult> {
    try {
      await this.fetchPublicKey();
      const entityCiphertext = this.encryptEntitySecret();

      const idempotencyKey = execSync('uuidgen', { encoding: 'utf-8' }).trim();

      const payload = {
        idempotencyKey,
        walletId: this.sourceWalletId,
        tokenId,
        destinationAddress: vaultAddress,
        amounts: [amount],
        feeLevel: 'MEDIUM',
        entitySecretCiphertext: entityCiphertext,
      };

      const response = execSync(
        `curl -s -X POST "https://api.circle.com/v1/w3s/developer/transactions/transfer" -H "Authorization: Bearer ${this.apiKey}" -H "Content-Type: application/json" -d '${JSON.stringify(payload)}'`,
        { encoding: 'utf-8' }
      );

      const data = JSON.parse(response);

      if (data.code) {
        return {
          success: false,
          error: `${data.code}: ${data.message}`,
        };
      }

      const transactionId = data.data.id;
      console.log(`✓ Settlement initiated: ${transactionId}`);

      await new Promise((resolve) => setTimeout(resolve, 5000));

      const txResponse = execSync(
        `curl -s -H "Authorization: Bearer ${this.apiKey}" "https://api.circle.com/v1/w3s/transactions/${transactionId}"`,
        { encoding: 'utf-8' }
      );
      const txData = JSON.parse(txResponse);

      return {
        success: true,
        transactionId,
        txHash: txData.data.transaction.txHash,
        amount,
      };
    } catch (error) {
      return {
        success: false,
        error: String(error),
      };
    }
  }
}

async function main() {
  console.log('=== Operator Vault Settlement Script ===\n');
  console.log('This script simulates the final settlement flow:');
  console.log('Arbitrage profits → Operator Vault (USDC)\n');

  const service = new VaultSettlementService();

  console.log('1. Fetching SOURCE wallet balance...');
  const sourceBalance = await service.getBalance(service['sourceWalletId']);
  console.log('SOURCE Balance:');
  sourceBalance.forEach((b) => {
    console.log(`  ${b.token.symbol}: ${b.amount}`);
  });

  console.log('\n2. Fetching Operator Vault balance...');
  const vaultBalance = await service.getBalance(service['vaultWalletId']);
  console.log('Operator Vault Balance:');
  vaultBalance.forEach((b) => {
    console.log(`  ${b.token.symbol}: ${b.amount}`);
  });

  const usdcToken = sourceBalance.find((b) => b.token.symbol === 'USDC-TESTNET');
  if (!usdcToken) {
    console.error('\n✗ No USDC-TESTNET found in SOURCE wallet');
    process.exit(1);
  }

  const currentAmount = parseFloat(usdcToken.amount);
  if (currentAmount < 3) {
    console.error('\n✗ Insufficient USDC balance for settlement (need at least 3)');
    process.exit(1);
  }

  console.log('\n3. Getting Operator Vault address...');
  const vaultAddress = await service.getVaultAddress();
  console.log(`Operator Vault Address: ${vaultAddress}`);

  console.log('\n4. Settling 3 USDC-TESTNET to Operator Vault...');
  console.log('   (Simulating arbitrage profit settlement)');
  const result = await service.settleToVault(usdcToken.token.id, '3', vaultAddress);

  if (!result.success) {
    console.error(`\n✗ Settlement failed: ${result.error}`);
    process.exit(1);
  }

  console.log(`\n✓ Settlement completed!`);
  console.log(`  Transaction ID: ${result.transactionId}`);
  console.log(`  Tx Hash: ${result.txHash}`);
  console.log(`  Amount: ${result.amount} USDC-TESTNET`);

  console.log('\n5. Verifying balances after settlement...');
  const sourceBalanceAfter = await service.getBalance(service['sourceWalletId']);
  const vaultBalanceAfter = await service.getBalance(service['vaultWalletId']);

  console.log('SOURCE Balance (after):');
  sourceBalanceAfter.forEach((b) => {
    console.log(`  ${b.token.symbol}: ${b.amount}`);
  });

  console.log('Operator Vault Balance (after):');
  vaultBalanceAfter.forEach((b) => {
    console.log(`  ${b.token.symbol}: ${b.amount}`);
  });

  console.log('\n=== Settlement Complete ===');
  console.log('This demonstrates the final step of the Zombie L2 Clearinghouse:');
  console.log('Arbitrage profits are settled to the Operator Vault in USDC,');
  console.log('which can then be used to cover L2 infrastructure costs.');
}

main().catch((error) => {
  console.error('Error:', error.message);
  process.exit(1);
});
