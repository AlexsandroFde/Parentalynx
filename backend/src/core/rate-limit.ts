// Limite de taxa por janela fixa, em memoria (protocolo 2.3).
//
// Serve a um unico processo. Com mais de uma instancia, cada uma teria a sua contagem.

import { errors } from './errors.ts';

export interface RateRule {
  limit: number;
  windowMs: number;
}

interface Bucket {
  count: number;
  resetAt: number;
}

export class RateLimiter {
  private readonly buckets = new Map<string, Bucket>();

  private bucket(key: string, windowMs: number, now: number): Bucket {
    let bucket = this.buckets.get(key);
    if (!bucket || bucket.resetAt <= now) {
      bucket = { count: 0, resetAt: now + windowMs };
      this.buckets.set(key, bucket);
    }
    return bucket;
  }

  /** Conta uma ocorrencia e lanca `rate_limited` se passou do limite. */
  consume(key: string, rule: RateRule, now: number): void {
    const bucket = this.bucket(key, rule.windowMs, now);
    bucket.count += 1;
    if (bucket.count > rule.limit) {
      throw errors.rateLimited(Math.max(1, Math.ceil((bucket.resetAt - now) / 1000)));
    }
  }

  /** Lanca `rate_limited` se o limite ja foi atingido, sem contar uma nova ocorrencia. */
  assertBelow(key: string, rule: RateRule, now: number): void {
    const bucket = this.buckets.get(key);
    if (bucket && bucket.resetAt > now && bucket.count >= rule.limit) {
      throw errors.rateLimited(Math.max(1, Math.ceil((bucket.resetAt - now) / 1000)));
    }
  }

  /** Conta uma ocorrencia sem lancar (usado para registrar falhas). */
  record(key: string, rule: RateRule, now: number): void {
    this.bucket(key, rule.windowMs, now).count += 1;
  }

  /** Remove janelas vencidas. Chamado periodicamente para a memoria nao crescer. */
  sweep(now: number): void {
    for (const [key, bucket] of this.buckets) {
      if (bucket.resetAt <= now) this.buckets.delete(key);
    }
  }

  get size(): number {
    return this.buckets.size;
  }
}
