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

let _cycleInFlight = false;

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
  if (_cycleInFlight) {
    console.log('[MONITOR] previous cycle still running; skipping');
    return [];
  }

  _cycleInFlight = true;

  try {
    const subs = loadSubscriptions().filter((s) => s.enabled);
    const results: any[] = [];
    const autoDisableOnExecute =
      String(process.env.MONITOR_AUTO_DISABLE_ON_EXECUTE || 'false').toLowerCase() === 'true';

    const cooldownMsRaw = Number(process.env.MONITOR_EXECUTION_COOLDOWN_MS ?? 300000);
    const cooldownMs = Number.isFinite(cooldownMsRaw) ? Math.max(0, cooldownMsRaw) : 300000;

    console.log(`[MONITOR] cycle started enabledSubs=${subs.length}`);
    if (!subs.length) {
      console.log('[MONITOR] no enabled subscriptions; skipping cycle');
    }

    for (const sub of subs) {
      try {
        if (cooldownMs > 0 && typeof sub.lastExecutedAt === 'number' && sub.lastExecutedAt > 0) {
          const elapsed = Date.now() - sub.lastExecutedAt;
          if (elapsed >= 0 && elapsed < cooldownMs) {
            const remainingMs = cooldownMs - elapsed;
            console.log(
              `[MONITOR] cooldown active user=${sub.userAddress} token=${sub.tokenSymbol} remainingMs=${remainingMs}`,
            );
            results.push({ sub, skipped: 'cooldown', cooldownRemainingMs: remainingMs });
            continue;
          }
        }

        console.log(
          `[MONITOR] processing user=${sub.userAddress} token=${sub.tokenSymbol} threshold=${sub.riskThreshold}`,
        );
        const [sentiment, price] = await Promise.all([
          getCryptoracle().getSentiment(sub.tokenSymbol),
          getCoingecko().getPrice(sub.tokenId),
        ]);

        const symbol = String(sub.tokenSymbol || '').trim().toUpperCase();
        const alias = symbol.startsWith('W') && symbol.length > 1 ? symbol.substring(1) : symbol;

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
          console.log(
            `[MONITOR] execute condition met user=${sub.userAddress} score=${analysis.riskScore} threshold=${sub.riskThreshold}`,
          );
          executed = await getAgentDemo().executeProtection(sub.userAddress, sub.amount);
          if (executed?.success && executed?.txHash) {
            sub.lastExecutedAt = Date.now();

            let routerAddress: string | undefined;
            let executorAddress: string | undefined;
            try {
              const cfg = await getAgentDemo().getPublicConfig();
              if (cfg?.router && typeof cfg.router === 'string') routerAddress = cfg.router;
              if (cfg?.routerExecutor && typeof cfg.routerExecutor === 'string') {
                executorAddress = cfg.routerExecutor;
              }
            } catch {
            }

            appendTxHistory({
              userAddress: sub.userAddress,
              tokenAddress: sub.tokenAddress,
              txHash: executed.txHash,
              timestamp: Date.now(),
              source: 'monitor',
              routerAddress,
              executorAddress,
            });
            if (injectedContext) {
              // Demo injected context is intentionally one-shot.
              // Use token-agnostic consume to avoid symbol alias mismatch (BNB vs WBNB).
              demoContextManager.markConsumed();
            }
            if (autoDisableOnExecute) {
              sub.enabled = false;
            }
            console.log(`[MONITOR] execution success txHash=${executed.txHash}`);
          } else {
            console.log(
              `[MONITOR] execution failed user=${sub.userAddress} error=${executed?.error || 'unknown error'}`,
            );
          }
        } else {
          console.log(
            `[MONITOR] no execute user=${sub.userAddress} shouldExit=${analysis.shouldExit} score=${analysis.riskScore} threshold=${sub.riskThreshold}`,
          );
        }

        results.push({ sub, sentiment, price, analysis, executed });
      } catch (e: any) {
        console.error(`[MONITOR] processing error user=${sub.userAddress}:`, e?.message ?? String(e));
        results.push({ sub, error: e?.message ?? String(e) });
      }
    }

    // Persist any auto-disable / cooldown timestamp changes
    saveSubscriptions(
      loadSubscriptions().map((s) => {
        const updated = results.find(
          (r) =>
            r.sub &&
            String(r.sub.userAddress || '').toLowerCase() === String(s.userAddress || '').toLowerCase() &&
            String(r.sub.tokenAddress || '').toLowerCase() === String(s.tokenAddress || '').toLowerCase(),
        )?.sub as Subscription | undefined;
        return updated ?? s;
      }),
    );

    return results;
  } finally {
    _cycleInFlight = false;
  }
}

export function startMonitorLoop() {
  const enabled = (process.env.ENABLE_MONITOR || '').toLowerCase() === 'true';
  if (!enabled) {
    console.log('[MONITOR] disabled by ENABLE_MONITOR flag');
    return null;
  }

  const intervalMs = Number(process.env.MONITOR_INTERVAL_MS ?? 30000);
  console.log(`[MONITOR] starting loop intervalMs=${intervalMs}`);

  runMonitorOnce().catch((err) => console.error('Monitor bootstrap run failed:', err));

  const id = setInterval(() => {
    runMonitorOnce().catch((err) => console.error('Monitor run failed:', err));
  }, intervalMs);

  return id;
}
