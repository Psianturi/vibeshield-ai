import { CryptoracleService } from '../services/cryptoracle.service';
import { CoinGeckoService } from '../services/coingecko.service';
import { KalibrService } from '../services/kalibr.service';
import { BlockchainService } from '../services/blockchain.service';
import { loadSubscriptions, saveSubscriptions, Subscription } from '../storage/subscriptions';
import { appendTxHistory } from '../storage/txHistory';

let _cryptoracle: CryptoracleService | null = null;
let _coingecko: CoinGeckoService | null = null;
let _kalibr: KalibrService | null = null;
let _blockchain: BlockchainService | null = null;

function getCryptoracle(): CryptoracleService {
  if (!_cryptoracle) _cryptoracle = new CryptoracleService();
  return _cryptoracle;
}

function getCoingecko(): CoinGeckoService {
  if (!_coingecko) _coingecko = new CoinGeckoService();
  return _coingecko;
}

function getKalibr(): KalibrService {
  if (!_kalibr) _kalibr = new KalibrService();
  return _kalibr;
}

function getBlockchain(): BlockchainService {
  if (!_blockchain) _blockchain = new BlockchainService();
  return _blockchain;
}

export async function runMonitorOnce() {
  const subs = loadSubscriptions().filter((s) => s.enabled);
  const results: any[] = [];

  for (const sub of subs) {
    try {
      const [sentiment, price] = await Promise.all([
        getCryptoracle().getSentiment(sub.tokenSymbol),
        getCoingecko().getPrice(sub.tokenId)
      ]);

      const analysis = await getKalibr().analyzeRisk(sentiment, price);

      let executed: any = null;
      if (analysis.shouldExit && analysis.riskScore >= sub.riskThreshold) {
        executed = await getBlockchain().emergencySwap(sub.userAddress, sub.tokenAddress, sub.amount);
        if (executed?.success && executed?.txHash) {
          appendTxHistory({
            userAddress: sub.userAddress,
            tokenAddress: sub.tokenAddress,
            txHash: executed.txHash,
            timestamp: Date.now(),
            source: 'monitor'
          });
        }
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
