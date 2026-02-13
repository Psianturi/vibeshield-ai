import { ethers } from 'ethers';
import { SwapResult } from '../types';

const VIBEGUARD_VAULT_ABI = [
  'function executeEmergencySwap(address user, address token, uint256 amountIn) external',
  'function guardians(address guardian) external view returns (bool)'
];

export class BlockchainService {
  private provider: ethers.JsonRpcProvider;
  private wallet: ethers.Wallet;
  private vaultAddress: string;

  constructor() {
    this.provider = new ethers.JsonRpcProvider(process.env.BSC_RPC_URL);
    this.wallet = new ethers.Wallet(process.env.PRIVATE_KEY || '', this.provider);
    this.vaultAddress = process.env.VIBEGUARD_VAULT_ADDRESS || '';
  }

  async emergencySwap(userAddress: string, tokenAddress: string, amount: string): Promise<SwapResult> {
    try {
      if (!this.vaultAddress) {
        return { success: false, error: 'Missing VIBEGUARD_VAULT_ADDRESS' };
      }

      const vault = new ethers.Contract(this.vaultAddress, VIBEGUARD_VAULT_ABI, this.wallet);
      const isGuardian: boolean = await vault.guardians(this.wallet.address);
      if (!isGuardian) {
        return { success: false, error: 'Backend wallet is not a vault guardian' };
      }

      const amountIn = ethers.parseUnits(amount, 18);
      const tx = await vault.executeEmergencySwap(userAddress, tokenAddress, amountIn);
      const receipt = await tx.wait();
      return { success: true, txHash: receipt.hash };
    } catch (error: any) {
      console.error('Swap error:', error);
      return { success: false, error: error.message };
    }
  }
}
