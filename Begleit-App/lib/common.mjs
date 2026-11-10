import { randomBytes, timingSafeEqual } from 'node:crypto';
export const VERSION = '1.0.0-alpha';
export const PROVIDERS = ['chatgpt', 'openrouter', 'gemini', 'groq', 'mistral', 'ollama', 'openai', 'anthropic', 'custom'];
export const EFFORTS = ['default', 'none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max'];
export class AppError extends Error {
  constructor(code, message = code, status = 400) { super(message); this.code = code; this.status = status; }
}
export const token = (size = 32) => randomBytes(size).toString('base64url');
export function equal(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const aa = Buffer.from(a), bb = Buffer.from(b);
  return aa.length === bb.length && timingSafeEqual(aa, bb);
}
export function validString(s, max = 1024) { return typeof s === 'string' && s.length <= max && !/[\x00-\x08\x0b\x0c\x0e-\x1f]/.test(s); }
export function modelID(s) { return typeof s === 'string' && /^[A-Za-z0-9][A-Za-z0-9._:/+@~-]{0,199}$/.test(s); }
export function publicError(e) {
  const code = /^[a-zA-Z0-9_.-]{1,100}$/.test(e?.code || '') ? e.code : 'request_failed';
  // Do not expose arbitrary upstream bodies, authorization URLs, keys, or prompts.
  return { code, message: e instanceof AppError ? String(e.message).slice(0,350) : 'The operation failed. No credentials were logged.' };
}
export function validateBaseURL(raw) {
  let u; try { u = new URL(raw); } catch { throw new AppError('bad_endpoint'); }
  const loopback = ['127.0.0.1','localhost','[::1]'].includes(u.hostname);
  if (!(u.protocol === 'https:' || (u.protocol === 'http:' && loopback)) || u.username || u.password || u.search || u.hash)
    throw new AppError('bad_endpoint', 'Use HTTPS, or HTTP on loopback only; no credentials, query, or fragment in the URL.');
  if (!u.hostname || /[\s\\]/.test(raw)) throw new AppError('bad_endpoint');
  return u.href.replace(/\/+$/, '');
}
export function assertProvider(id) { if (!PROVIDERS.includes(id)) throw new AppError('unknown_provider'); return id; }
export function uniqueEfforts(values) { return ['default', ...new Set((values || []).filter(x => EFFORTS.includes(x) && x !== 'default'))]; }
