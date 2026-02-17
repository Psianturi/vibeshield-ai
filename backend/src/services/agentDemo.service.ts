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
];

const ROUTER_ABI = [
  'function executeProtection(address user, uint256 amountIn) external',
  'function executor() external view returns (address)',
];

const ERC20_ABI = [
  'function balanceOf(address owner) external view returns (uint256)',
  'function allowance(address owner, address spender) external view returns (uint256)',
];

const ROUTER_ERROR_BY_SELECTOR: Record<string, string> = {
  '0x30cd7471': 'Router error: NotOwner',
  '0xc32d1d76': 'Router error: NotExecutor (backend wallet is not router executor)',
  '0x486fcee2': 'Router error: AgentNotActive',
  '0x05d7702d': 'Router error: NothingToSell (user WBNB balance is zero for selected strategy)',
  '0x90b8ec18': 'Router error: TransferFailed (check WBNB allowance/balance)',
  '0xbb55fd27': 'Router error: InsufficientLiquidity (router mUSDT liquidity too low)',
};

export class AgentDemoService {
  private provider?: ethers.JsonRpcProvider;
  private wallet?: ethers.Wallet;
  private rpcUrl: string;
  private privateKey: string;

  private deploymentCache?: AgentDemoDeployment;

  constructor() {
    // Allow a dedicated RPC/PK for the agent demo so it can target BSC Testnet
    // even if the rest of the backend is configured for a different chain.
    this.rpcUrl =
      process.env.AGENT_DEMO_RPC_URL ||
      process.env.BSC_TESTNET_RPC_URL ||
      'https://bsc-testnet-dataseed.bnbchain.org' ||
      process.env.EVM_RPC_URL ||
      process.env.BSC_RPC_URL ||
      '';
    this.privateKey = process.env.AGENT_DEMO_PRIVATE_KEY || process.env.PRIVATE_KEY || '';
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
    // Railway often deploys only the backend/ folder in monorepos.
    candidates.push(path.join(cwd, 'deployments', 'agent-demo-97.json'));
    candidates.push(path.join(cwd, 'backend', 'deployments', 'agent-demo-97.json'));
    candidates.push(path.join(cwd, 'contracts', 'deployments', 'agent-demo-97.json'));
    candidates.push(path.join(cwd, '..', 'contracts', 'deployments', 'agent-demo-97.json'));

    // Resolve from __dirname as additional fallback.
    candidates.push(path.resolve(__dirname, '..', '..', 'deployments', 'agent-demo-97.json'));
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
    selected: {
      registry: string;
      router: string;
      wbnb: string;
      musdt: string;
    };
    fallbackFromDeployment: {
      registry: string;
      router: string;
      wbnb: string;
      musdt: string;
    } | null;
    executorFromFile?: string;
  } {
    const dep = this.loadDeployment();

    const depRegistry = String(dep.VibeShieldRegistry || '').trim();
    const depRouter = String(dep.VibeShieldRouter || '').trim();
    const depWbnb = String(dep.wbnb || '').trim();
    const depMusdt = String(dep.MockUSDT || '').trim();

    const registry = String(process.env.AGENT_DEMO_REGISTRY_ADDRESS || depRegistry).trim();
    const router = String(process.env.AGENT_DEMO_ROUTER_ADDRESS || depRouter).trim();
    const wbnb = String(process.env.AGENT_DEMO_WBNB_ADDRESS || depWbnb).trim();
    const musdt = String(process.env.AGENT_DEMO_MUSDT_ADDRESS || depMusdt).trim();
    const chainId = dep.network?.chainId != null ? Number(dep.network.chainId) : null;

    if (!ethers.isAddress(registry)) throw new Error('Invalid or missing VibeShieldRegistry address');
    if (!ethers.isAddress(router)) throw new Error('Invalid or missing VibeShieldRouter address');
    if (!ethers.isAddress(wbnb)) throw new Error('Invalid or missing WBNB address');
    if (!ethers.isAddress(musdt)) throw new Error('Invalid or missing MockUSDT address');

    const deploymentSetValid =
      ethers.isAddress(depRegistry) &&
      ethers.isAddress(depRouter) &&
      ethers.isAddress(depWbnb) &&
      ethers.isAddress(depMusdt);

    const hasOverrides =
      Boolean(String(process.env.AGENT_DEMO_REGISTRY_ADDRESS || '').trim()) ||
      Boolean(String(process.env.AGENT_DEMO_ROUTER_ADDRESS || '').trim()) ||
      Boolean(String(process.env.AGENT_DEMO_WBNB_ADDRESS || '').trim()) ||
      Boolean(String(process.env.AGENT_DEMO_MUSDT_ADDRESS || '').trim());

    const fallbackFromDeployment = hasOverrides && deploymentSetValid
      ? {
          registry: depRegistry,
          router: depRouter,
          wbnb: depWbnb,
          musdt: depMusdt,
        }
      : null;

    return {
      chainId,
      selected: { registry, router, wbnb, musdt },
      fallbackFromDeployment,
      executorFromFile: dep.executor,
    };
  }

