import axios from 'axios';
import { RiskAnalysis, SentimentData, PriceData } from '../types';

export class KalibrService {
  private apiKey: string;
  private tenantId: string;
  private intelligenceUrl: string;
  private goal: string;
  private googleApiKey: string;
  private modelHigh: string;
  private modelLow: string;
  private sentimentBadThreshold: number;
  private modelFallbacks: string[];
  private modelsCache?: { expiresAt: number; generateContentModels: Set<string> };

  

  constructor() {
    this.apiKey = process.env.KALIBR_API_KEY || '';
    this.tenantId = process.env.KALIBR_TENANT_ID || '';
    this.intelligenceUrl = process.env.KALIBR_INTELLIGENCE_URL || 'https://kalibr-intelligence.fly.dev';
    this.goal = process.env.KALIBR_GOAL || 'vibeguard_risk';
    this.googleApiKey = process.env.GOOGLE_API_KEY || process.env.GEMINI_API_KEY || '';
    this.modelHigh = process.env.KALIBR_MODEL_HIGH || 'gemini-2.0-flash';
    this.modelLow = process.env.KALIBR_MODEL_LOW || 'gemini-2.0-flash';
    this.sentimentBadThreshold = Number(process.env.SENTIMENT_BAD_THRESHOLD ?? 30);

    const fallbackStr = process.env.GEMINI_MODEL_FALLBACKS || 'gemini-2.5-flash,gemini-2.0-flash,gemini-2.0-flash-lite,gemini-1.5-flash-8b';
    this.modelFallbacks = fallbackStr
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
  }

  private formatAxiosError(error: any): string {
    const status = error?.response?.status;
    const statusText = error?.response?.statusText;
    const message = error?.message;
    const providerMsg = error?.response?.data?.error?.message;
    return [
      status ? `status ${status}` : null,
      statusText,
      providerMsg,
      message
    ]
      .filter(Boolean)
      .join(' - ');
  }

  private getKalibrHeaders() {
    return {
      'X-API-Key': this.apiKey,
      'X-Tenant-ID': this.tenantId,
      'Content-Type': 'application/json'
    };
  }

  private async registerPathsIfPossible() {
    if (!this.apiKey || !this.tenantId) return;

    const models = Array.from(new Set([this.modelHigh, this.modelLow].filter(Boolean)));
    await Promise.all(
      models.map(async (modelId) => {
        try {
          await axios.post(
            `${this.intelligenceUrl}/api/v1/routing/paths`,
            { goal: this.goal, model_id: modelId },
            { headers: this.getKalibrHeaders(), timeout: 15000 }
          );
        } catch {
          // Ignore: path registration can be idempotent or may already exist.
        }
      })
    );
  }

  private async decideModel(): Promise<{ traceId: string; modelId: string } | null> {
    if (!this.apiKey || !this.tenantId) return null;

    await this.registerPathsIfPossible();

    const res = await axios.post(
      `${this.intelligenceUrl}/api/v1/routing/decide`,
      { goal: this.goal },
      { headers: this.getKalibrHeaders(), timeout: 15000 }
    );

    const data = res.data ?? {};
    const traceId = data.trace_id || data.traceId || (globalThis.crypto?.randomUUID?.() ?? String(Date.now()));
    const modelId = data.model_id || data.modelId || data.recommended_model || this.modelLow;

    return { traceId, modelId };
  }

  private async reportOutcome(params: { traceId: string; modelId: string; success: boolean; reason?: string }) {
    if (!this.apiKey || !this.tenantId) return;

    try {
      await axios.post(
        `${this.intelligenceUrl}/api/v1/intelligence/report-outcome`,
        {
          trace_id: params.traceId,
          goal: this.goal,
          success: params.success,
          model_id: params.modelId,
          reason: params.reason
        },
        { headers: this.getKalibrHeaders(), timeout: 15000 }
      );
    } catch (e) {
      console.warn('Kalibr report-outcome failed');
    }
  }

