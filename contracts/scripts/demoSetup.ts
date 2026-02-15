import { ethers } from 'hardhat';

async function main() {
  const vaultAddress = process.env.VAULT_ADDRESS;
  const tokenAddress = process.env.TOKEN_ADDRESS;

  if (!vaultAddress) throw new Error('Missing VAULT_ADDRESS in contracts/.env');
  if (!tokenAddress) throw new Error('Missing TOKEN_ADDRESS in contracts/.env');

  const slippageBps = Number(process.env.SLIPPAGE_BPS ?? 100); // 1%
  const maxAmountIn = process.env.MAX_AMOUNT_IN ?? '0';
  const approveAmount = process.env.APPROVE_AMOUNT ?? '1000';
  const mintAmount = process.env.MINT_AMOUNT ?? '1000';

  const [user] = await ethers.getSigners();
  if (!user) throw new Error('No signer available. Check DEPLOYER_PRIVATE_KEY and network RPC.');

  const vault = await ethers.getContractAt('VibeGuardVault', vaultAddress, user);
  const token = await ethers.getContractAt('ERC20Mintable', tokenAddress, user);

  const mintWei = ethers.parseUnits(mintAmount, 18);
  const approveWei = ethers.parseUnits(approveAmount, 18);
  const maxWei = ethers.parseUnits(maxAmountIn, 18);

  console.log('Demo setup:', {
    network: (await ethers.provider.getNetwork()).name,
    user: user.address,
    vaultAddress,
    tokenAddress,
    mintAmount,
    approveAmount,
    slippageBps,
    maxAmountIn,
  });

  console.log('Minting token to user...');
  const mintTx = await token.mint(user.address, mintWei);
  await mintTx.wait();

  console.log('Setting vault config (stable = token for demo)...');
  const cfgTx = await vault.setConfig(
    tokenAddress,
    tokenAddress,
    true,
    slippageBps,
    maxWei,
    false
  );
  await cfgTx.wait();

  console.log('Approving vault allowance...');
  const approveTx = await token.approve(vaultAddress, approveWei);
  await approveTx.wait();

  console.log('Done. User is ready for executeEmergencySwap().');
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
