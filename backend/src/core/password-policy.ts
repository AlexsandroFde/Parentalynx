// Politica da senha administrativa (protocolo 1.2). O servidor e a autoridade.

import { ApiError } from './errors.ts';

export type PasswordReason = 'too_short' | 'too_long' | 'few_classes' | 'contains_identity' | 'common';

const MIN_LENGTH = 10;
const MAX_LENGTH = 128;
const MIN_IDENTITY_LENGTH = 4;

// Senhas longas o bastante para passar no tamanho e nas classes, mas previsiveis.
const COMMON_PASSWORDS = new Set(
  [
    'password123', 'password1234', 'password12345', 'password123!', 'password@123', 'p@ssw0rd123',
    'p@ssword123', 'passw0rd123', 'passw0rd!23', 'welcome123!', 'welcome@123', 'welcome12345',
    'qwerty12345', 'qwerty123456', 'qwerty@123', 'qwertyuiop', 'qwertyuiop1', 'qwertyuiop123',
    '1q2w3e4r5t', '1q2w3e4r5t6y', '1qaz2wsx3edc', 'zaq12wsxcde3', 'q1w2e3r4t5', 'q1w2e3r4t5y6',
    'abc123456789', 'abcd123456', 'abcd@12345', 'abcdef123456', 'abc@123456', 'a1b2c3d4e5',
    '1234567890', '12345678910', '123456789012', '0123456789', '9876543210', '0987654321',
    '1234567890a', 'a1234567890', '123456789a', '123456789@', '1234567890!', '1234567890@',
    '1122334455', '1111111111', '0000000000', '1212121212', '1231231234', '1234512345',
    'admin12345', 'admin@1234', 'admin@12345', 'administrator', 'administrador', 'admin123456',
    'senha12345', 'senha123456', 'senha@1234', 'senha@12345', 'senha1234!', 'minhasenha1',
    'minhasenha123', 'minhasenha@1', 'senhaforte1', 'senhaforte123', 'senha@forte1', 'mudar@12345',
    'mudar123456', 'trocar@1234', 'teste12345', 'teste@1234', 'teste@12345', 'teste123456',
    'brasil12345', 'brasil@1234', 'brasil@2024', 'brasil@2025', 'brasil@2026', 'brasil2026!',
    'flamengo123', 'flamengo@123', 'corinthians1', 'palmeiras123', 'saopaulo123', 'gremio12345',
    'iloveyou123', 'iloveyou1234', 'iloveyou@123', 'teamo12345', 'teamo@1234', 'euteamo1234',
    'familia1234', 'familia@123', 'familia12345', 'jesus@12345', 'jesuscristo1', 'deusefiel123',
    'letmein12345', 'letmein@123', 'changeme123', 'changeme@123', 'changeme1234', 'default12345',
    'monkey12345', 'dragon12345', 'master12345', 'superman123', 'batman12345', 'pokemon1234',
    'football123', 'baseball123', 'sunshine123', 'princess123', 'princesa123', 'princesa@123',
    'parental123', 'parental@123', 'parentalynx', 'parentalynx1', 'parentalynx@1', 'controle123',
    'controle@123', 'controleparental', 'controleparental1', 'responsavel1', 'responsavel123',
    'google12345', 'android12345', 'samsung1234', 'motorola123', 'xiaomi12345', 'iphone12345',
    'aaaaaaaaaa', 'aaaaaaaaaa1', 'aaaaaaaa1!', 'asdfghjkl1', 'asdfghjkl123', 'asdf123456',
    'zxcvbnm123', 'zxcvbnm1234', 'qazwsxedc1', 'qazwsx12345', 'qweasdzxc1', 'qweasdzxc123',
  ].map((entry) => entry.toLowerCase()),
);

function countClasses(password: string): number {
  let lower = false;
  let upper = false;
  let digit = false;
  let symbol = false;
  for (const char of password) {
    if (/\p{Ll}/u.test(char)) lower = true;
    else if (/\p{Lu}/u.test(char)) upper = true;
    else if (/\p{Nd}/u.test(char)) digit = true;
    else symbol = true;
  }
  return Number(lower) + Number(upper) + Number(digit) + Number(symbol);
}

/** Trechos de identidade que nao podem aparecer dentro da senha. */
function identityFragments(email: string, displayName: string): string[] {
  const fragments = new Set<string>();
  const local = email.split('@')[0]?.toLowerCase() ?? '';
  if (local.length >= MIN_IDENTITY_LENGTH) fragments.add(local);
  const name = displayName.toLowerCase().trim();
  const compact = name.replace(/\s+/g, '');
  if (compact.length >= MIN_IDENTITY_LENGTH) fragments.add(compact);
  for (const word of name.split(/\s+/)) {
    if (word.length >= MIN_IDENTITY_LENGTH) fragments.add(word);
  }
  return [...fragments];
}

export function checkPassword(password: string, email: string, displayName: string): PasswordReason[] {
  const reasons: PasswordReason[] = [];
  const length = Array.from(password).length;
  if (length < MIN_LENGTH) reasons.push('too_short');
  if (length > MAX_LENGTH) reasons.push('too_long');
  if (countClasses(password) < 3) reasons.push('few_classes');
  const lowered = password.toLowerCase();
  if (identityFragments(email, displayName).some((fragment) => lowered.includes(fragment))) {
    reasons.push('contains_identity');
  }
  if (COMMON_PASSWORDS.has(lowered)) reasons.push('common');
  return reasons;
}

const REASON_TEXT: Record<PasswordReason, string> = {
  too_short: `use pelo menos ${MIN_LENGTH} caracteres`,
  too_long: `use no máximo ${MAX_LENGTH} caracteres`,
  few_classes: 'combine pelo menos 3 tipos entre minúsculas, maiúsculas, números e símbolos',
  contains_identity: 'não use seu nome nem seu e-mail',
  common: 'escolha uma senha menos previsível',
};

/** Lanca `weak_password` se a senha nao atender a politica. */
export function assertStrongPassword(password: string, email: string, displayName: string): void {
  const reasons = checkPassword(password, email, displayName);
  if (reasons.length === 0) return;
  const text = reasons.map((reason) => REASON_TEXT[reason]).join('; ');
  throw new ApiError('weak_password', `Senha fraca: ${text}.`, { reasons });
}
