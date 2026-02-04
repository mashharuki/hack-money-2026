import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

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

interface TransferResult {
  success: boolean;
  transactionId?: string;
  txHash?: string;
  error?: string;
}

class ArcTransferService {
  private apiKey: string;
  private sourceWalletId: string;
  private targetWalletId: string;
  private entitySecretHex: string;
  private pubKeyPath: string;

  constructor() {
    this.apiKey = process.env.ARC_API_KEY || '';
    this.sourceWalletId = process.env.ARC_WALLET_ID_SOURCE || '';
    this.targetWalletId = process.env.ARC_WALLET_ID_TARGET || '';
    this.entitySecretHex = process.env.ENTITY_SECRET_HEX || '';
    this.pubKeyPath = '/tmp/arc_pubkey.pem';

    if (!this.apiKey || !this.sourceWalletId || !this.targetWalletId) {
      throw new Error('Missing required environment variables');
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
      if (!this.entitySecretHex) {
        throw new Error('ENTITY_SECRET_HEX not set');
      }

      const secretBinPath = '/tmp/secret_transfer.bin';
      const secretEncPath = '/tmp/secret_transfer.enc';

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

  async transfer(
    tokenId: string,
    amount: string,
    destinationAddress: string
  ): Promise<TransferResult> {
    try {
      await this.fetchPublicKey();
      const entityCiphertext = this.encryptEntitySecret();

      const idempotencyKey = execSync('uuidgen', { encoding: 'utf-8' }).trim();

      const payload = {
        idempotencyKey,
        walletId: this.sourceWalletId,
        tokenId,
        destinationAddress,
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
      console.log(`✓ Transfer initiated: ${transactionId}`);

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
      };
    } catch (error) {
      return {
        success: false,
        error: String(error),
      };
    }
  }

  async getTargetAddress(): Promise<string> {
    try {
      const response = execSync(
        `curl -s -H "Authorization: Bearer ${this.apiKey}" "https://api.circle.com/v1/w3s/wallets/${this.targetWalletId}"`,
        { encoding: 'utf-8' }
      );
      const data = JSON.parse(response);
      return data.data.wallet.address;
    } catch (error) {
      throw new Error(`Failed to get target address: ${error}`);
    }
  }
}

async function main() {
  console.log('=== Arc Transfer Script ===\n');

  const service = new ArcTransferService();

  console.log('1. Fetching SOURCE wallet balance...');
  const sourceBalance = await service.getBalance(service['sourceWalletId']);
  console.log('SOURCE Balance:');
  sourceBalance.forEach((b) => {
    console.log(`  ${b.token.symbol}: ${b.amount}`);
  });

  console.log('\n2. Fetching TARGET wallet balance...');
  const targetBalance = await service.getBalance(service['targetWalletId']);
  console.log('TARGET Balance:');
  targetBalance.forEach((b) => {
    console.log(`  ${b.token.symbol}: ${b.amount}`);
  });

  const usdcToken = sourceBalance.find((b) => b.token.symbol === 'USDC-TESTNET');
  if (!usdcToken) {
    console.error('\n✗ No USDC-TESTNET found in SOURCE wallet');
    process.exit(1);
  }

  console.log('\n3. Getting TARGET wallet address...');
  const targetAddress = await service.getTargetAddress();
  console.log(`TARGET Address: ${targetAddress}`);

  console.log('\n4. Transferring 5 USDC-TESTNET to TARGET...');
  const result = await service.transfer(usdcToken.token.id, '5', targetAddress);

  if (!result.success) {
    console.error(`\n✗ Transfer failed: ${result.error}`);
    process.exit(1);
  }

  console.log(`✓ Transfer completed!`);
  console.log(`  Transaction ID: ${result.transactionId}`);
  console.log(`  Tx Hash: ${result.txHash}`);

  console.log('\n5. Verifying balances after transfer...');
  const sourceBalanceAfter = await service.getBalance(service['sourceWalletId']);
  const targetBalanceAfter = await service.getBalance(service['targetWalletId']);

  console.log('SOURCE Balance (after):');
  sourceBalanceAfter.forEach((b) => {
    console.log(`  ${b.token.symbol}: ${b.amount}`);
  });

  console.log('TARGET Balance (after):');
  targetBalanceAfter.forEach((b) => {
    console.log(`  ${b.token.symbol}: ${b.amount}`);
  });

  console.log('\n=== Transfer Complete ===');
}

main().catch((error) => {
  console.error('Error:', error.message);
  process.exit(1);
});
