import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import vibeRoutes from './routes/vibe.routes';
import { startMonitorLoop } from './monitor/vibeMonitor';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'VibeGuard AI is running' });
});

app.use('/api/vibe', vibeRoutes);

app.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`🛡️  VibeGuard AI Backend running on port ${PORT}`);
});

startMonitorLoop();
