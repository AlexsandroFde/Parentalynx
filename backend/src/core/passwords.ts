// Derivacao e verificacao da senha administrativa com Argon2id (protocolo 1.2).
//
// O resultado e gravado no formato de texto PHC, que carrega os parametros. Assim os parametros
// podem ser reforcados depois: `needsRehash` indica quando regravar no proximo login.

import { argon2, randomBytes, timingSafeEqual } from 'node:crypto';

const MEMORY_KIB = 19_456;
const PASSES = 2;
const PARALLELISM = 1;
const SALT_BYTES = 16;
const TAG_BYTES = 32;

interface Argon2Options {
  memory: number;
  passes: number;
  parallelism: number;
}

function derive(password: string, salt: Buffer, options: Argon2Options, tagLength: number): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    argon2(
      'argon2id',
      {
        message: Buffer.from(password, 'utf8'),
        nonce: salt,
        parallelism: options.parallelism,
        tagLength,
        memory: options.memory,
        passes: options.passes,
      },
      (error, derived) => {
        if (error) reject(error);
        else resolve(Buffer.from(derived));
      },
    );
  });
}

function b64(buffer: Buffer): string {
  return buffer.toString('base64').replace(/=+$/, '');
}

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(SALT_BYTES);
  const tag = await derive(password, salt, { memory: MEMORY_KIB, passes: PASSES, parallelism: PARALLELISM }, TAG_BYTES);
  return `$argon2id$v=19$m=${MEMORY_KIB},t=${PASSES},p=${PARALLELISM}$${b64(salt)}$${b64(tag)}`;
}

interface ParsedHash {
  options: Argon2Options;
  salt: Buffer;
  tag: Buffer;
}

function parsePhc(phc: string): ParsedHash | null {
  const match = /^\$argon2id\$v=19\$m=(\d+),t=(\d+),p=(\d+)\$([A-Za-z0-9+/]+)\$([A-Za-z0-9+/]+)$/.exec(phc);
  if (!match) return null;
  const [, memory, passes, parallelism, salt, tag] = match;
  if (!memory || !passes || !parallelism || !salt || !tag) return null;
  return {
    options: { memory: Number(memory), passes: Number(passes), parallelism: Number(parallelism) },
    salt: Buffer.from(salt, 'base64'),
    tag: Buffer.from(tag, 'base64'),
  };
}

export async function verifyPassword(password: string, phc: string): Promise<boolean> {
  const parsed = parsePhc(phc);
  if (!parsed) return false;
  const candidate = await derive(password, parsed.salt, parsed.options, parsed.tag.length);
  return candidate.length === parsed.tag.length && timingSafeEqual(candidate, parsed.tag);
}

/** Verdadeiro quando o hash foi gerado com parametros mais fracos que os atuais. */
export function needsRehash(phc: string): boolean {
  const parsed = parsePhc(phc);
  if (!parsed) return true;
  return (
    parsed.options.memory < MEMORY_KIB ||
    parsed.options.passes < PASSES ||
    parsed.tag.length < TAG_BYTES
  );
}

let dummyHash: Promise<string> | null = null;

/**
 * Gasta o mesmo tempo de uma verificacao real quando a conta nao existe, para que o tempo de
 * resposta nao revele se um e-mail esta cadastrado.
 */
export async function burnPasswordTime(password: string): Promise<void> {
  dummyHash ??= hashPassword('senha-inexistente-apenas-para-tempo-constante');
  await verifyPassword(password, await dummyHash);
}
