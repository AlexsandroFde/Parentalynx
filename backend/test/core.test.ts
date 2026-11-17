// Testes das primitivas: TOTP, Base32, calendario, codigos, senha, cifra e limite de taxa.

import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { describe, test } from 'node:test';

import {
  CODE_ALPHABET,
  formatPairingCode,
  generateConfirmCode,
  generatePairingCode,
  generateRecoveryKey,
  normalizePairingCode,
  normalizeRecoveryKey,
} from '../src/core/codes.ts';
import { FieldCipher, newToken, sha256Hex } from '../src/core/crypto.ts';
import { ApiError } from '../src/core/errors.ts';
import { formatElapsed, formatMinutes } from '../src/core/format.ts';
import { checkPassword } from '../src/core/password-policy.ts';
import { hashPassword, needsRehash, verifyPassword } from '../src/core/passwords.ts';
import { RateLimiter } from '../src/core/rate-limit.ts';
import {
  addDays,
  dayRange,
  diffDays,
  isDay,
  isHourMinute,
  isoWeekday,
  isValidTimeZone,
  localParts,
  quotaDayOf,
} from '../src/core/time.ts';
import { base32Decode, base32Encode, generateOfflineSecret, totp, verifyTotp } from '../src/core/totp.ts';
import { parse, v } from '../src/core/validate.ts';

describe('TOTP (RFC 6238)', () => {
  const seeds = {
    sha1: Buffer.from('12345678901234567890', 'ascii'),
    sha256: Buffer.from('12345678901234567890123456789012', 'ascii'),
    sha512: Buffer.from('1234567890123456789012345678901234567890123456789012345678901234', 'ascii'),
  } as const;

  // Apendice B da RFC 6238: 8 digitos, passo de 30 segundos.
  const vectors: [number, string, string, string][] = [
    [59, '94287082', '46119246', '90693936'],
    [1111111109, '07081804', '68084774', '25091201'],
    [1111111111, '14050471', '67062674', '99943326'],
    [1234567890, '89005924', '91819424', '93441116'],
    [2000000000, '69279037', '90698825', '38618901'],
    [20000000000, '65353130', '77737706', '47863826'],
  ];

  for (const [seconds, sha1, sha256, sha512] of vectors) {
    test(`vetores da RFC em T=${seconds}`, () => {
      const options = { stepSeconds: 30, digits: 8 } as const;
      assert.equal(totp(seeds.sha1, seconds * 1000, { ...options, algorithm: 'sha1' }), sha1);
      assert.equal(totp(seeds.sha256, seconds * 1000, { ...options, algorithm: 'sha256' }), sha256);
      assert.equal(totp(seeds.sha512, seconds * 1000, { ...options, algorithm: 'sha512' }), sha512);
    });
  }

  test('padrao do protocolo: SHA-256, 8 digitos, passo de 60 s, janela de 2 passos', () => {
    const secret = base32Decode(generateOfflineSecret());
    assert.equal(secret.length, 20);
    const at = Date.UTC(2026, 10, 17, 15, 0, 30);
    const code = totp(secret, at);
    assert.match(code, /^\d{8}$/);
    // O mesmo passo de 60 segundos produz o mesmo codigo.
    assert.equal(totp(secret, at + 20_000), code);
    for (const offset of [-2, -1, 0, 1, 2]) {
      assert.equal(verifyTotp(secret, code, at + offset * 60_000), true, `passo ${offset}`);
    }
    assert.equal(verifyTotp(secret, code, at + 3 * 60_000), false);
    assert.equal(verifyTotp(secret, code, at - 3 * 60_000), false);
    assert.equal(verifyTotp(secret, '00000000', at) && code !== '00000000', false);
  });

  test('Base32 confere com os vetores da RFC 4648', () => {
    const cases: [string, string][] = [
      ['', ''],
      ['f', 'MY'],
      ['fo', 'MZXQ'],
      ['foo', 'MZXW6'],
      ['foob', 'MZXW6YQ'],
      ['fooba', 'MZXW6YTB'],
      ['foobar', 'MZXW6YTBOI'],
    ];
    for (const [plain, encoded] of cases) {
      assert.equal(base32Encode(Buffer.from(plain, 'ascii')), encoded);
      assert.equal(base32Decode(encoded).toString('ascii'), plain);
    }
    const random = randomBytes(64);
    assert.deepEqual(base32Decode(base32Encode(random)), random);
    assert.throws(() => base32Decode('MZX!'));
  });
});