  private async callGemini(
    modelId: string,
    prompt: string
  ): Promise<{ text: string; usedModel: string; requestedModel: string; apiVersion: 'v1beta' | 'v1'; fallbackFrom?: string }> {
    if (!this.googleApiKey) throw new Error('Missing GOOGLE_API_KEY (or GEMINI_API_KEY)');

    // Refuse to call Gemini while in 429 backoff cooldown
    if (this.isBackedOff()) {
      const secs = Math.ceil((this._backoffUntil - Date.now()) / 1000);
      throw Object.assign(new Error(`Gemini 429 backoff active (${secs}s remaining)`), { response: { status: 429 } });
    }

    const resolved = await this.resolveGeminiModel(modelId);
    const resolvedModel = resolved.model;

    const tryCall = async (apiVersion: 'v1beta' | 'v1') => {
      const modelPath = resolvedModel.startsWith('models/') ? resolvedModel : `models/${resolvedModel}`;
      const url = `https://generativelanguage.googleapis.com/${apiVersion}/${modelPath}:generateContent?key=${this.googleApiKey}`;

      const response = await axios.post(
        url,
        {
          contents: [{ role: 'user', parts: [{ text: prompt }] }]
        },
        { timeout: 30000 }
      );

      const text =
        response.data?.candidates?.[0]?.content?.parts?.[0]?.text ??
        response.data?.candidates?.[0]?.content?.parts?.map((p: any) => p?.text).filter(Boolean).join('\n');

      if (!text) throw new Error('Empty Gemini response');
      return String(text);
    };

    try {
      const text = await tryCall('v1beta');
      this.clearBackoff();          // success → reset backoff
      return {
        text,
        usedModel: resolvedModel,
        requestedModel: modelId,
        apiVersion: 'v1beta',
        fallbackFrom: resolved.fallbackFrom
      };
    } catch (e: any) {
      // 429 → exponential backoff
      if (e?.response?.status === 429) {
        this.recordBackoff();
        throw e;
      }

      const msg = this.formatAxiosError(e);
      // Some accounts/models respond only under v1; retry once.
      if (String(msg).includes('not found') || e?.response?.status === 404) {
        const text = await tryCall('v1');
        this.clearBackoff();
        return {
          text,
          usedModel: resolvedModel,
          requestedModel: modelId,
          apiVersion: 'v1',
          fallbackFrom: resolved.fallbackFrom
        };
      }
      throw e;
    }
  }

