import axios from 'axios';
import { SentimentData, EnhancedSentiment, CommunityActivity, SentimentScores, SentimentSignals } from '../types';

export class CryptoracleService {
  private apiKey: string;
  private baseUrl: string;

  private readonly endpoints: string[] = [
    'CO-A-01-03', 'CO-A-01-04', 'CO-A-01-05', 'CO-A-01-07', 'CO-A-01-08',
    'CO-A-02-01', 'CO-A-02-02', 'CO-A-02-03',
    'CO-S-01-01', 'CO-S-01-02', 'CO-S-01-03', 'CO-S-01-05'
  ];

  private readonly cache = new Map<
    string,
    {
      value: EnhancedSentiment;
      expiresAtMs: number;
      storedAtMs: number;
    }
  >();

  constructor() {
    this.apiKey = process.env.CRYPTORACLE_API_KEY || '';
    this.baseUrl = process.env.CRYPTORACLE_BASE_URL || 'https://service.cryptoracle.network';
    
    // Log configuration when service is created
    if (this.apiKey) {
      console.log('[Cryptoracle] Service initialized with API key');
    } else {
      console.warn('[Cryptoracle] ⚠️ No API key configured - will use fallback data');
    }
  }

  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    };
    if (this.apiKey) headers['X-API-KEY'] = this.apiKey;
    return headers;
  }

  private cacheKey({ symbol, timeType }: { symbol: string; timeType: string }): string {
    return `cryptoracle:v2.1:${symbol}:${timeType}:${this.endpoints.join(',')}`;
  }

  private baseCacheTtlMs(): number {
    const env = Number(process.env.CRYPTORACLE_CACHE_TTL_MS ?? 60000);
    if (!Number.isFinite(env) || env <= 0) return 60000;
    return env;
  }

  private ttlForTimeType(timeType: string): number {
    const base = this.baseCacheTtlMs();
    const multiplier =
      timeType === '15m' ? 0.5 :
      timeType === '1h' ? 1 :
      timeType === '4h' ? 2 :
      5;
    const ttl = Math.round(base * multiplier);
    return Math.max(15000, Math.min(ttl, 5 * 60 * 1000));
  }

  private staleForTimeType(timeType: string): number {
    const env = Number(process.env.CRYPTORACLE_CACHE_STALE_MS ?? NaN);
    if (Number.isFinite(env) && env > 0) return env;
    return this.ttlForTimeType(timeType) * 10;
  }

  private getFromCache(key: string): EnhancedSentiment | null {
    const hit = this.cache.get(key);
    if (!hit) return null;
    if (Date.now() > hit.expiresAtMs) return null;
    return hit.value;
  }

  private getStaleFromCache(key: string, maxAgeMs: number): EnhancedSentiment | null {
    const hit = this.cache.get(key);
    if (!hit) return null;
    if (Date.now() - hit.storedAtMs > maxAgeMs) return null;
    return hit.value;
  }

  private setCache(key: string, value: EnhancedSentiment, ttlMs: number): void {
    const now = Date.now();
    this.cache.set(key, {
      value,
      expiresAtMs: now + ttlMs,
      storedAtMs: now,
    });
  }

  async getSentiment(token: string): Promise<SentimentData> {
    const symbol = String(token || '').trim().toUpperCase();
    if (!symbol) return { token: symbol, score: 50, timestamp: Date.now(), sources: [] };

    console.log(`[Cryptoracle] Fetching sentiment for ${symbol}...`);
    const startTime = Date.now();

    try {
      const enhanced = await this.getEnhancedSentiment(symbol, 'Daily');
      if (!enhanced) {
        console.warn(`[Cryptoracle] No data for ${symbol}, using fallback`);
        return {
          token: symbol,
          score: this.fallbackScore(symbol),
          timestamp: Date.now(),
          sources: ['fallback']
        };
      }

      const elapsed = Date.now() - startTime;
      console.log(`[Cryptoracle] ✅ ${symbol} sentiment fetched in ${elapsed}ms (Score: ${Math.round((enhanced.sentiment.positive ?? 0.5) * 100)})`);
      
      return {
        token: symbol,
        score: Math.round((enhanced.sentiment.positive ?? 0.5) * 100),
        timestamp: Date.now(),
        sources: ['cryptoracle']
      };
    } catch (error: any) {
      const elapsed = Date.now() - startTime;
      console.error(`[Cryptoracle] Error for ${symbol} (${elapsed}ms):`, error?.message || 'Unknown');
      return {
        token: symbol,
        score: this.fallbackScore(symbol),
        timestamp: Date.now(),
        sources: ['fallback']
      };
    }
  }

  private fallbackScore(symbol: string): number {
    const seed = symbol.split('').reduce((a, c) => a + c.charCodeAt(0), 0);
    const random01 = (i: number) => (((seed * 9301 + 49297 + i * 233) % 233280) / 233280);
    const positive = 0.4 + random01(7) * 0.4;
    return Math.round(positive * 100);
  }

  async getEnhancedSentiment(token: string, window: string = 'Daily'): Promise<EnhancedSentiment | null> {
    const symbol = String(token || '').trim().toUpperCase();
    if (!symbol) {
      console.warn('[Cryptoracle] Empty token symbol');
      return null;
    }
    
    if (!this.apiKey) {
      console.warn('[Cryptoracle] No API key - skipping API call');
      return null;
    }

    const requestStartTime = Date.now();
    const timeType = this.windowToTimeType(window);
    const cacheKey = this.cacheKey({ symbol, timeType });
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    try {
      const headers = this.getHeaders();
      const endpointUrl = this.resolveOpenApiEndpointUrl();
      const { startTime, endTime } = this.getTimeRange(timeType);

      console.log(`[Cryptoracle] Requesting ${symbol} (${window}) - ${startTime} to ${endTime}`);

      const records = await this.fetchOpenApiRecords({
        endpointUrl,
        headers,
        endpoints: this.endpoints,
        startTime,
        endTime,
        timeType,
        tokens: [symbol],
      });

      const built = this.buildEnhancedSentimentFromRecords({ symbol, window, records });
      if (!built) return null;

      this.setCache(cacheKey, built, this.ttlForTimeType(timeType));

      const elapsed = Date.now() - requestStartTime;
      console.log(
        `[Cryptoracle] ✅ ${symbol}: ${(built.sentiment.positive * 100).toFixed(1)}% positive, ${built.community.totalMessages} messages (${elapsed}ms)`
      );

      return built;
    } catch (error: any) {
      const elapsed = Date.now() - requestStartTime;
      const status = error?.response?.status;
      const errorMsg = error?.message || 'Unknown';
      
      if (status === 401 || status === 403) {
        console.error(`[Cryptoracle] Auth failed for ${symbol} - check API key`);
      } else if (status === 429) {
        console.error(`[Cryptoracle] Rate limited for ${symbol}`);
      } else if (error?.code === 'ECONNABORTED') {
        console.error(`[Cryptoracle] Timeout for ${symbol} (${elapsed}ms)`);
      } else {
        console.error(`[Cryptoracle] Error for ${symbol}: ${errorMsg}`);
      }

      // Serve stale cache (short-lived) on transient failures / rate limiting.
      if (status === 429 || error?.code === 'ECONNABORTED') {
        const stale = this.getStaleFromCache(cacheKey, this.staleForTimeType(timeType));
        if (stale) return stale;
      }
      return null;
    }
  }

  private async fetchOpenApiRecords(params: {
    endpointUrl: string;
    headers: Record<string, string>;
    endpoints: string[];
    startTime: string;
    endTime: string;
    timeType: string;
    tokens: string[];
  }): Promise<any[]> {
    const response = await axios.post(
      params.endpointUrl,
      {
        // Body apiKey is optional in docs examples; header X-API-KEY is required.
        apiKey: this.apiKey,
        endpoints: params.endpoints,
        startTime: params.startTime,
        endTime: params.endTime,
        timeType: params.timeType,
        token: params.tokens,
      },
      { headers: params.headers, timeout: 20000 }
    );

    return this.normalizeOpenApiRecords(response.data);
  }

  private buildEnhancedSentimentFromRecords(params: {
    symbol: string;
    window: string;
    records: any[];
  }): EnhancedSentiment | null {
    const symbol = params.symbol.toUpperCase();
    const records = params.records || [];

    if (records.length === 0) {
      console.warn(`[Cryptoracle] No records for ${symbol}`);
      return null;
    }

    const byEndpoint = new Map<string, { value: number; timeMs: number }>();
    let latestTimeMs = 0;

    for (let i = 0; i < records.length; i++) {
      const r = records[i];
      if (String(r?.token || '').toUpperCase() !== symbol) continue;
      const endpoint = String(
        r?.endpoint ?? r?.endpoints ?? r?.endpointId ?? r?.endpoint_id ?? ''
      ).trim();
      if (!endpoint) continue;

      const value = this.toNumber(r?.value);
      if (value === null) continue;

      const timeMs = this.extractRecordTimeMs(r) ?? i; // if unknown, preserve stable ordering
      const prev = byEndpoint.get(endpoint);
      if (!prev || timeMs >= prev.timeMs) {
        byEndpoint.set(endpoint, { value, timeMs });
      }
      if (timeMs > latestTimeMs) latestTimeMs = timeMs;
    }

    const v = (endpoint: string) => byEndpoint.get(endpoint)?.value ?? 0;

    const community: CommunityActivity = {
      totalMessages: Math.round(v('CO-A-01-03')),
      interactions: Math.round(v('CO-A-01-04')),
      mentions: Math.round(v('CO-A-01-05')),
      uniqueUsers: Math.round(v('CO-A-01-07')),
      activeCommunities: Math.round(v('CO-A-01-08')),
    };

    const sentiment: SentimentScores = {
      positive: this.normalizeRatioOrPercent(v('CO-A-02-01')),
      negative: this.normalizeRatioOrPercent(v('CO-A-02-02')),
      sentimentDiff: this.normalizeSignedRatioOrPercent(v('CO-A-02-03')),
    };

    const signals: SentimentSignals = {
      deviation: v('CO-S-01-01'),
      momentum: v('CO-S-01-02'),
      breakout: v('CO-S-01-03'),
      priceDislocation: v('CO-S-01-05'),
    };

    const looksEmpty =
      community.totalMessages === 0 &&
      community.interactions === 0 &&
      community.mentions === 0 &&
      community.uniqueUsers === 0 &&
      community.activeCommunities === 0 &&
      sentiment.positive === 0 &&
      sentiment.negative === 0 &&
      sentiment.sentimentDiff === 0 &&
      signals.deviation === 0 &&
      signals.momentum === 0 &&
      signals.breakout === 0 &&
      signals.priceDislocation === 0;

    if (looksEmpty) {
      console.warn(`[Cryptoracle] All values zero for ${symbol}`);
      return null;
    }

    return {
      token: symbol,
      window: params.window,
      community,
      sentiment,
      signals,
      // Prefer upstream record time if we can parse it.
      timestamp: latestTimeMs > 1000000000 ? latestTimeMs : Date.now(),
    };
  }

  private normalizeRatioOrPercent(raw: number): number {
    if (!Number.isFinite(raw)) return 0;
    const v = raw > 1.5 ? raw / 100 : raw;
    if (!Number.isFinite(v)) return 0;
    return Math.max(0, Math.min(1, v));
  }

  private normalizeSignedRatioOrPercent(raw: number): number {
    if (!Number.isFinite(raw)) return 0;
    const v = Math.abs(raw) > 1.5 ? raw / 100 : raw;
    if (!Number.isFinite(v)) return 0;
    return Math.max(-1, Math.min(1, v));
  }

  private extractRecordTimeMs(record: any): number | null {
    const candidates = [
      record?.time,
      record?.timestamp,
      record?.timeStamp,
      record?.ts,
      record?.datetime,
      record?.date,
    ];

    for (const c of candidates) {
      if (typeof c === 'number' && Number.isFinite(c)) {
        // Heuristic: seconds vs milliseconds
        if (c > 1e12) return Math.floor(c);
        if (c > 1e9) return Math.floor(c * 1000);
      }
      if (typeof c === 'string' && c.trim()) {
        const s = c.trim();
        const asNum = Number(s);
        if (Number.isFinite(asNum)) {
          if (asNum > 1e12) return Math.floor(asNum);
          if (asNum > 1e9) return Math.floor(asNum * 1000);
        }

        // Try parse "YYYY-MM-DD HH:mm:ss" as UTC
        const m = s.match(
          /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})$/
        );
        if (m) {
          const [_, yy, mo, dd, hh, mm, ss] = m;
          const ms = Date.UTC(
            Number(yy),
            Number(mo) - 1,
            Number(dd),
            Number(hh),
            Number(mm),
            Number(ss)
          );
          if (Number.isFinite(ms)) return ms;
        }

        const parsed = Date.parse(s);
        if (Number.isFinite(parsed)) return parsed;
      }
    }

    return null;
  }

  private resolveOpenApiEndpointUrl(): string {
    const raw = String(this.baseUrl || '').trim().replace(/\/+$/, '');
    
    // If empty, use default
    if (!raw) return 'https://service.cryptoracle.network/openapi/v2.1/endpoint';
    
    // If already complete with /endpoint, use directly
    if (raw.endsWith('/endpoint')) return raw;
    
    // If already has /openapi/v2.1, append /endpoint
    if (raw.includes('/openapi/v2.1')) return `${raw}/endpoint`;
    
    // If only base domain, append full path
    return `${raw}/openapi/v2.1/endpoint`;
  }

  private windowToTimeType(window: string): string {
    switch (String(window || '').trim()) {
      case '15M': return '15m';
      case '1H': return '1h';
      case '4H': return '4h';
      default: return '1d';
    }
  }

  private getTimeRange(timeType: string): { startTime: string; endTime: string } {
    const now = new Date();
    const end = now;
    const ms =
      timeType === '15m' ? 15 * 60 * 1000 :
      timeType === '1h' ? 60 * 60 * 1000 :
      timeType === '4h' ? 4 * 60 * 60 * 1000 :
      24 * 60 * 60 * 1000;
    const start = new Date(end.getTime() - ms);
    return { startTime: this.formatUtc(start), endTime: this.formatUtc(end) };
  }

  private formatUtc(d: Date): string {
    const pad = (n: number) => String(n).padStart(2, '0');
    return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())} ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}`;
  }

  private toNumber(v: any): number | null {
    if (typeof v === 'number' && Number.isFinite(v)) return v;
    if (typeof v === 'string') {
      const n = Number(v);
      if (Number.isFinite(n)) return n;
    }
    return null;
  }

  private normalizeOpenApiRecords(payload: any): Array<any> {
    const root = payload?.data ?? payload?.result ?? payload;
    const unwrap = (x: any): any => {
      if (typeof x === 'string') {
        try { return JSON.parse(x); } catch { return x; }
      }
      return x;
    };
    const unwrapped = unwrap(root);
    const data = unwrap(unwrapped?.data ?? unwrapped?.result ?? unwrapped);
    if (Array.isArray(data)) return data as any[];
    if (Array.isArray(data?.records)) return data.records as any[];
    if (Array.isArray(data?.list)) return data.list as any[];
    if (Array.isArray(data?.items)) return data.items as any[];
    return [];
  }

  async getMultiTokenSentiment(tokens: string[], window: string = 'Daily'): Promise<Map<string, EnhancedSentiment | null>> {
    console.log(`[Cryptoracle] Fetching sentiment for ${tokens.length} tokens: ${tokens.slice(0, 5).join(', ')}${tokens.length > 5 ? '...' : ''}`);
    const startTime = Date.now();
    
    const results = new Map<string, EnhancedSentiment | null>();
    const unique = Array.from(
      new Set((tokens || []).map((t) => String(t || '').trim().toUpperCase()).filter(Boolean))
    );

    if (unique.length === 0) return results;

    if (!this.apiKey) {
      unique.forEach((t) => results.set(t, null));
      return results;
    }

    const headers = this.getHeaders();
    const endpointUrl = this.resolveOpenApiEndpointUrl();
    const timeType = this.windowToTimeType(window);
    const { startTime: rangeStartTime, endTime: rangeEndTime } = this.getTimeRange(timeType);

    try {
      const records = await this.fetchOpenApiRecords({
        endpointUrl,
        headers,
        endpoints: this.endpoints,
        startTime: rangeStartTime,
        endTime: rangeEndTime,
        timeType,
        tokens: unique,
      });

      for (const symbol of unique) {
        const cacheKey = this.cacheKey({ symbol, timeType });
        const built = this.buildEnhancedSentimentFromRecords({ symbol, window, records });
        if (built) {
          this.setCache(cacheKey, built, this.ttlForTimeType(timeType));
          results.set(symbol, built);
        } else {
          results.set(symbol, null);
        }
      }
    } catch (error: any) {
      const status = error?.response?.status;
      const fallbackFromCache = status === 429 || error?.code === 'ECONNABORTED';
      for (const symbol of unique) {
        if (fallbackFromCache) {
          const cacheKey = this.cacheKey({ symbol, timeType });
          const stale = this.getStaleFromCache(cacheKey, this.staleForTimeType(timeType));
          results.set(symbol, stale);
        } else {
          results.set(symbol, null);
        }
      }
    }

    const successCount = Array.from(results.values()).filter(v => v !== null).length;
    const elapsed = Date.now() - startTime;
    console.log(`[Cryptoracle] ✅ Multi-token complete: ${successCount}/${tokens.length} successful (${elapsed}ms)`);

    return results;
  }
}
