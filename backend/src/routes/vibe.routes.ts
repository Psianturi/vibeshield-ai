import { Router } from 'express';
import { CryptoracleService } from '../services/cryptoracle.service';
import { CoinGeckoService } from '../services/coingecko.service';
import { KalibrService } from '../services/kalibr.service';
import { BlockchainService } from '../services/blockchain.service';
import { AgentDemoService } from '../services/agentDemo.service';
import { demoContextManager } from '../services/demoContext.service';
import { loadSubscriptions, upsertSubscription } from '../storage/subscriptions';
import { appendTxHistory, loadTxHistory } from '../storage/txHistory';
import { runMonitorOnce } from '../monitor/vibeMonitor';
import { ethers } from 'ethers';
import rateLimit from 'express-rate-limit';
import crypto from 'crypto';
import { requireApiAuth } from '../middleware/apiAuth';

const router = Router();

const cryptoracleLimiter = rateLimit({
  windowMs: Number(process.env.CRYPTORACLE_RATE_LIMIT_WINDOW_MS ?? 60_000),
  limit: Number(process.env.CRYPTORACLE_RATE_LIMIT_PER_WINDOW ?? 30),
  standardHeaders: 'draft-7',
  legacyHeaders: false,
});

const demoInjectLimiter = rateLimit({
  windowMs: Number(process.env.DEMO_INJECT_RATE_LIMIT_WINDOW_MS ?? 60_000),
  limit: Number(process.env.DEMO_INJECT_RATE_LIMIT_PER_WINDOW ?? 5),
  standardHeaders: 'draft-7',
  legacyHeaders: false,
});

function normalizeWindow(raw: any): 'Daily' | '4H' | '1H' | '15M' {
  const w = String(raw ?? 'Daily').trim();
  if (w === '15M' || w === '1H' || w === '4H' || w === 'Daily') return w;
  return 'Daily';
}

function normalizeSymbol(raw: any): string {
  const s = String(raw ?? '').trim().toUpperCase();
  // Basic sanity check to avoid abusive payloads
  if (!/^[A-Z0-9]{2,15}$/.test(s)) return '';
  return s;
}

