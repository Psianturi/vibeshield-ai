import { Router } from 'express';
import { CryptoracleService } from '../services/cryptoracle.service';
import { CoinGeckoService } from '../services/coingecko.service';
import { KalibrService } from '../services/kalibr.service';
import { BlockchainService } from '../services/blockchain.service';
import { loadSubscriptions, upsertSubscription } from '../storage/subscriptions';
import { appendTxHistory, loadTxHistory } from '../storage/txHistory';
import { runMonitorOnce } from '../monitor/vibeMonitor';

const router = Router();
const cryptoracle = new CryptoracleService();
const coingecko = new CoinGeckoService();
const kalibr = new KalibrService();
const blockchain = new BlockchainService();

router.get('/debug/models', async (req, res) => {
  const debugEnabled = String(process.env.DEBUG || '').toLowerCase() === 'true';
  if (!debugEnabled) {
    return res.status(404).json({ error: 'Not found' });
  }

  try {
    const models = await kalibr.listGeminiGenerateContentModels();
    res.json({ ok: true, count: models.length, models });
  } catch (error: any) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

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
    const status = error?.response?.status;
    const msg = String(error?.message || 'Request failed');

    if (status === 429 || msg.includes('status 429')) {
      return res.status(429).json({ error: 'Rate limited by upstream provider. Please retry in a moment.' });
    }

    if (msg.toLowerCase().includes('Missing data for tokenid')) {
      return res.status(400).json({ error: 'Invalid Token or Coin ID. Please pick a valid coin id (e.g. bitcoin, ethereum).' });
    }

    res.status(500).json({ error: msg });
  }
});

router.get('/prices', async (req, res) => {
  try {
    const idsRaw = String(req.query.ids || '').trim();
    const tokenIds = idsRaw
      ? idsRaw.split(',').map((s) => s.trim()).filter(Boolean)
      : ['bitcoin', 'binancecoin', 'ethereum', 'tether'];

    const items = await coingecko.getPrices(tokenIds);
    res.json({ ok: true, items, updatedAt: Date.now() });
  } catch (error: any) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

router.post('/execute-swap', async (req, res) => {
  try {
    const { userAddress, tokenAddress, amount } = req.body;
    const result = await blockchain.emergencySwap(userAddress, tokenAddress, amount);

    if (result?.success && result?.txHash && userAddress && tokenAddress) {
      appendTxHistory({
        userAddress,
        tokenAddress,
        txHash: result.txHash,
        timestamp: Date.now(),
        source: 'manual'
      });
    }

    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/tx-history', (req, res) => {
  const userAddress = String(req.query.userAddress || '').trim();
  if (!userAddress) {
    return res.status(400).json({ ok: false, error: 'Missing userAddress query param' });
  }

  const limit = req.query.limit ? Number(req.query.limit) : undefined;
  const items = loadTxHistory({ userAddress, limit });
  return res.json({ ok: true, items });
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
