import { ethers } from 'ethers';
import { SwapResult } from '../types';

const VIBEGUARD_VAULT_ABI = [
  'function executeEmergencySwap(address user, address token, uint256 amountIn) external',
  'function guardians(address guardian) external view returns (bool)'
];

const ERC20_ABI = [
  'function decimals() view returns (uint8)'
];

export class BlockchainService {
  private provider?: ethers.JsonRpcProvider;
  private wallet?: ethers.Wallet;
  private vaultAddress: string;
  private rpcUrl: string;
  private privateKey: string;

  constructor() {
    this.rpcUrl = process.env.EVM_RPC_URL || process.env.BSC_RPC_URL || '';
    this.privateKey = process.env.PRIVATE_KEY || '';
    this.vaultAddress = process.env.VIBESHIELD_VAULT_ADDRESS || process.env.VIBEGUARD_VAULT_ADDRESS || '';
  }

  private getWallet(): ethers.Wallet {
    if (!this.rpcUrl) throw new Error('Missing EVM_RPC_URL (or BSC_RPC_URL)');
    if (!this.privateKey) throw new Error('Missing PRIVATE_KEY');

    if (!this.provider) this.provider = new ethers.JsonRpcProvider(this.rpcUrl);
    if (!this.wallet) this.wallet = new ethers.Wallet(this.privateKey, this.provider);
    return this.wallet;
  }

  async emergencySwap(userAddress: string, tokenAddress: string, amount: string): Promise<SwapResult> {
    try {
      if (!this.vaultAddress) {
        return { success: false, error: 'Missing VIBEGUARD_VAULT_ADDRESS' };
      }

      const wallet = this.getWallet();

      if (!ethers.isAddress(tokenAddress)) {
        return { success: false, error: 'Invalid tokenAddress' };
      }

      const vault = new ethers.Contract(this.vaultAddress, VIBEGUARD_VAULT_ABI, wallet);
      const isGuardian: boolean = await vault.guardians(wallet.address);
      if (!isGuardian) {
        return { success: false, error: 'Backend wallet is not a vault guardian' };
      }

      // Determine token decimals dynamically.
      let decimals = 18;
      try {
        const erc20 = new ethers.Contract(tokenAddress, ERC20_ABI, wallet);
        const d = await erc20.decimals();
        const n = Number(d);
        if (Number.isFinite(n) && n >= 0 && n <= 36) decimals = n;
      } catch {
      }

      const amountIn = ethers.parseUnits(amount, decimals);
      const tx = await vault.executeEmergencySwap(userAddress, tokenAddress, amountIn);
      const receipt = await tx.wait();
      return { success: true, txHash: receipt.hash };
    } catch (error: any) {
      console.error('Swap error:', error);
      return { success: false, error: error.message };
    }
  }
}
