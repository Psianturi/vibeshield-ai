import { ethers } from 'hardhat';
import fs from 'node:fs';
import path from 'node:path';

const WBNB_TESTNET = '0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd';

async function main() {
  const net = await ethers.provider.getNetwork();
  const [deployer] = await ethers.getSigners();
  if (!deployer) throw new Error('No deployer signer available. Check DEPLOYER_PRIVATE_KEY and network RPC.');

  const chainId = Number(net.chainId);
  const networkName = net.name;

  console.log('Network:', { name: networkName, chainId });
  console.log('Deployer:', deployer.address);

  const executor = process.env.EXECUTOR_ADDRESS || deployer.address;
  const wbnb = process.env.WBNB_TESTNET || process.env.WBNB || WBNB_TESTNET;

  const MockUSDT = await ethers.getContractFactory('MockUSDT', deployer);
  const musdt = await MockUSDT.deploy();
  await musdt.waitForDeployment();

  const Registry = await ethers.getContractFactory('VibeShieldRegistry', deployer);
  const registry = await Registry.deploy();
  await registry.waitForDeployment();

  const Router = await ethers.getContractFactory('VibeShieldRouter', deployer);
  const router = await Router.deploy(await registry.getAddress(), wbnb, await musdt.getAddress(), executor);
  await router.waitForDeployment();

  const musdtAddr = await musdt.getAddress();
  const registryAddr = await registry.getAddress();
  const routerAddr = await router.getAddress();

  console.log('Deployed:', {
    MockUSDT: musdtAddr,
    VibeShieldRegistry: registryAddr,
    VibeShieldRouter: routerAddr,
    executor,
    wbnb,
  });

  const liquidity = process.env.ROUTER_MUSDT_LIQUIDITY || '100000';
  const liquidityAmount = ethers.parseEther(liquidity);
  console.log('Seeding router mUSDT liquidity:', liquidity);
  const tx = await musdt.transfer(routerAddr, liquidityAmount);
  await tx.wait();
  console.log('Seeded. tx:', tx.hash);

  const out = {
    network: { name: networkName, chainId },
    deployer: deployer.address,
    executor,
    wbnb,
    MockUSDT: musdtAddr,
    VibeShieldRegistry: registryAddr,
    VibeShieldRouter: routerAddr,
    seededMusdt: liquidity,
    timestamp: new Date().toISOString(),
  };

  const deploymentsDir = path.join(process.cwd(), 'deployments');
  fs.mkdirSync(deploymentsDir, { recursive: true });
  const file = path.join(deploymentsDir, `agent-demo-${chainId}.json`);
  fs.writeFileSync(file, JSON.stringify(out, null, 2));
  console.log('Wrote:', file);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
