import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import vibeRoutes from './routes/vibe.routes';
import { startMonitorLoop } from './monitor/vibeMonitor';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

const corsOptions: cors.CorsOptions = {
  origin: process.env.CORS_ORIGIN
    ? process.env.CORS_ORIGIN.split(',').map((s) => s.trim()).filter(Boolean)
    : true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  optionsSuccessStatus: 204
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    message: 'VibeShield AI is running',
    config: {
      kalibr: {
        apiKey: Boolean(process.env.KALIBR_API_KEY),
        tenantId: Boolean(process.env.KALIBR_TENANT_ID),
        intelligenceUrl: process.env.KALIBR_INTELLIGENCE_URL || 'https://kalibr-intelligence.fly.dev'
      },
      gemini: {
        apiKey: Boolean(process.env.GOOGLE_API_KEY || process.env.GEMINI_API_KEY)
      },
      cryptoracle: {
        apiKey: Boolean(process.env.CRYPTORACLE_API_KEY),
        baseUrl: process.env.CRYPTORACLE_BASE_URL || 'https://service.cryptoracle.network'
      },
      coingecko: {
        apiKey: Boolean(process.env.COINGECKO_API_KEY)
      },
      blockchain: {
        rpcUrl: Boolean(process.env.EVM_RPC_URL || process.env.SEPOLIA_RPC_URL || process.env.BSC_RPC_URL),
        privateKey: Boolean(process.env.PRIVATE_KEY),
        vaultAddress: Boolean(process.env.VIBESHIELD_VAULT_ADDRESS || process.env.VIBEGUARD_VAULT_ADDRESS)
      },
      monitor: {
        enabled: String(process.env.ENABLE_MONITOR || '').toLowerCase() === 'true',
        intervalMs: Number(process.env.MONITOR_INTERVAL_MS ?? 30000)
      }
    }
  });
});

app.use('/api/vibe', vibeRoutes);

app.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`🛡️  VibeShield AI Backend running on port ${PORT}`);
});

startMonitorLoop();
