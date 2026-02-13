import { CryptoracleService } from '../services/cryptoracle.service';
import { CoinGeckoService } from '../services/coingecko.service';
import { KalibrService } from '../services/kalibr.service';
import { BlockchainService } from '../services/blockchain.service';
import { loadSubscriptions, saveSubscriptions, Subscription } from '../storage/subscriptions';

const cryptoracle = new CryptoracleService();
const coingecko = new CoinGeckoService();
const kalibr = new KalibrService();
const blockchain = new BlockchainService();

export async function runMonitorOnce() {
  const subs = loadSubscriptions().filter((s) => s.enabled);
  const results: any[] = [];

  for (const sub of subs) {
    try {
      const [sentiment, price] = await Promise.all([
        cryptoracle.getSentiment(sub.tokenSymbol),
        coingecko.getPrice(sub.tokenId)
      ]);

      const analysis = await kalibr.analyzeRisk(sentiment, price);

      let executed: any = null;
      if (analysis.shouldExit && analysis.riskScore >= sub.riskThreshold) {
        executed = await blockchain.emergencySwap(sub.userAddress, sub.tokenAddress, sub.amount);
        // Auto-disable after execution (hackathon safety)
        sub.enabled = false;
      }

      results.push({ sub, sentiment, price, analysis, executed });
    } catch (e: any) {
      results.push({ sub, error: e?.message ?? String(e) });
    }
  }

  // Persist any auto-disable changes
  saveSubscriptions(loadSubscriptions().map((s) => {
    const updated = results.find((r) => r.sub && r.sub.userAddress === s.userAddress && r.sub.tokenAddress === s.tokenAddress)?.sub as Subscription | undefined;
    return updated ?? s;
  }));

  return results;
}

export function startMonitorLoop() {
  const enabled = (process.env.ENABLE_MONITOR || '').toLowerCase() === 'true';
  if (!enabled) return null;

  const intervalMs = Number(process.env.MONITOR_INTERVAL_MS ?? 30000);
  const id = setInterval(() => {
    runMonitorOnce().catch((err) => console.error('Monitor run failed:', err));
  }, intervalMs);

  return id;
}
