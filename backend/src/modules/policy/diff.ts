// Resumo em portugues das diferencas entre duas versoes da politica, para a auditoria.

import { formatMinutes, plural } from '../../core/format.ts';
import type { AppRule, BlockPeriod, Policy } from './schema.ts';

function same(left: unknown, right: unknown): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

function describeRule(rule: AppRule | undefined): string {
  if (!rule) return 'padrão';
  if (rule.state === 'blocked') return 'bloqueado';
  const limit = rule.dailyLimitMinutes === null ? '' : `, limite de ${formatMinutes(rule.dailyLimitMinutes)}`;
  if (rule.state === 'exception') {
    return `exceção${rule.countsTowardLimit ? ' que conta no limite' : ''}${limit}`;
  }
  return `permitido${limit}`;
}

function describePeriod(period: BlockPeriod): string {
  return period.label === '' ? 'sem nome' : period.label;
}

/**
 * Lista as mudancas relevantes. `labelOf` traduz o nome do pacote para o nome do app, quando o
 * inventario do aparelho o conhece.
 */
export function summarizePolicyChange(
  previous: Policy,
  next: Policy,
  labelOf: (packageName: string) => string = (packageName) => packageName,
): string {
  const changes: string[] = [];

  if (previous.timezone !== next.timezone) changes.push(`Fuso horário alterado para ${next.timezone}`);

  const before = previous.dailyLimit;
  const after = next.dailyLimit;
  if (before.enabled !== after.enabled) {
    changes.push(after.enabled ? `Limite diário ativado (${formatMinutes(after.minutes)})` : 'Limite diário desativado');
  } else if (before.minutes !== after.minutes) {
    changes.push(`Limite diário alterado de ${formatMinutes(before.minutes)} para ${formatMinutes(after.minutes)}`);
  }
  if (!same(before.perWeekday, after.perWeekday)) changes.push('Limites por dia da semana alterados');
  if (before.resetTime !== after.resetTime) {
    changes.push(`Horário de reinício da cota alterado de ${before.resetTime} para ${after.resetTime}`);
  }
  if (!same(before.warnAtMinutes, after.warnAtMinutes)) changes.push('Avisos de pouco tempo alterados');

  if (previous.allowedHours.enabled !== next.allowedHours.enabled) {
    changes.push(next.allowedHours.enabled ? 'Horários permitidos ativados' : 'Horários permitidos desativados');
  } else if (!same(previous.allowedHours.windows, next.allowedHours.windows)) {
    changes.push('Horários permitidos alterados');
  }

  const previousPeriods = new Map(previous.blockPeriods.map((period) => [period.id, period]));
  const nextPeriods = new Map(next.blockPeriods.map((period) => [period.id, period]));
  for (const period of next.blockPeriods) {
    const old = previousPeriods.get(period.id);
    if (!old) changes.push(`Período de bloqueio criado: ${describePeriod(period)}`);
    else if (!same(old, period)) changes.push(`Período de bloqueio alterado: ${describePeriod(period)}`);
  }
  for (const period of previous.blockPeriods) {
    if (!nextPeriods.has(period.id)) changes.push(`Período de bloqueio removido: ${describePeriod(period)}`);
  }

  if (previous.apps.defaultForNewApps !== next.apps.defaultForNewApps) {
    changes.push(
      next.apps.defaultForNewApps === 'blocked'
        ? 'Apps novos passam a ficar bloqueados até aprovação'
        : 'Apps novos passam a ficar liberados',
    );
  }
  const packages = new Set([...Object.keys(previous.apps.rules), ...Object.keys(next.apps.rules)]);
  const ruleChanges: string[] = [];
  for (const packageName of [...packages].sort()) {
    const old = previous.apps.rules[packageName];
    const current = next.apps.rules[packageName];
    if (same(old, current)) continue;
    ruleChanges.push(`${labelOf(packageName)}: ${describeRule(old)} para ${describeRule(current)}`);
  }
  if (ruleChanges.length > 0 && ruleChanges.length <= 4) {
    changes.push(...ruleChanges.map((change) => `App ${change}`));
  } else if (ruleChanges.length > 4) {
    changes.push(`Regras de ${plural(ruleChanges.length, 'app alterada', 'apps alteradas')}`);
  }

  if (!same(previous.web, next.web)) {
    const parts: string[] = [];
    if (previous.web.managedBrowser !== next.web.managedBrowser) {
      parts.push(next.web.managedBrowser ? 'navegador gerenciado ligado' : 'navegador gerenciado desligado');
    }
    if (previous.web.mode !== next.web.mode) {
      parts.push(next.web.mode === 'allowlist' ? 'somente sites autorizados' : 'lista de sites proibidos');
    }
    if (!same(previous.web.blockedDomains, next.web.blockedDomains)) parts.push('sites proibidos');
    if (!same(previous.web.allowedDomains, next.web.allowedDomains)) parts.push('sites autorizados');
    if (!same(previous.web.blockedCategories, next.web.blockedCategories)) parts.push('categorias');
    if (previous.web.safeDns !== next.web.safeDns) parts.push(next.web.safeDns ? 'DNS filtrado ligado' : 'DNS filtrado desligado');
    if (previous.web.safeSearch !== next.web.safeSearch) {
      parts.push(next.web.safeSearch ? 'busca segura ligada' : 'busca segura desligada');
    }
    if (previous.web.logHistory !== next.web.logHistory) {
      parts.push(next.web.logHistory ? 'histórico ligado' : 'histórico desligado');
    }
    changes.push(`Filtro de navegação alterado (${parts.join(', ')})`);
  }

  if (!same(previous.protection, next.protection)) changes.push('Opções de proteção alteradas');

  return changes.length === 0 ? 'Sem alterações' : changes.join('; ');
}

/** Verdadeiro quando as partes editaveis (tudo menos `overrides`) sao iguais. */
export function sameEditablePolicy(left: Policy, right: Policy): boolean {
  return same({ ...left, overrides: null }, { ...right, overrides: null });
}
