import { CryptoracleService } from '../services/cryptoracle.service';
import { CoinGeckoService } from '../services/coingecko.service';
import { KalibrService } from '../services/kalibr.service';
import { AgentDemoService } from '../services/agentDemo.service';
import { demoContextManager } from '../services/demoContext.service';
import { loadSubscriptions, saveSubscriptions, Subscription } from '../storage/subscriptions';
import { appendTxHistory } from '../storage/txHistory';

let _cryptoracle: CryptoracleService | null = null;
let _coingecko: CoinGeckoService | null = null;
let _kalibr: KalibrService | null = null;
let _agentDemo: AgentDemoService | null = null;

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

function getAgentDemo(): AgentDemoService {
  if (!_agentDemo) _agentDemo = new AgentDemoService();
  return _agentDemo;
}

export async function runMonitorOnce() {
  const subs = loadSubscriptions().filter((s) => s.enabled);
  const results: any[] = [];
  const autoDisableOnExecute =
    String(process.env.MONITOR_AUTO_DISABLE_ON_EXECUTE || 'false').toLowerCase() === 'true';

  for (const sub of subs) {
    try {
      const [sentiment, price] = await Promise.all([
        getCryptoracle().getSentiment(sub.tokenSymbol),
        getCoingecko().getPrice(sub.tokenId)
      ]);

      const symbol = String(sub.tokenSymbol || '').trim().toUpperCase();
      const alias = symbol.startsWith('W') && symbol.length > 1
        ? symbol.substring(1)
        : symbol;

      const injectedContext =
        demoContextManager.getActiveContext(symbol) ||
        (alias !== symbol ? demoContextManager.getActiveContext(alias) : null);

      const analysis = await getKalibr().analyzeRisk(sentiment, price, {
        injectedContext: injectedContext
          ? {
              headline: injectedContext.headline,
              severity: injectedContext.severity,
            }
          : undefined,
      });

      let executed: any = null;
      if (analysis.shouldExit && analysis.riskScore >= sub.riskThreshold) {
        executed = await getAgentDemo().executeProtection(sub.userAddress, sub.amount);
        if (executed?.success && executed?.txHash) {
          appendTxHistory({
            userAddress: sub.userAddress,
            tokenAddress: sub.tokenAddress,
            txHash: executed.txHash,
            timestamp: Date.now(),
            source: 'monitor'
          });
          if (injectedContext) {
            demoContextManager.markConsumed(sub.tokenSymbol);
          }
          if (autoDisableOnExecute) {
            sub.enabled = false;
          }
        }
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