function secureEquals(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function normalizeSymbolList(raw: any): string[] {
  const list = Array.isArray(raw) ? raw : [];
  const out: string[] = [];
  for (const item of list) {
    const s = normalizeSymbol(item);
    if (s && !out.includes(s)) out.push(s);
    if (out.length >= Number(process.env.MULTI_MAX_TOKENS ?? 20)) break;
  }
  return out;
}

// Lazy initialization to ensure dotenv has loaded
let _cryptoracle: CryptoracleService | null = null;
let _coingecko: CoinGeckoService | null = null;
let _kalibr: KalibrService | null = null;
let _blockchain: BlockchainService | null = null;
let _agentDemo: AgentDemoService | null = null;

function getCryptoracle(): CryptoracleService {
  if (!_cryptoracle) {
    _cryptoracle = new CryptoracleService();
  }
  return _cryptoracle;
}

function getCoingecko(): CoinGeckoService {
  if (!_coingecko) {
    _coingecko = new CoinGeckoService();
  }
  return _coingecko;
}

function getKalibr(): KalibrService {
  if (!_kalibr) {
    _kalibr = new KalibrService();
  }
  return _kalibr;
}

function getBlockchain(): BlockchainService {
  if (!_blockchain) {
    _blockchain = new BlockchainService();
  }
  return _blockchain;
}

function getAgentDemo(): AgentDemoService {
  if (!_agentDemo) {
    _agentDemo = new AgentDemoService();
  }
  return _agentDemo;
}

router.get('/debug/models', async (req, res) => {
  const debugEnabled = String(process.env.DEBUG || '').toLowerCase() === 'true';
  if (!debugEnabled) {
    return res.status(404).json({ error: 'Not found' });
  }

  try {
    const models = await getKalibr().listGeminiGenerateContentModels();
    res.json({ ok: true, count: models.length, models });
  } catch (error: any) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

router.get('/public-config', (req, res) => {

  return res.json({
    ok: true,
    walletConnectProjectId: String(process.env.WALLETCONNECT_PROJECT_ID || '').trim()
  });
});

router.post('/demo/inject', demoInjectLimiter, (req, res) => {
  const demoEnabled = String(process.env.ENABLE_DEMO_INJECTION || '').toLowerCase() === 'true';
  if (!demoEnabled) {
    return res.status(404).json({ ok: false, error: 'Demo injection is disabled' });
  }

  const requireSecret = String(process.env.DEMO_INJECTION_REQUIRE_SECRET || 'false').toLowerCase() === 'true';
  if (requireSecret) {
    const configuredSecret = String(process.env.DEMO_INJECTION_SECRET || '').trim();
    if (!configuredSecret) {
      return res.status(500).json({ ok: false, error: 'Server missing DEMO_INJECTION_SECRET' });
    }

    const inputSecret = String(req.body?.secret || '').trim();
    if (!inputSecret || !secureEquals(inputSecret, configuredSecret)) {
      return res.status(401).json({ ok: false, error: 'Unauthorized' });
    }
  }

  const token = normalizeSymbol(req.body?.token || 'BNB');
  const type = String(req.body?.type || '').trim().toUpperCase();
  const mappedHeadlineByType: Record<string, string> = {
    BRIDGE_HACK: 'Major security breach detected on BNB bridge; cascading liquidity risk expected.',
    ORACLE_FAILURE: 'Critical oracle outage detected; pricing integrity at risk for major pools.',
    LIQUIDITY_CRUNCH: 'Severe liquidity crunch detected; slippage and market impact risk elevated.',
  };
  const headline = String(req.body?.headline || mappedHeadlineByType[type] || '').trim();
  if (!token || !headline) {
    return res.status(400).json({ ok: false, error: 'token and headline (or supported type) are required' });
  }

  const severityRaw = String(req.body?.severity || 'CRITICAL').trim().toUpperCase();
  const severity = severityRaw === 'HIGH' ? 'HIGH' : 'CRITICAL';
  const ttlMsRaw = Number(req.body?.ttlMs);
  const ttlMs = Number.isFinite(ttlMsRaw)
    ? Math.max(15_000, Math.min(ttlMsRaw, 10 * 60 * 1000))
    : Number(process.env.DEMO_INJECTION_TTL_MS ?? 3 * 60 * 1000);

  const context = demoContextManager.inject({
    token,
    headline,
    severity,
    ttlMs,
  });

  return res.json({
    ok: true,
    injected: {
      type: type || null,
      token: context.token,
      headline: context.headline,
      severity: context.severity,
      timestamp: context.timestamp,
      expiresAt: context.expiresAt,
      consumed: context.consumed,
      ttlMs,
    },
  });
});

router.get('/demo/context', (req, res) => {
  const demoEnabled = String(process.env.ENABLE_DEMO_INJECTION || '').toLowerCase() === 'true';
  if (!demoEnabled) {
    return res.status(404).json({ ok: false, error: 'Demo injection is disabled' });
  }

  const context = demoContextManager.getSnapshot();
  return res.json({ ok: true, context });
});

router.get('/agent-demo/config', async (req, res) => {
  try {
    const config = await getAgentDemo().getPublicConfig();
    return res.json({ ok: true, config });
  } catch (error: any) {
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.get('/agent-demo/status', async (req, res) => {
  try {
    const userAddress = String(req.query.userAddress || '').trim();
    if (!userAddress) {
      return res.status(400).json({ ok: false, error: 'Missing userAddress query param' });
    }

    const status = await getAgentDemo().getUserStatus(userAddress);
    return res.json({ ok: true, status });
  } catch (error: any) {
    return res.status(500).json({ ok: false, error: error.message });
  }
});

router.post('/agent-demo/execute-protection', async (req, res) => {
  try {
    const { userAddress, amountWbnb } = req.body;
    const result = await getAgentDemo().executeProtection(
      String(userAddress || '').trim(),
      String(amountWbnb || '').trim(),
    );

    if (result?.success && result?.txHash && userAddress) {
      appendTxHistory({
        userAddress: String(userAddress).trim(),
        tokenAddress: 'WBNB',
        txHash: result.txHash,
        timestamp: Date.now(),
        source: 'agent'
      });
    }

    return res.json(result);
  } catch (error: any) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

router.post('/agent-demo/topup-wbnb', async (req, res) => {
  try {
    const userAddress = String(req.body?.userAddress || '').trim();
    const result = await getAgentDemo().topUpWbnbForDemo(userAddress);
    return res.json(result);
  } catch (error: any) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

router.post('/agent-demo/log-wallet-tx', (req, res) => {
  try {
    const userAddress = String(req.body?.userAddress || '').trim();
    const txHash = String(req.body?.txHash || '').trim();
    const tokenAddress = String(req.body?.tokenAddress || 'WBNB').trim();
    const kind = String(req.body?.kind || '').trim().toLowerCase();

    if (!ethers.isAddress(userAddress)) {
      return res.status(400).json({ ok: false, error: 'Invalid userAddress' });
    }
    if (!/^0x([A-Fa-f0-9]{64})$/.test(txHash)) {
      return res.status(400).json({ ok: false, error: 'Invalid txHash' });
    }

    const normalizedKind = kind === 'spawn' || kind === 'approve' ? kind : 'wallet';

    appendTxHistory({
      userAddress,
      tokenAddress: `${tokenAddress}:${normalizedKind}`,
      txHash,
      timestamp: Date.now(),
      source: 'agent',
    });

    return res.json({ ok: true });
  } catch (error: any) {
    return res.status(500).json({ ok: false, error: error?.message || String(error) });
  }
});

router.get('/token-presets', (req, res) => {
  const raw = String(process.env.TOKEN_PRESETS_JSON || '').trim();
  if (!raw) {
    return res.json({ ok: true, items: [] });
  }

  try {
    const parsed = JSON.parse(raw);
    const items = Array.isArray(parsed) ? parsed : (Array.isArray(parsed?.items) ? parsed.items : []);

    const chainIdQuery = String(req.query.chainId || '').trim();
    const chainId = chainIdQuery ? Number(chainIdQuery) : null;

    const normalized = items
      .map((it: any) => {
        const address = String(it?.address || it?.tokenAddress || '').trim();
        const chainIdVal = Number(it?.chainId);
        const symbol = String(it?.symbol || '').trim().toUpperCase();
        const name = String(it?.name || symbol).trim();
        const decimals = it?.decimals != null ? Number(it.decimals) : null;
        const coinGeckoId = String(it?.coinGeckoId || it?.coingeckoId || '').trim().toLowerCase();

        return {
          chainId: Number.isFinite(chainIdVal) ? chainIdVal : null,
          symbol,
          name,
          address: ethers.isAddress(address) ? address : '',
          decimals: Number.isFinite(decimals as any) ? decimals : null,
          coinGeckoId: coinGeckoId || null
        };
      })
      .filter((it: any) => it.symbol && it.address && it.chainId != null);

    const filtered = chainId != null
      ? normalized.filter((it: any) => it.chainId === chainId)
      : normalized;

    return res.json({ ok: true, items: filtered });
  } catch (e: any) {
    return res.status(400).json({ ok: false, error: 'Invalid TOKEN_PRESETS_JSON' });
  }
});

router.post('/check', cryptoracleLimiter, async (req, res) => {
  try {
    const { token, tokenId } = req.body;
    const symbol = normalizeSymbol(token);
    if (!symbol) {
      return res.status(400).json({ error: 'Invalid token symbol' });
    }

    const [sentiment, price] = await Promise.all([
      getCryptoracle().getSentiment(symbol),
      getCoingecko().getPrice(tokenId)
    ]);

    const analysis = await getKalibr().analyzeRisk(sentiment, price);

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

    const items = await getCoingecko().getPrices(tokenIds);
    res.json({ ok: true, items, updatedAt: Date.now() });
  } catch (error: any) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

router.post('/execute-swap', requireApiAuth, async (req, res) => {
  try {
    const { userAddress, tokenAddress, amount } = req.body;
    const result = await getBlockchain().emergencySwap(userAddress, tokenAddress, amount);

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

router.post('/subscribe', requireApiAuth, (req, res) => {
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


// Get detailed sentiment insights for a single token
router.post('/insights', cryptoracleLimiter, async (req, res) => {
  try {
    const { token, window = 'Daily' } = req.body;

    if (!token) {
      return res.status(400).json({ error: 'Missing token parameter' });
    }

    const symbol = normalizeSymbol(token);
    if (!symbol) {
      return res.status(400).json({ error: 'Invalid token symbol' });
    }
    const resolvedWindow = normalizeWindow(window);
    console.log(`[API] /insights request: ${symbol} (${window})`);
    const requestStartTime = Date.now();

    const symbolToCoinId: Record<string, string> = {
      BTC: 'bitcoin',
      ETH: 'ethereum',
      BNB: 'binancecoin',
      USDT: 'tether',
      SOL: 'solana',
      XRP: 'ripple',
      DOGE: 'dogecoin',
      SUI: 'sui'
    };
    const coinId = symbolToCoinId[symbol] || String(token || '').trim().toLowerCase();

    const [enhanced, price] = await Promise.all([
      getCryptoracle().getEnhancedSentiment(symbol, resolvedWindow),
      getCoingecko().getPrice(coinId)
    ]);

    let vibeScore = 50;
    let finalEnhanced;
    
    if (enhanced && enhanced.sentiment) {
      finalEnhanced = enhanced;
      vibeScore = Math.round((enhanced.sentiment.positive * 100));
    } else {
      console.warn(`[API] No Cryptoracle data for ${symbol} - using fallback`);
      finalEnhanced = _generateFallbackData(token.toUpperCase());
      vibeScore = Math.round(finalEnhanced.sentiment.positive * 100);
    }

    const elapsed = Date.now() - requestStartTime;
    const source = enhanced && enhanced.sentiment ? 'cryptoracle' : 'fallback';
    console.log(`[API] /insights ${symbol} -> ${source} (${elapsed}ms)`);

    res.json({ 
      token: symbol,
      window: resolvedWindow,
      enhanced: finalEnhanced, 
      price,
      vibeScore,
      source,
      timestamp: Date.now(),
      responseTimeMs: elapsed
    });
  } catch (error: any) {
    console.error(`[API] /insights error:`, error?.message || 'Unknown');
    res.status(500).json({ ok: false, error: error.message });
  }
});

// Get multi-token sentiment dashboard
router.post('/multi', cryptoracleLimiter, async (req, res) => {
  try {
    const { tokens, window = 'Daily' } = req.body;
    const resolvedWindow = normalizeWindow(window);

    const tokenList = (tokens && Array.isArray(tokens) && tokens.length)
      ? normalizeSymbolList(tokens)
      : ['BTC', 'BNB', 'ETH', 'SOL', 'XRP', 'DOGE', 'SUI', 'USDT'];

    console.log(`[API] /multi request: ${tokenList.length} tokens`);
    const requestStartTime = Date.now();

    const results = await getCryptoracle().getMultiTokenSentiment(tokenList, resolvedWindow);

    const data: Record<string, any> = {};
    
    let realDataCount = 0;
    let fallbackCount = 0;
    
    tokenList.forEach((token) => {
      const result = results.get(token.toUpperCase());
      
      if (result && result.sentiment) {
        realDataCount++;
        data[token.toUpperCase()] = {
          sentiment: {
            positive: result.sentiment.positive,
            negative: result.sentiment.negative,
            sentimentDiff: result.sentiment.sentimentDiff,
          },
          community: result.community,
          signals: result.signals,
          timestamp: result.timestamp,
          isFallback: false,
        };
      } else {
        fallbackCount++;
        data[token.toUpperCase()] = _generateFallbackData(token.toUpperCase());
      }
    });

    const elapsed = Date.now() - requestStartTime;
    const source = realDataCount > 0 ? 'cryptoracle' : 'fallback';
    console.log(`[API] /multi -> ${realDataCount} real, ${fallbackCount} fallback (${elapsed}ms)`);

    res.json({ 
      ok: true, 
      window: resolvedWindow,
      tokens: data,
      updatedAt: Date.now(),
      source,
      stats: {
        total: tokenList.length,
        realData: realDataCount,
        fallbackData: fallbackCount,
        responseTimeMs: elapsed
      }
    });
  } catch (error: any) {
    console.error(`[API] /multi error:`, error?.message || 'Unknown');
    res.status(500).json({ ok: false, error: error.message });
  }
});


function _generateFallbackData(token: string): any {
  // Seed-based pseudo-random for consistency
  const seed = token.split('').reduce((a, c) => a + c.charCodeAt(0), 0);
  const random = (i: number) => ((seed * 9301 + 49297) % 233280) / 233280 * i;
  
  const baseSentiment = 0.4 + random(0.4); // 0.4 - 0.8 range
  
  return {
    sentiment: {
      positive: baseSentiment,
      negative: 1 - baseSentiment,
      sentimentDiff: (random(0.2) - 0.1), // -0.1 to +0.1
    },
    community: {
      totalMessages: Math.floor(random(50000) + 10000),
      interactions: Math.floor(random(100000) + 20000),
      mentions: Math.floor(random(30000) + 5000),
      uniqueUsers: Math.floor(random(10000) + 2000),
      activeCommunities: Math.floor(random(50) + 10),
    },
    signals: {
      deviation: random(0.3) - 0.15,
      momentum: random(0.5) - 0.25,
      breakout: random(0.2),
      priceDislocation: random(0.1),
    },
    timestamp: Date.now(),
    isFallback: true,
  };
}

router.get('/chains', (req, res) => {
  res.json({
    ok: true,
    chains: [
      {
        id: 'bitcoin',
        name: 'Bitcoin',
        symbol: 'BTC',
        network: 'Bitcoin',
        icon: '₿'
      },
      {
        id: 'binancecoin',
        name: 'BNB',
        symbol: 'BNB',
        network: 'BNB Chain',
        icon: 'B'
      },
      {
        id: 'opbnb',
        name: 'BNB',
        symbol: 'BNB',
        network: 'opBNB',
        icon: '🔷'
      },
      {
        id: 'ethereum',
        name: 'Ethereum',
        symbol: 'ETH',
        network: 'Ethereum',
        icon: 'Ξ'
      },
      {
        id: 'solana',
        name: 'Solana',
        symbol: 'SOL',
        network: 'Solana',
        icon: '◎'
      },
      {
        id: 'ripple',
        name: 'XRP',
        symbol: 'XRP',
        network: 'XRP Ledger',
        icon: '✕'
      },
      {
        id: 'dogecoin',
        name: 'Dogecoin',
        symbol: 'DOGE',
        network: 'Dogecoin',
        icon: 'Ð'
      },
      {
        id: 'sui',
        name: 'Sui',
        symbol: 'SUI',
        network: 'Sui',
        icon: '⚡'
      },
      {
        id: 'tether',
        name: 'Tether',
        symbol: 'USDT',
        network: 'Multi-chain',
        icon: '₮'
      }
    ]
  });
});

export default router;
