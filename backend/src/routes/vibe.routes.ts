import { Router } from 'express';
import { CryptoracleService } from '../services/cryptoracle.service';
import { CoinGeckoService } from '../services/coingecko.service';
import { KalibrService } from '../services/kalibr.service';
import { BlockchainService } from '../services/blockchain.service';
import { loadSubscriptions, upsertSubscription } from '../storage/subscriptions';
import { runMonitorOnce } from '../monitor/vibeMonitor';

const router = Router();
const cryptoracle = new CryptoracleService();
const coingecko = new CoinGeckoService();
const kalibr = new KalibrService();
const blockchain = new BlockchainService();

router.post('/check', async (req, res) => {
  try {
    const { token, tokenId } = req.body;

    const [sentiment, price] = await Promise.all([
      cryptoracle.getSentiment(token),
      coingecko.getPrice(tokenId)
    ]);

    const analysis = await kalibr.analyzeRisk(sentiment, price);

    res.json({ sentiment, price, analysis });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/execute-swap', async (req, res) => {
  try {
    const { userAddress, tokenAddress, amount } = req.body;
    const result = await blockchain.emergencySwap(userAddress, tokenAddress, amount);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/subscriptions', (req, res) => {
  res.json(loadSubscriptions());
});

router.post('/subscribe', (req, res) => {
  const {
    userAddress,
    tokenSymbol,
    tokenId,
    tokenAddress,
    amount,
    enabled = true,
    riskThreshold = 80
  } = req.body;

  if (!userAddress || !tokenSymbol || !tokenId || !tokenAddress || !amount) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const sub = upsertSubscription({
    userAddress,
    tokenSymbol,
    tokenId,
    tokenAddress,
    amount,
    enabled: Boolean(enabled),
    riskThreshold: Number(riskThreshold)
  });

  res.json({ ok: true, subscription: sub });
});

router.post('/run-once', async (req, res) => {
  try {
    const result = await runMonitorOnce();
    res.json({ ok: true, result });
  } catch (error: any) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

export default router;
