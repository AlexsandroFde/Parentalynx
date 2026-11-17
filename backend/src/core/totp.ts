// TOTP (RFC 6238) e Base32 (RFC 4648), usados no codigo de acesso offline do responsavel.
//
// O servidor so gera e guarda o segredo. Quem calcula o codigo e o app do responsavel e quem
// verifica e o aparelho da crianca. A implementacao fica aqui como referencia testada com os
// vetores da RFC e para o simulador de aparelho.

import { createHmac, randomBytes } from 'node:crypto';

const BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export function base32Encode(data: Uint8Array): string {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const byte of data) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += BASE32_ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
    // Mantem so os bits ainda nao emitidos, para o acumulador nao estourar 32 bits.
    value &= (1 << bits) - 1;
  }
  if (bits > 0) out += BASE32_ALPHABET[(value << (5 - bits)) & 31];
  return out;
}

export function base32Decode(text: string): Buffer {
  const clean = text.toUpperCase().replace(/=+$/, '').replace(/\s+/g, '');
  const bytes: number[] = [];
  let bits = 0;
  let value = 0;
  for (const char of clean) {
    const index = BASE32_ALPHABET.indexOf(char);
    if (index < 0) throw new Error('Base32 inválido.');
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 0xff);
      bits -= 8;
    }
    value &= (1 << bits) - 1;
  }
  return Buffer.from(bytes);
}

export type TotpAlgorithm = 'sha1' | 'sha256' | 'sha512';

export interface TotpOptions {
  /** Passo em segundos. Padrao do protocolo: 60. */
  stepSeconds?: number;
  /** Quantidade de digitos. Padrao do protocolo: 8. */
  digits?: number;
  /** Padrao do protocolo: sha256. */
  algorithm?: TotpAlgorithm;
}

const DEFAULTS: Required<TotpOptions> = { stepSeconds: 60, digits: 8, algorithm: 'sha256' };

/** Codigo HOTP (RFC 4226) para um contador. */
export function hotp(secret: Uint8Array, counter: number, options: TotpOptions = {}): string {
  const { digits, algorithm } = { ...DEFAULTS, ...options };
  const message = Buffer.alloc(8);
  message.writeBigUInt64BE(BigInt(counter));
  const digest = createHmac(algorithm, secret).update(message).digest();
  const offset = (digest[digest.length - 1] ?? 0) & 0x0f;
  const binary =
    (((digest[offset] ?? 0) & 0x7f) << 24) |
    ((digest[offset + 1] ?? 0) << 16) |
    ((digest[offset + 2] ?? 0) << 8) |
    (digest[offset + 3] ?? 0);
  return String(binary % 10 ** digits).padStart(digits, '0');
}

/** Codigo TOTP do instante informado (em milissegundos). */
export function totp(secret: Uint8Array, instantMs: number, options: TotpOptions = {}): string {
  const { stepSeconds } = { ...DEFAULTS, ...options };
  return hotp(secret, Math.floor(instantMs / 1000 / stepSeconds), options);
}

/** Aceita `window` passos para tras e para a frente (protocolo: 2). */
export function verifyTotp(
  secret: Uint8Array,
  code: string,
  instantMs: number,
  options: TotpOptions & { window?: number } = {},
): boolean {
  const { stepSeconds } = { ...DEFAULTS, ...options };
  const window = options.window ?? 2;
  const current = Math.floor(instantMs / 1000 / stepSeconds);
  const candidate = code.replace(/\s+/g, '');
  let matched = false;
  for (let offset = -window; offset <= window; offset += 1) {
    const counter = current + offset;
    if (counter < 0) continue;
    // Sem retorno antecipado, para o tempo nao depender de qual passo conferiu.
    if (hotp(secret, counter, options) === candidate) matched = true;
  }
  return matched;
}

/** Segredo offline: 20 bytes aleatorios em Base32 sem preenchimento. */
export function generateOfflineSecret(): string {
  return base32Encode(randomBytes(20));
}
