import fs from 'node:fs';
import path from 'node:path';
import { ethers } from 'ethers';
import { SwapResult } from '../types';

type AgentDemoDeployment = {
  network?: { name?: string; chainId?: number };
  deployer?: string;
  executor?: string;
  wbnb?: string;
  MockUSDT?: string;
  VibeShieldRegistry?: string;
  VibeShieldRouter?: string;
  seededMusdt?: string;
  timestamp?: string;
};

const REGISTRY_ABI = [
  'function getAgent(address user) external view returns (bool isActive, uint8 strategy)',
  'function creationFee() external view returns (uint256)',
];

const ROUTER_ABI = [
  'function executeProtection(address user, uint256 amountIn) external',
  'function executor() external view returns (address)',
];

export class AgentDemoService {
  private provider?: ethers.JsonRpcProvider;
  private wallet?: ethers.Wallet;
  private rpcUrl: string;
  private privateKey: string;

  private deploymentCache?: AgentDemoDeployment;

  constructor() {
    this.rpcUrl = process.env.EVM_RPC_URL || process.env.BSC_RPC_URL || '';
    this.privateKey = process.env.PRIVATE_KEY || '';
  }

  private getWallet(): ethers.Wallet {
    if (!this.rpcUrl) throw new Error('Missing EVM_RPC_URL (or BSC_RPC_URL)');
    if (!this.privateKey) throw new Error('Missing PRIVATE_KEY');

    if (!this.provider) this.provider = new ethers.JsonRpcProvider(this.rpcUrl);
    if (!this.wallet) this.wallet = new ethers.Wallet(this.privateKey, this.provider);
    return this.wallet;
  }

  private loadDeployment(): AgentDemoDeployment {
    if (this.deploymentCache) return this.deploymentCache;

    const envPath = String(process.env.AGENT_DEMO_DEPLOYMENT_PATH || '').trim();
    const candidates: string[] = [];
    if (envPath) candidates.push(envPath);

    // Common run locations: repo root, backend/, backend/dist
    const cwd = process.cwd();
    candidates.push(path.join(cwd, 'contracts', 'deployments', 'agent-demo-97.json'));
    candidates.push(path.join(cwd, '..', 'contracts', 'deployments', 'agent-demo-97.json'));

    // Resolve from __dirname as additional fallback.
    candidates.push(path.resolve(__dirname, '..', '..', '..', 'contracts', 'deployments', 'agent-demo-97.json'));
    candidates.push(path.resolve(__dirname, '..', '..', '..', '..', 'contracts', 'deployments', 'agent-demo-97.json'));

    let lastErr: any = null;
    for (const file of candidates) {
      try {
        if (!file) continue;
        if (!fs.existsSync(file)) continue;
        const raw = fs.readFileSync(file, 'utf8');
        const parsed = JSON.parse(raw);
        this.deploymentCache = parsed as AgentDemoDeployment;
        return this.deploymentCache;
      } catch (e) {
        lastErr = e;
      }
    }

    throw new Error(
      `Missing agent demo deployment file. Set AGENT_DEMO_DEPLOYMENT_PATH or ensure contracts/deployments/agent-demo-97.json is present. (${lastErr?.message || 'n/a'})`,
    );
  }

  private resolveAddresses(): {
    chainId: number | null;
    registry: string;
    router: string;
    wbnb: string;
    musdt: string;
    executorFromFile?: string;
  } {
    const dep = this.loadDeployment();

    const registry = String(process.env.AGENT_DEMO_REGISTRY_ADDRESS || dep.VibeShieldRegistry || '').trim();
    const router = String(process.env.AGENT_DEMO_ROUTER_ADDRESS || dep.VibeShieldRouter || '').trim();
    const wbnb = String(process.env.AGENT_DEMO_WBNB_ADDRESS || dep.wbnb || '').trim();
    const musdt = String(process.env.AGENT_DEMO_MUSDT_ADDRESS || dep.MockUSDT || '').trim();
    const chainId = dep.network?.chainId != null ? Number(dep.network.chainId) : null;

    if (!ethers.isAddress(registry)) throw new Error('Invalid or missing VibeShieldRegistry address');
    if (!ethers.isAddress(router)) throw new Error('Invalid or missing VibeShieldRouter address');
    if (!ethers.isAddress(wbnb)) throw new Error('Invalid or missing WBNB address');
    if (!ethers.isAddress(musdt)) throw new Error('Invalid or missing MockUSDT address');

    return { chainId, registry, router, wbnb, musdt, executorFromFile: dep.executor };
  }

  async getPublicConfig(): Promise<{
    chainId: number | null;
    registry: string;
    router: string;
    wbnb: string;
    musdt: string;
    creationFeeWei: string | null;
    routerExecutor: string | null;
  }> {
    const { chainId, registry, router, wbnb, musdt } = this.resolveAddresses();

    let creationFeeWei: string | null = null;
    let routerExecutor: string | null = null;

    try {
      const wallet = this.getWallet();
      const reg = new ethers.Contract(registry, REGISTRY_ABI, wallet);
      const fee: bigint = await reg.creationFee();
      creationFeeWei = fee.toString();

      const r = new ethers.Contract(router, ROUTER_ABI, wallet);
      const ex: string = await r.executor();
      routerExecutor = ethers.isAddress(ex) ? ex : null;
    } catch {
    }

    return { chainId, registry, router, wbnb, musdt, creationFeeWei, routerExecutor };
  }

  async executeProtection(userAddress: string, amountWbnb: string): Promise<SwapResult> {
    try {
      const { registry, router } = this.resolveAddresses();

      if (!ethers.isAddress(userAddress)) {
        return { success: false, error: 'Invalid userAddress' };
      }

      const parsed = Number(amountWbnb);
      if (!Number.isFinite(parsed) || parsed <= 0) {
        return { success: false, error: 'Invalid amount' };
      }

      const wallet = this.getWallet();

      const reg = new ethers.Contract(registry, REGISTRY_ABI, wallet);
      const agent = await reg.getAgent(userAddress);
      const isActive = Boolean(agent?.[0]);
      if (!isActive) {
        return { success: false, error: 'Agent not active for this user' };
      }

      const amountWei = ethers.parseUnits(String(amountWbnb), 18);
      const r = new ethers.Contract(router, ROUTER_ABI, wallet);
      const tx = await r.executeProtection(userAddress, amountWei);
      const receipt = await tx.wait();
      return { success: true, txHash: receipt.hash };
    } catch (error: any) {
      return { success: false, error: error?.message || 'Execution failed' };
    }
  }
}