describe('calendario', () => {
  test('converte instantes para a data local do fuso', () => {
    const noonUtc = Date.UTC(2026, 10, 17, 15, 0);
    assert.deepEqual(localParts(noonUtc, 'America/Fortaleza'), { date: '2026-11-17', minuteOfDay: 12 * 60 });
    assert.deepEqual(localParts(noonUtc, 'Asia/Tokyo'), { date: '2026-11-18', minuteOfDay: 0 });
    assert.deepEqual(localParts(Date.UTC(2026, 10, 17, 2, 59), 'America/Fortaleza'), {
      date: '2026-11-16',
      minuteOfDay: 23 * 60 + 59,
    });
  });

  test('dia da cota respeita o horario de reinicio', () => {
    const tz = 'America/Fortaleza';
    // 02:00 locais do dia 18 (05:00 UTC).
    const earlyMorning = Date.UTC(2026, 10, 18, 5, 0);
    assert.equal(quotaDayOf(earlyMorning, tz, '00:00'), '2026-11-18');
    assert.equal(quotaDayOf(earlyMorning, tz, '04:00'), '2026-11-17');
    // Exatamente no reinicio ja e o novo dia.
    assert.equal(quotaDayOf(Date.UTC(2026, 10, 18, 7, 0), tz, '04:00'), '2026-11-18');
    assert.equal(quotaDayOf(Date.UTC(2026, 10, 18, 6, 59), tz, '04:00'), '2026-11-17');
  });

  test('aritmetica de dias', () => {
    assert.equal(addDays('2026-12-31', 1), '2027-01-01');
    assert.equal(addDays('2028-03-01', -1), '2028-02-29');
    assert.equal(diffDays('2026-11-11', '2026-11-17'), 6);
    assert.deepEqual(dayRange('2026-11-29', '2026-12-02'), ['2026-11-29', '2026-11-30', '2026-12-01', '2026-12-02']);
    assert.equal(isoWeekday('2026-11-17'), 2);
    assert.equal(isoWeekday('2026-11-22'), 7);
    assert.equal(isoWeekday('2026-11-16'), 1);
  });

  test('valida datas, horarios e fusos', () => {
    assert.equal(isDay('2026-11-17'), true);
    assert.equal(isDay('2026-02-30'), false);
    assert.equal(isDay('2026-13-01'), false);
    assert.equal(isDay('17/11/2026'), false);
    assert.equal(isDay(20261117), false);
    assert.equal(isHourMinute('00:00'), true);
    assert.equal(isHourMinute('23:59'), true);
    assert.equal(isHourMinute('24:00'), false);
    assert.equal(isHourMinute('24:00', true), true);
    assert.equal(isHourMinute('7:00'), false);
    assert.equal(isHourMinute('12:60'), false);
    assert.equal(isValidTimeZone('America/Fortaleza'), true);
    assert.equal(isValidTimeZone('Marte/Olimpo'), false);
    assert.equal(isValidTimeZone(''), false);
  });

  test('formata duracoes em portugues', () => {
    assert.equal(formatMinutes(150), '2h30');
    assert.equal(formatMinutes(120), '2h');
    assert.equal(formatMinutes(45), '45 min');
    assert.equal(formatMinutes(65), '1h05');
    assert.equal(formatElapsed(40 * 60_000), '40 minutos');
    assert.equal(formatElapsed(3 * 3_600_000), '3 horas');
    assert.equal(formatElapsed(72 * 3_600_000), '3 dias');
  });
});

