// Codigo de vinculacao, chave de recuperacao e codigo de confirmacao (protocolo 2.4 e 3.3).

import { randomDigits, randomFromAlphabet } from './crypto.ts';

/** Alfabeto sem I, L, O e U, para evitar confusao na digitacao. */
export const CODE_ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

const PAIRING_LENGTH = 8;
const RECOVERY_LENGTH = 25;
const RECOVERY_GROUP = 5;

function normalizeSymbols(input: string): string {
  return input
    .toUpperCase()
    .replace(/[^0-9A-Z]/g, '')
    .replace(/O/g, '0')
    .replace(/[IL]/g, '1');
}

function isInAlphabet(text: string): boolean {
  for (const char of text) {
    if (!CODE_ALPHABET.includes(char)) return false;
  }
  return true;
}

/** Codigo de vinculacao: 8 caracteres, sem hifen. */
export function generatePairingCode(): string {
  return randomFromAlphabet(PAIRING_LENGTH, CODE_ALPHABET);
}

/** Normaliza o que o usuario digitou. Devolve `null` se nao for um codigo possivel. */
export function normalizePairingCode(input: string): string | null {
  const text = normalizeSymbols(input);
  if (text.length !== PAIRING_LENGTH || !isInAlphabet(text)) return null;
  return text;
}

/** Forma de exibicao `XXXX-XXXX`. */
export function formatPairingCode(code: string): string {
  return `${code.slice(0, 4)}-${code.slice(4)}`;
}

/** Chave de recuperacao no formato `RK-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX` (125 bits). */
export function generateRecoveryKey(): string {
  const body = randomFromAlphabet(RECOVERY_LENGTH, CODE_ALPHABET);
  const groups: string[] = [];
  for (let index = 0; index < RECOVERY_LENGTH; index += RECOVERY_GROUP) {
    groups.push(body.slice(index, index + RECOVERY_GROUP));
  }
  return `RK-${groups.join('-')}`;
}

/**
 * Normaliza a chave digitada para os 25 caracteres do corpo. Aceita com ou sem o prefixo `RK`,
 * com ou sem hifens e espacos, em qualquer caixa. Devolve `null` se nao for uma chave possivel.
 */
export function normalizeRecoveryKey(input: string): string | null {
  // O prefixo e retirado antes da troca de letras, porque `R` e `K` pertencem ao alfabeto.
  let text = input.toUpperCase().replace(/[^0-9A-Z]/g, '');
  if (text.length === RECOVERY_LENGTH + 2 && text.startsWith('RK')) text = text.slice(2);
  text = normalizeSymbols(text);
  if (text.length !== RECOVERY_LENGTH || !isInAlphabet(text)) return null;
  return text;
}

/** Codigo de confirmacao de 4 digitos mostrado nos dois aparelhos. */
export function generateConfirmCode(): string {
  return randomDigits(4);
}
