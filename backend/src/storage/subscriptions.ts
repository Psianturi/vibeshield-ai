import fs from 'fs';
import path from 'path';

export interface Subscription {
  userAddress: string;
  tokenSymbol: string;
  tokenId: string;
  tokenAddress: string;
  amount: string; // human-readable, assumed 18 decimals for demo
  enabled: boolean;
  riskThreshold: number; // 0-100
}

const DATA_DIR = path.join(process.cwd(), 'data');
const FILE_PATH = path.join(DATA_DIR, 'subscriptions.json');

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
}

export function loadSubscriptions(): Subscription[] {
  try {
    ensureDataDir();
    if (!fs.existsSync(FILE_PATH)) return [];
    const raw = fs.readFileSync(FILE_PATH, 'utf-8');
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as Subscription[]) : [];
  } catch {
    return [];
  }
}

export function saveSubscriptions(subs: Subscription[]) {
  ensureDataDir();
  fs.writeFileSync(FILE_PATH, JSON.stringify(subs, null, 2));
}

export function upsertSubscription(sub: Subscription) {
  const subs = loadSubscriptions();
  const idx = subs.findIndex(
    (s) => s.userAddress.toLowerCase() === sub.userAddress.toLowerCase() && s.tokenAddress.toLowerCase() === sub.tokenAddress.toLowerCase()
  );

  if (idx >= 0) subs[idx] = sub;
  else subs.push(sub);

  saveSubscriptions(subs);
  return sub;
}