  async listGeminiGenerateContentModels(): Promise<string[]> {
    if (!this.googleApiKey) throw new Error('Missing GOOGLE_API_KEY (or GEMINI_API_KEY)');

    const now = Date.now();
    if (this.modelsCache && this.modelsCache.expiresAt > now) {
      return Array.from(this.modelsCache.generateContentModels);
    }

    const fetchModels = async (apiVersion: 'v1beta' | 'v1') => {
      const url = `https://generativelanguage.googleapis.com/${apiVersion}/models?key=${this.googleApiKey}`;
      const res = await axios.get(url, { timeout: 20000 });
      const models = res.data?.models;
      if (!Array.isArray(models)) return [];
      return models
        .filter((m: any) => Array.isArray(m?.supportedGenerationMethods) && m.supportedGenerationMethods.includes('generateContent'))
        .map((m: any) => String(m?.name || ''))
        .filter(Boolean)
        .map((name: string) => name.replace(/^models\//, ''));
    };

    // Try v1beta first; if it fails, try v1.
    let names: string[] = [];
    try {
      names = await fetchModels('v1beta');
    } catch {
      names = await fetchModels('v1');
    }

    this.modelsCache = {
      expiresAt: now + 10 * 60 * 1000,
      generateContentModels: new Set(names)
    };

    return names;
  }

  private async resolveGeminiModel(requested: string): Promise<{ model: string; fallbackFrom?: string }> {
    // If user explicitly configured a model, try to honor it.
    // If it's unsupported, fall back to a known-good model from the account.
    const clean = (requested || '').trim();
    if (!clean) return { model: this.modelLow };

    let available: string[] = [];
    try {
      available = await this.listGeminiGenerateContentModels();
    } catch {
      return { model: clean };
    }

    const set = new Set(available.map((m) => m.toLowerCase()));
    if (set.has(clean.toLowerCase())) return { model: clean };

    for (const fb of this.modelFallbacks) {
      if (set.has(fb.toLowerCase())) return { model: fb, fallbackFrom: clean };
    }

    // As a last resort, pick the first available model.
    return { model: available[0] || clean, fallbackFrom: available[0] ? clean : undefined };
  }

  async analyzeRisk(
    sentiment: SentimentData,
    price: PriceData,
    options?: {
      injectedContext?: {
        headline: string;
        severity?: 'HIGH' | 'CRITICAL';
      };
    }
  ): Promise<RiskAnalysis> {
    // Prepare prompt once.
    let prompt = `Analyze crypto risk:
Token: ${sentiment.token}
Sentiment Score: ${sentiment.score}/100
Price Change 24h: ${price.priceChange24h}%
Volume 24h: $${price.volume24h}

Should we exit position? Respond with JSON: {riskScore: 0-100, shouldExit: boolean, reason: string}`;

    const injected = options?.injectedContext;
    if (injected?.headline) {
      const severity = injected.severity ?? 'CRITICAL';
      prompt += `

  ⚠️ EMERGENCY CONTEXT (WEIGHTED INPUT)
  Headline: "${injected.headline}"
  Severity: ${severity}

  Instructions:
  - Treat this event as verified for simulation purpose.
  - Weigh emergency context at 80% and regular market metrics at 20%.
  - If the headline indicates exploit, hack, insolvency, or bridge compromise, set riskScore > 85 and shouldExit=true.
  - Explain clearly in reason why this event materially changes short-term risk.`;
    }

    // If Kalibr tenant is configured, use Kalibr Intelligence to pick the model.
    let traceId: string = globalThis.crypto?.randomUUID?.() ?? String(Date.now());
    let chosenModel = sentiment.score < this.sentimentBadThreshold ? this.modelHigh : this.modelLow;

    try {
      const decision = await this.decideModel();
      chosenModel = decision?.modelId ?? chosenModel;
      traceId = decision?.traceId ?? traceId;

      const gemini = await this.callGemini(chosenModel, prompt);
      const raw = gemini.text;

      // Gemini may wrap JSON in markdown; try to extract the first JSON object.
      const jsonMatch = raw.match(/\{[\s\S]*\}/);
      const jsonText = (jsonMatch ? jsonMatch[0] : raw).trim();

      const result = JSON.parse(jsonText);

      if (gemini.fallbackFrom) {
        // Kalibr chose a model id that the current Gemini key can't use.
        await this.reportOutcome({
          traceId,
          modelId: gemini.fallbackFrom,
          success: false,
          reason: `model unavailable; used ${gemini.usedModel}`.slice(0, 120)
        });
      } else {
        await this.reportOutcome({ traceId, modelId: chosenModel, success: true });
      }

      return { ...result, aiModel: gemini.usedModel };
    } catch (error) {
      const msg = this.formatAxiosError(error);
      console.error('Kalibr/Gemini error:', msg);

      await this.reportOutcome({
        traceId,
        modelId: chosenModel,
        success: false,
        reason: msg ? msg.slice(0, 120) : 'exception'
      });

      return {
        riskScore: 50,
        shouldExit: false,
        reason: msg ? `Analysis failed (${msg})` : 'Analysis failed',
        aiModel: chosenModel || 'fallback'
      };
    }
  }

  // ---------------------------------------------------------------------------
  // Rate-limit awareness: track 429 backoff
  // ---------------------------------------------------------------------------
  private _backoffUntil = 0;
  private _backoffMs = 0;
  private static readonly BACKOFF_INITIAL_MS = 15_000;  // 15s
  private static readonly BACKOFF_MAX_MS = 300_000;     // 5 min

  private isBackedOff(): boolean {
    return Date.now() < this._backoffUntil;
  }

  private recordBackoff(): void {
    this._backoffMs = this._backoffMs > 0
      ? Math.min(this._backoffMs * 2, KalibrService.BACKOFF_MAX_MS)
      : KalibrService.BACKOFF_INITIAL_MS;
    this._backoffUntil = Date.now() + this._backoffMs;
    console.warn(`[Kalibr] 429 backoff: pausing Gemini calls for ${this._backoffMs / 1000}s`);
  }

  private clearBackoff(): void {
    this._backoffMs = 0;
    this._backoffUntil = 0;
  }

  // ---------------------------------------------------------------------------
  // Market brief cache (avoid calling Gemini on every page load)
  // ---------------------------------------------------------------------------
  private _briefCache: { text: string; expiresAt: number } | null = null;
  private static readonly BRIEF_CACHE_TTL_MS = Number(process.env.MARKET_BRIEF_CACHE_TTL_MS ?? 300_000); // 5 min

  /**
   * Generate a concise 1-sentence market brief for the Agent Intel Feed.
   * Uses Gemini via Kalibr routing with a lightweight prompt.
   * Results are cached for 5 minutes to avoid rate limits.
   */
  async generateMarketBrief(marketData: {
    btc?: { price: number; change24h: number } | null;
    eth?: { price: number; change24h: number } | null;
    bnb?: { price: number; change24h: number } | null;
    sentimentScore: number;
    sentimentLabel: string;
  }): Promise<string> {
    // Return cached brief if still fresh.
    if (this._briefCache && Date.now() < this._briefCache.expiresAt) {
      return this._briefCache.text;
    }

    // Skip if in 429 backoff period.
    if (this.isBackedOff()) {
      const score = marketData.sentimentScore;
      return this.fallbackBrief(score);
    }

    const btcChange = marketData.btc?.change24h?.toFixed(2) ?? 'N/A';
    const ethChange = marketData.eth?.change24h?.toFixed(2) ?? 'N/A';
    const bnbChange = marketData.bnb?.change24h?.toFixed(2) ?? 'N/A';

    const prompt = `You are VibeShield AI, an autonomous crypto portfolio guardian agent on BNB Chain.

Market snapshot:
- BTC 24h change: ${btcChange}%
- ETH 24h change: ${ethChange}%
- BNB 24h change: ${bnbChange}%
- Social sentiment score: ${marketData.sentimentScore}/100 (${marketData.sentimentLabel})

Task: Give exactly ONE sentence of witty, actionable market insight for a DeFi investor.
Style: Cyberpunk-professional, concise, confident.
Max length: 120 characters.
Do NOT use markdown or quotes. Just the sentence.`;

    try {
      const decision = await this.decideModel();
      const modelId = decision?.modelId ?? this.modelLow;
      const gemini = await this.callGemini(modelId, prompt);
      this.clearBackoff();

      const text = gemini.text.split('\n')[0].replace(/^["']|["']$/g, '').trim();
      const result = text || 'Markets in flux. Stay vigilant, Guardian.';

      // Cache the result.
      this._briefCache = { text: result, expiresAt: Date.now() + KalibrService.BRIEF_CACHE_TTL_MS };
      return result;
    } catch (e: any) {
      const status = e?.response?.status;
      if (status === 429) this.recordBackoff();

      console.warn('[Kalibr] generateMarketBrief failed:', e.message);
      return this.fallbackBrief(marketData.sentimentScore);
    }
  }

  private fallbackBrief(score: number): string {
    if (score >= 65) return 'Bullish momentum detected. Shields on standby.';
    if (score <= 35) return 'Bearish signals rising. Guardian shields activated.';
    return 'Markets in flux. Stay vigilant, Guardian.';
  }
}