describe('codigos', () => {
  test('codigo de vinculacao usa o alfabeto sem letras ambiguas', () => {
    for (let index = 0; index < 200; index += 1) {
      const code = generatePairingCode();
      assert.equal(code.length, 8);
      for (const char of code) assert.ok(CODE_ALPHABET.includes(char), `caractere ${char}`);
      assert.equal(normalizePairingCode(code), code);
    }
    assert.equal(CODE_ALPHABET.length, 32);
    assert.ok(!/[ILOU]/.test(CODE_ALPHABET));
  });

  test('normaliza o codigo digitado', () => {
    assert.equal(normalizePairingCode('ab12-cd34'), 'AB12CD34');
    assert.equal(normalizePairingCode(' AB12 CD34 '), 'AB12CD34');
    // O vira 0, I e L viram 1.
    assert.equal(normalizePairingCode('OIL0-AB12'), '0110AB12');
    assert.equal(formatPairingCode('AB12CD34'), 'AB12-CD34');
    assert.equal(normalizePairingCode('AB12-CD3'), null);
    assert.equal(normalizePairingCode('AB12-CD345'), null);
    // U nao pertence ao alfabeto.
    assert.equal(normalizePairingCode('UUUU-UUUU'), null);
    assert.equal(normalizePairingCode(''), null);
  });

  test('chave de recuperacao tem 125 bits e aceita variacoes de digitacao', () => {
    const key = generateRecoveryKey();
    assert.match(key, /^RK(-[0-9A-HJKMNP-TV-Z]{5}){5}$/);
    const body = normalizeRecoveryKey(key);
    assert.ok(body);
    assert.equal(body.length, 25);
    assert.equal(normalizeRecoveryKey(key.toLowerCase()), body);
    assert.equal(normalizeRecoveryKey(key.replace(/-/g, ' ')), body);
    assert.equal(normalizeRecoveryKey(key.slice(3)), body);
    assert.equal(normalizeRecoveryKey(`${key}X`), null);
    assert.equal(normalizeRecoveryKey('RK-AAAAA'), null);
    assert.notEqual(generateRecoveryKey(), key);
  });

  test('codigo de confirmacao tem 4 digitos', () => {
    for (let index = 0; index < 50; index += 1) assert.match(generateConfirmCode(), /^\d{4}$/);
  });

  test('tokens tem prefixo, 256 bits e hash estavel', () => {
    const token = newToken('gs_');
    assert.match(token, /^gs_[A-Za-z0-9_-]{43}$/);
    assert.notEqual(newToken('gs_'), token);
    assert.equal(sha256Hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });
});

describe('senha administrativa', () => {
  test('politica: tamanho, classes, identidade e senhas comuns', () => {
    const check = (password: string) => checkPassword(password, 'maria.silva@exemplo.com', 'Maria Silva');
    assert.deepEqual(check('Girassol#Azul27'), []);
    assert.deepEqual(check('Abc#1'), ['too_short']);
    assert.deepEqual(check('somenteminusculas'), ['few_classes']);
    assert.deepEqual(check('minusculas12345'), ['few_classes']);
    assert.deepEqual(check(`A1#${'x'.repeat(130)}`), ['too_long']);
    // Trecho local do e-mail, nome inteiro e cada palavra do nome.
    assert.deepEqual(check('Xmaria.silva#99'), ['contains_identity']);
    assert.deepEqual(check('MariaSilva#2026'), ['contains_identity']);
    assert.deepEqual(check('Casa#SILVA#2026'), ['contains_identity']);
    assert.deepEqual(check('Password123!'), ['common']);
    assert.deepEqual(check('abc'), ['too_short', 'few_classes']);
    // Identidade curta (menos de 4 caracteres) nao e considerada.
    assert.deepEqual(checkPassword('Ana#Girassol27', 'ana@exemplo.com', 'Ana'), []);
  });

  test('Argon2id no formato PHC', async () => {
    const hash = await hashPassword('Girassol#Azul27');
    assert.match(hash, /^\$argon2id\$v=19\$m=19456,t=2,p=1\$[A-Za-z0-9+/]{22}\$[A-Za-z0-9+/]{43}$/);
    assert.ok(!hash.includes('Girassol'));
    assert.equal(await verifyPassword('Girassol#Azul27', hash), true);
    assert.equal(await verifyPassword('Girassol#Azul28', hash), false);
    assert.equal(await verifyPassword('Girassol#Azul27', 'texto-qualquer'), false);
    assert.notEqual(await hashPassword('Girassol#Azul27'), hash, 'o sal muda a cada derivacao');
    assert.equal(needsRehash(hash), false);
    assert.equal(needsRehash(hash.replace('m=19456', 'm=8192')), true);
  });
});

describe('cifra de campos', () => {
  test('cifra, decifra e nao repete o texto cifrado', () => {
    const cipher = new FieldCipher(randomBytes(32));
    const stored = cipher.encrypt('https://exemplo.com/segredo', 'browsing.url');
    assert.ok(stored.startsWith('enc:v1:'));
    assert.ok(!stored.includes('exemplo'));
    assert.equal(cipher.decrypt(stored, 'browsing.url'), 'https://exemplo.com/segredo');
    assert.notEqual(cipher.encrypt('https://exemplo.com/segredo', 'browsing.url'), stored);
    assert.equal(cipher.encryptNullable(null, 'x'), null);
    assert.equal(cipher.decryptNullable(null, 'x'), null);
  });

  test('recusa contexto trocado, adulteracao e chave errada', () => {
    const cipher = new FieldCipher(randomBytes(32));
    const stored = cipher.encrypt('conteudo', 'events.data');
    assert.throws(() => cipher.decrypt(stored, 'browsing.url'));
    const tampered = `${stored.slice(0, -4)}${stored.slice(-4) === 'AAAA' ? 'BBBB' : 'AAAA'}`;
    assert.throws(() => cipher.decrypt(tampered, 'events.data'));
    assert.throws(() => new FieldCipher(randomBytes(32)).decrypt(stored, 'events.data'));
    assert.throws(() => cipher.decrypt('texto puro', 'events.data'));
    assert.throws(() => new FieldCipher(randomBytes(16)));
  });
});

describe('limite de taxa', () => {
  test('janela fixa por chave', () => {
    const limiter = new RateLimiter();
    const rule = { limit: 3, windowMs: 60_000 };
    limiter.consume('a', rule, 0);
    limiter.consume('a', rule, 1_000);
    limiter.consume('a', rule, 2_000);
    assert.throws(
      () => limiter.consume('a', rule, 3_000),
      (error: unknown) => error instanceof ApiError && error.code === 'rate_limited' && error.details.retryAfterSec === 57,
    );
    // Outra chave tem contagem propria, e a janela reinicia depois do prazo.
    limiter.consume('b', rule, 3_000);
    limiter.consume('a', rule, 60_000);
  });

  test('registra falhas sem lancar e limpa janelas vencidas', () => {
    const limiter = new RateLimiter();
    const rule = { limit: 2, windowMs: 1_000 };
    limiter.assertBelow('k', rule, 0);
    limiter.record('k', rule, 0);
    limiter.assertBelow('k', rule, 10);
    limiter.record('k', rule, 10);
    assert.throws(() => limiter.assertBelow('k', rule, 20));
    limiter.assertBelow('k', rule, 1_001);
    assert.equal(limiter.size, 1);
    limiter.sweep(5_000);
    assert.equal(limiter.size, 0);
  });
});

describe('validacao', () => {
  test('relata todos os campos com problema no formato do protocolo', () => {
    const parser = v.object({
      name: v.string({ min: 1, max: 5 }),
      age: v.int({ min: 0, max: 150 }),
      tags: v.array(v.string({ min: 1 }), { max: 2 }),
      nested: v.object({ flag: v.bool() }),
      kind: v.oneOf(['a', 'b'] as const),
      note: v.optional(v.string()),
      limit: v.nullable(v.int()),
    });
    assert.deepEqual(parse(parser, { name: ' ana ', age: 9, tags: ['x'], nested: { flag: true }, kind: 'b' }), {
      name: 'ana',
      age: 9,
      tags: ['x'],
      nested: { flag: true },
      kind: 'b',
      note: undefined,
      limit: null,
    });
    assert.throws(
      () => parse(parser, { name: '', age: 1.5, tags: ['', 'b', 'c'], nested: {}, kind: 'z' }),
      (error: unknown) => {
        assert.ok(error instanceof ApiError);
        assert.equal(error.code, 'validation_error');
        assert.equal(error.status, 400);
        assert.deepEqual(error.details.fields, ['name', 'age', 'tags', 'nested.flag', 'kind']);
        return true;
      },
    );
    assert.throws(() => parse(parser, 'texto'), (error: unknown) => error instanceof ApiError);
  });
});
