import fs from 'fs';
import path from 'path';

export interface TxHistoryItem {
  userAddress: string;
  tokenAddress: string;
  txHash: string;
  timestamp: number;
  source: 'monitor' | 'manual' | 'agent';
  // Optional metadata to make explorers easier to interpret.
  executorAddress?: string;
  routerAddress?: string;
}

const DATA_DIR = path.join(process.cwd(), 'data');
const FILE_PATH = path.join(DATA_DIR, 'tx_history.json');
const MAX_ITEMS = 500;

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
}

export function loadTxHistory(params?: { userAddress?: string; limit?: number }): TxHistoryItem[] {
  try {
    ensureDataDir();
    if (!fs.existsSync(FILE_PATH)) return [];
    const raw = fs.readFileSync(FILE_PATH, 'utf-8');
    const parsed = JSON.parse(raw);
    const all = Array.isArray(parsed) ? (parsed as TxHistoryItem[]) : [];

    const filtered = params?.userAddress
      ? all.filter((t) => t.userAddress.toLowerCase() === params.userAddress!.toLowerCase())
      : all;

    const limit = Math.max(1, Math.min(Number(params?.limit ?? 100), 500));
    return filtered
      .slice()
      .sort((a, b) => b.timestamp - a.timestamp)
      .slice(0, limit);
  } catch {
    return [];
  }
}

export function appendTxHistory(item: TxHistoryItem) {
  const all = loadTxHistory();
  all.push(item);

  // Keep newest MAX_ITEMS
  const trimmed = all
    .slice()
    .sort((a, b) => b.timestamp - a.timestamp)
    .slice(0, MAX_ITEMS);

  ensureDataDir();
  fs.writeFileSync(FILE_PATH, JSON.stringify(trimmed, null, 2));
}
