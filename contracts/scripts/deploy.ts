import { ethers } from 'hardhat';

async function main() {
  const networkName = (await ethers.provider.getNetwork()).name;

  const needsKey = networkName !== 'hardhat' && networkName !== 'localhost';
  if (needsKey && !process.env.DEPLOYER_PRIVATE_KEY) {
    throw new Error('Missing DEPLOYER_PRIVATE_KEY in contracts/.env');
  }

  const [deployer] = await ethers.getSigners();
  if (!deployer) {
    throw new Error('No deployer signer available. Check DEPLOYER_PRIVATE_KEY and network RPC.');
  }

  let router = process.env.DEX_ROUTER || process.env.PANCAKESWAP_ROUTER;
  let wrappedNative = process.env.WRAPPED_NATIVE || process.env.WBNB;

  // On local networks, deploy mocks so you can test deployment without external deps.
  if (networkName === 'hardhat' || networkName === 'localhost') {
    const RouterStub = await ethers.getContractFactory('RouterStub', deployer);
    const routerStub = await RouterStub.deploy();
    await routerStub.waitForDeployment();
    router = await routerStub.getAddress();

    const ERC20Mintable = await ethers.getContractFactory('ERC20Mintable', deployer);
    const wrapped = await ERC20Mintable.deploy('Wrapped Native (Stub)', 'WNATIVE', 18);
    await wrapped.waitForDeployment();
    wrappedNative = await wrapped.getAddress();

    console.log('Local mocks deployed:', { router, wrappedNative });
  }

  if (!router || !wrappedNative) {
    throw new Error('Missing router/wrapped native. Set DEX_ROUTER+WRAPPED_NATIVE (or PANCAKESWAP_ROUTER+WBNB).');
  }

  const Vault = await ethers.getContractFactory('VibeGuardVault', deployer);
  const vault = await Vault.deploy(router, wrappedNative);
  await vault.waitForDeployment();

  const address = await vault.getAddress();
  console.log('VibeGuardVault deployed to:', address);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