  private async assertRpcMatchesDeployment(
    provider: ethers.Provider,
    expectedChainId: number | null,
  ): Promise<void> {
    if (expectedChainId == null) return;
    const net = await provider.getNetwork();
    const actual = Number(net.chainId);
    if (actual !== expectedChainId) {
      throw new Error(
        `RPC network mismatch. Expected chainId ${expectedChainId} but RPC is chainId ${actual}. Set AGENT_DEMO_RPC_URL or BSC_TESTNET_RPC_URL to a BSC Testnet RPC (e.g. https://bsc-testnet-dataseed.bnbchain.org).`,
      );
    }
  }

  private async assertContractDeployed(
    provider: ethers.Provider,
    address: string,
    label: string,
  ): Promise<void> {
    const code = await provider.getCode(address);
    if (!code || code === '0x') {
      throw new Error(
        `${label} contract not found at ${address}. Likely wrong RPC network for this deployment.`,
      );
    }
  }

  private async selectUsableAddresses(
    provider: ethers.Provider,
    chainId: number | null,
    selected: { registry: string; router: string; wbnb: string; musdt: string },
    fallbackFromDeployment: {
      registry: string;
      router: string;
      wbnb: string;
      musdt: string;
    } | null,
  ): Promise<{
    selected: { registry: string; router: string; wbnb: string; musdt: string };
    warning: string | null;
  }> {
    await this.assertRpcMatchesDeployment(provider, chainId);

    const ensureContracts = async (set: { registry: string; router: string }) => {
      await this.assertContractDeployed(provider, set.registry, 'Registry');
      await this.assertContractDeployed(provider, set.router, 'Router');
    };

    try {
      await ensureContracts(selected);
      return { selected, warning: null };
    } catch (primaryErr: any) {
      if (!fallbackFromDeployment) throw primaryErr;

      await ensureContracts(fallbackFromDeployment);
      return {
        selected: fallbackFromDeployment,
        warning: `Primary AGENT_DEMO_* addresses failed validation. Using deployment file addresses instead. Cause: ${primaryErr?.message || primaryErr}`,
      };
    }
  }

  private async readCreationFeeWei(
    provider: ethers.Provider,
    registryAddress: string,
  ): Promise<string> {
    const probes: Array<{ abi: string[]; method: string }> = [
      {
        abi: ['function creationFee() external view returns (uint256)'],
        method: 'creationFee',
      },
      {
        abi: ['function fee() external view returns (uint256)'],
        method: 'fee',
      },
      {
        abi: ['function getCreationFee() external view returns (uint256)'],
        method: 'getCreationFee',
      },
    ];

    let lastErr: any = null;
    for (const probe of probes) {
      try {
        const reg = new ethers.Contract(registryAddress, probe.abi, provider);
        const raw = await (reg as any)[probe.method]();
        const asBigInt = typeof raw === 'bigint' ? raw : BigInt(String(raw));
        return asBigInt.toString();
      } catch (e) {
        lastErr = e;
      }
    }

    throw new Error(
      `Unable to read registry creation fee at ${registryAddress}. ${lastErr?.message || lastErr}`,
    );
  }

  private decodeRouterError(error: any): string | null {
    const candidates: string[] = [];

    if (error?.data && typeof error.data === 'string') {
      candidates.push(error.data);
    }
    if (error?.info?.error?.data && typeof error.info.error.data === 'string') {
      candidates.push(error.info.error.data);
    }

    const raw = String(error?.message || error || '');
    const match = raw.match(/data="(0x[0-9a-fA-F]+)"/);
    if (match?.[1]) candidates.push(match[1]);

    for (const hex of candidates) {
      const selector = hex.slice(0, 10).toLowerCase();
      if (ROUTER_ERROR_BY_SELECTOR[selector]) {
        return ROUTER_ERROR_BY_SELECTOR[selector];
      }
    }

    return null;
  }

  async getPublicConfig(): Promise<{
    chainId: number | null;
    registry: string;
    router: string;
    wbnb: string;
    musdt: string;
    creationFeeWei: string | null;
    routerExecutor: string | null;
    configError: string | null;
  }> {
    const resolved = this.resolveAddresses();
    let { selected } = resolved;
    let { registry, router, wbnb, musdt } = selected;
    const { chainId } = resolved;

    let creationFeeWei: string | null = null;
    let routerExecutor: string | null = null;
    let configError: string | null = null;

    // Use read-only provider 
    const rpcUrl = this.rpcUrl;
    if (!rpcUrl) {
      configError = 'Missing RPC URL (set AGENT_DEMO_RPC_URL, BSC_TESTNET_RPC_URL, or EVM_RPC_URL)';
      console.error('[AgentDemo] getPublicConfig:', configError);
    } else {
      try {
        const provider = new ethers.JsonRpcProvider(rpcUrl);
        const selectedResult = await this.selectUsableAddresses(
          provider,
          chainId,
          resolved.selected,
          resolved.fallbackFromDeployment,
        );
        selected = selectedResult.selected;
        registry = selected.registry;
        router = selected.router;
        wbnb = selected.wbnb;
        musdt = selected.musdt;

        creationFeeWei = await this.readCreationFeeWei(provider, registry);
        console.log('[AgentDemo] creationFee loaded:', creationFeeWei);

        const r = new ethers.Contract(router, ROUTER_ABI, provider);
        const ex: string = await r.executor();
        routerExecutor = ethers.isAddress(ex) ? ex : null;

        if (selectedResult.warning) {
          configError = selectedResult.warning;
        }
      } catch (e: any) {
        configError = e?.message || String(e);
        console.error('[AgentDemo] Failed to read contract data:', configError);
      }
    }

    return { chainId, registry, router, wbnb, musdt, creationFeeWei, routerExecutor, configError };
  }

