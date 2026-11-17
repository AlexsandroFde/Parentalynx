// Primitivas criptograficas: tokens opacos, hashes e cifra de campos em repouso.

import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
  randomInt,
  timingSafeEqual,
} from 'node:crypto';

export type TokenPrefix = 'gs_' | 'dv_' | 'pp_';

export function sha256Hex(input: string | Uint8Array): string {
  return createHash('sha256').update(input).digest('hex');
}

/** Token opaco de 256 bits com o prefixo do tipo. O servidor guarda apenas o SHA-256. */
export function newToken(prefix: TokenPrefix): string {
  return prefix + randomBytes(32).toString('base64url');
}

/** Compara dois textos em tempo constante. */
export function safeEqual(a: string, b: string): boolean {
  const left = Buffer.from(a, 'utf8');
  const right = Buffer.from(b, 'utf8');
  if (left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}

/** Sorteia `length` caracteres de um alfabeto cujo tamanho divide 256 (sem vies). */
export function randomFromAlphabet(length: number, alphabet: string): string {
  if (256 % alphabet.length !== 0) {
    throw new Error('O tamanho do alfabeto precisa dividir 256.');
  }
  const bytes = randomBytes(length);
  let out = '';
  for (const byte of bytes) out += alphabet[byte % alphabet.length];
  return out;
}

export function randomDigits(length: number): string {
  let out = '';
  for (let index = 0; index < length; index += 1) out += String(randomInt(0, 10));
  return out;
}

const CIPHER_PREFIX = 'enc:v1:';

/**
 * Cifra de campos sensiveis em repouso com AES-256-GCM.
 *
 * Formato gravado: `enc:v1:` + base64(iv de 12 bytes + etiqueta de 16 bytes + texto cifrado).
 * O `context` (por exemplo `browsing.url`) entra como dado autenticado, entao um valor cifrado
 * nao pode ser movido para outra coluna sem que a decifragem falhe.
 */
export class FieldCipher {
  private readonly key: Buffer;

  constructor(key: Buffer) {
    if (key.length !== 32) throw new Error('A chave de cifra precisa ter 32 bytes.');
    this.key = key;
  }

  encrypt(plain: string, context: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    cipher.setAAD(Buffer.from(context, 'utf8'));
    const body = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag();
    return CIPHER_PREFIX + Buffer.concat([iv, tag, body]).toString('base64');
  }

  decrypt(stored: string, context: string): string {
    if (!stored.startsWith(CIPHER_PREFIX)) throw new Error('Valor cifrado em formato desconhecido.');
    const raw = Buffer.from(stored.slice(CIPHER_PREFIX.length), 'base64');
    if (raw.length < 28) throw new Error('Valor cifrado truncado.');
    const iv = raw.subarray(0, 12);
    const tag = raw.subarray(12, 28);
    const body = raw.subarray(28);
    const decipher = createDecipheriv('aes-256-gcm', this.key, iv);
    decipher.setAAD(Buffer.from(context, 'utf8'));
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(body), decipher.final()]).toString('utf8');
  }

  encryptNullable(plain: string | null, context: string): string | null {
    return plain === null ? null : this.encrypt(plain, context);
  }

  decryptNullable(stored: string | null, context: string): string | null {
    return stored === null ? null : this.decrypt(stored, context);
  }
}