  async executeProtection(userAddress: string, amountWbnb: string): Promise<SwapResult> {
    try {
      const resolved = this.resolveAddresses();
      const { chainId } = resolved;

      if (!ethers.isAddress(userAddress)) {
        return { success: false, error: 'Invalid userAddress' };
      }

      const parsed = Number(amountWbnb);
      if (!Number.isFinite(parsed) || parsed <= 0) {
        return { success: false, error: 'Invalid amount' };
      }

      const wallet = this.getWallet();
      const provider = wallet.provider!;

      const selectedResult = await this.selectUsableAddresses(
        provider,
        chainId,
        resolved.selected,
        resolved.fallbackFromDeployment,
      );
      const registry = selectedResult.selected.registry;
      const router = selectedResult.selected.router;
      const wbnb = selectedResult.selected.wbnb;

      // Make failures actionable: validate RPC matches the deployment and that
      // contract bytecode exists at the configured addresses.
      const reg = new ethers.Contract(registry, REGISTRY_ABI, wallet);
      const agent = await reg.getAgent(userAddress);
      const isActive = Boolean(agent?.[0]);
      const strategy = Number(agent?.[1] ?? 0);
      if (!isActive) {
        return { success: false, error: 'Agent not active for this user' };
      }

      const amountWei = ethers.parseUnits(String(amountWbnb), 18);

      const token = new ethers.Contract(wbnb, ERC20_ABI, provider);
      const userBalanceRaw = await token.balanceOf(userAddress);
      const userBalanceWei =
        typeof userBalanceRaw === 'bigint'
          ? userBalanceRaw
          : BigInt(String(userBalanceRaw));

      let maxSellWei = userBalanceWei;
      if (strategy === 2) {
        maxSellWei = userBalanceWei / 2n;
      }

      if (maxSellWei <= 0n) {
        return {
          success: false,
          error:
            'Nothing to sell. Your WBNB balance is 0 (or too low for current strategy). Top up WBNB testnet first.',
        };
      }

      const r = new ethers.Contract(router, ROUTER_ABI, wallet);
      const tx = await r.executeProtection(userAddress, amountWei);
      const receipt = await tx.wait();
      return { success: true, txHash: receipt.hash };
    } catch (error: any) {
      const decoded = this.decodeRouterError(error);
      return {
        success: false,
        error: decoded || error?.message || 'Execution failed',
      };
    }
  }

  async getUserStatus(userAddress: string): Promise<{
    chainId: number | null;
    userAddress: string;
    isAgentActive: boolean;
    strategy: number;
    allowanceWei: string;
    statusError: string | null;
  }> {
    const resolved = this.resolveAddresses();
    let { registry, router, wbnb } = resolved.selected;
    const { chainId } = resolved;

    if (!ethers.isAddress(userAddress)) {
      throw new Error('Invalid userAddress');
    }

    let isAgentActive = false;
    let strategy = 0;
    let allowanceWei = '0';
    let statusError: string | null = null;

    const rpcUrl = this.rpcUrl;
    if (!rpcUrl) {
      statusError =
        'Missing RPC URL (set AGENT_DEMO_RPC_URL, BSC_TESTNET_RPC_URL, or EVM_RPC_URL)';
      return {
        chainId,
        userAddress,
        isAgentActive,
        strategy,
        allowanceWei,
        statusError,
      };
    }

    try {
      const provider = new ethers.JsonRpcProvider(rpcUrl);
      const selectedResult = await this.selectUsableAddresses(
        provider,
        chainId,
        resolved.selected,
        resolved.fallbackFromDeployment,
      );
      registry = selectedResult.selected.registry;
      router = selectedResult.selected.router;
      wbnb = selectedResult.selected.wbnb;

      const reg = new ethers.Contract(registry, REGISTRY_ABI, provider);
      const agent = await reg.getAgent(userAddress);
      isAgentActive = Boolean(agent?.[0]);
      strategy = Number(agent?.[1] ?? 0);

      const token = new ethers.Contract(wbnb, ERC20_ABI, provider);
      const allowance = await token.allowance(userAddress, router);
      allowanceWei = (typeof allowance === 'bigint' ? allowance : BigInt(String(allowance))).toString();

      if (selectedResult.warning) {
        statusError = selectedResult.warning;
      }
    } catch (e: any) {
      statusError = e?.message || String(e);
    }

    return {
      chainId,
      userAddress,
      isAgentActive,
      strategy,
      allowanceWei,
      statusError,
    };
  }
}
