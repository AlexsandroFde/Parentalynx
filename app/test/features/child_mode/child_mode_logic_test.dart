import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/core/platform/native_api.g.dart' hide AgentStatus;
import 'package:parentalynx/features/child_mode/data/mappers/agent_status_mapper.dart';
import 'package:parentalynx/features/child_mode/domain/entities/admin_auth.dart';
import 'package:parentalynx/features/child_mode/domain/entities/agent_status.dart';
import 'package:parentalynx/features/child_mode/domain/entities/permission_plan.dart';
import 'package:parentalynx/features/child_mode/domain/entities/permission_step.dart';
import 'package:parentalynx/features/child_mode/domain/services/offline_access_code_rules.dart';
import 'package:parentalynx/features/child_mode/domain/services/permission_steps.dart';
import 'package:parentalynx/features/child_mode/presentation/texts/admin_auth_texts.dart';
import 'package:parentalynx/features/child_mode/presentation/texts/home_texts.dart';
import 'package:parentalynx/features/device_policy/data/dto/policy_dto.dart';
import 'package:parentalynx/features/device_policy/data/mappers/policy_mapper.dart';
import 'package:parentalynx/features/device_policy/domain/entities/policy.dart';
import 'package:parentalynx/features/device_sync/domain/entities/device_sync_result.dart';

import 'support/child_fakes.dart';

void main() {
  group('tela inicial: bloqueio', () {
    test('liberado nao tem mensagem de bloqueio', () {
      expect(lockMessage(agentStatus(fakeStatus())), isNull);
    });

    test('limite diario informa quando o tempo volta', () {
      final AgentStatus status = agentStatus(
        fakeStatus(
          lockState: LockState.dailyLimit,
          quotaUsedMs: 9000000,
          releaseAtMs: msAt(0, 0, dayOffset: 1),
        ),
      );
      final LockMessage message = lockMessage(status)!;
      expect(message.title, 'Seu tempo de hoje acabou');
      expect(message.body, contains('amanhã às 00:00'));
    });

    test('bloqueio por horario usa o nome do periodo', () {
      final AgentStatus status = agentStatus(
        fakeStatus(
          lockState: LockState.schedule,
          activeScheduleLabel: 'Hora de dormir',
          releaseAtMs: msAt(7, 0, dayOffset: 1),
        ),
      );
      final LockMessage message = lockMessage(status)!;
      expect(message.title, 'Hora de dormir');
      expect(message.body, contains('amanhã às 07:00'));
    });

    test('pausa manual sem prazo orienta a falar com o responsavel', () {
      final AgentStatus status = agentStatus(fakeStatus(lockState: LockState.manualLock));
      final LockMessage message = lockMessage(status)!;
      expect(message.title, 'Aparelho em pausa');
      expect(message.body, contains('fale com Maria'));
    });

    test('permissao desligada orienta a ligar de novo, sem culpa', () {
      final AgentStatus status = agentStatus(fakeStatus(lockState: LockState.tamperLock));
      final LockMessage message = lockMessage(status)!;
      expect(message.title, 'O controle precisa de atenção');
      expect(message.body, contains('Ligue de novo'));
    });

    test('liberacao local do responsavel tem prioridade sobre o bloqueio', () {
      final AgentStatus status = agentStatus(
        fakeStatus(lockState: LockState.dailyLimit, localOverrideUntilMs: msAt(16, 0)),
      );
      expect(status.isLocked, isFalse);
      expect(lockMessage(status), isNull);
      final ReliefMessage relief = reliefMessage(status)!;
      expect(relief.title, 'Uso liberado até 16:00');
      expect(relief.body, 'Maria liberou o aparelho por um tempo.');
    });
  });

  group('tela inicial: tempo e avisos', () {
    test('tempo restante, nivel do anel e a frase do leitor de tela', () {
      final TimeDisplay plenty = timeDisplay(agentStatus(fakeStatus()));
      expect(plenty.headline, '1h 20min');
      expect(plenty.detail, 'Você usou 1h 10min de 2h 30min.');
      expect(plenty.spoken, 'Restam 1 hora e 20 minutos para usar hoje, de 2 horas e 30 minutos.');
      expect(plenty.level, TimeLevel.plenty);

      final TimeDisplay low = timeDisplay(agentStatus(fakeStatus(quotaUsedMs: 8400000)));
      expect(low.headline, '10min');
      expect(low.level, TimeLevel.low);

      final TimeDisplay over = timeDisplay(agentStatus(fakeStatus(quotaUsedMs: 9000000)));
      expect(over.headline, '0min');
      expect(over.spoken, 'O tempo de hoje acabou.');
      expect(over.level, TimeLevel.over);
      expect(over.progress, 1);
    });

    test('os minutos restantes arredondam para cima: o tempo so zera quando acaba', () {
      final TimeDisplay seconds = timeDisplay(
        agentStatus(fakeStatus(quotaUsedMs: 9000000 - 30000)),
      );
      expect(seconds.headline, '1min');
      expect(spokenMinutes(61), '1 hora e 1 minuto');
      expect(spokenMinutes(120), '2 horas');
    });

    test('sem limite mostra o uso total', () {
      final TimeDisplay display = timeDisplay(agentStatus(fakeStatus(limitEnabled: false)));
      expect(display.headline, 'Sem limite');
      expect(display.level, TimeLevel.unlimited);
    });

    test('tempo extra aparece no detalhe', () {
      final TimeDisplay display = timeDisplay(
        agentStatus(fakeStatus(limitMs: 10800000, extraMs: 1800000)),
      );
      expect(display.detail, contains('(com 30min extras)'));
    });

    test('suspensao de regras e descrita com os escopos', () {
      final AgentStatus status = agentStatus(
        fakeStatus(
          suspensionUntilMs: msAt(18, 0),
          suspensionScopes: <String>['dailyLimit', 'schedules'],
        ),
      );
      final ReliefMessage relief = reliefMessage(status)!;
      expect(relief.title, 'Regras liberadas até 18:00');
      expect(relief.body, 'Maria liberou o limite de tempo e os horários de pausa.');
    });

    test('escopo de suspensao desconhecido e ignorado', () {
      final AgentStatus status = agentStatus(
        fakeStatus(suspensionUntilMs: msAt(18, 0), suspensionScopes: <String>['appBlocks', 'x']),
      );
      expect(status.suspensionScopes, <SuspensionScope>[SuspensionScope.appBlocks]);
    });

    test('problemas viram aviso em linguagem simples', () {
      expect(attentionMessage(agentStatus(fakeStatus())), isNull);
      final String message = attentionMessage(
        agentStatus(
          fakeStatus(
            issues: <String>['accessibility_disabled', 'battery_optimized'],
            clockTrusted: false,
          ),
        ),
      )!;
      expect(message, startsWith('A acessibilidade do controle está desligada.'));
      expect(message, contains('E mais 2 avisos'));
    });

    test('so problemas de permissao levam a tela de permissoes', () {
      expect(
        attentionNeedsPermissions(
          agentStatus(fakeStatus(issues: <String>['accessibility_disabled'])),
        ),
        isTrue,
      );
      expect(attentionNeedsPermissions(agentStatus(fakeStatus(clockTrusted: false))), isFalse);
    });

    test('proxima pausa so aparece com o aparelho liberado', () {
      final AgentStatus status = agentStatus(
        fakeStatus(nextBlockAtMs: msAt(21, 0), nextBlockLabel: 'Hora de dormir'),
      );
      expect(nextPauseText(status), 'Hora de dormir começa às 21:00.');
      expect(
        nextPauseText(
          agentStatus(fakeStatus(lockState: LockState.manualLock, nextBlockAtMs: msAt(21, 0))),
        ),
        isNull,
      );
    });

    test('estado das regras entre o aparelho e o responsavel', () {
      final ConnectionText ok = connectionText(agentStatus(fakeStatus()));
      expect(ok.ok, isTrue);
      expect(ok.title, 'Regras em dia');
      expect(ok.detail, 'Atualizadas há 2 min.');
      final ConnectionText offline = connectionText(agentStatus(fakeStatus(lastSyncOk: false)));
      expect(offline.ok, isFalse);
      expect(offline.detail, contains('As regras continuam valendo'));
    });

    test('resultado de atualizar agora', () {
      expect(
        syncResultMessage(const DeviceSyncResult(ok: true, atMs: 1)),
        'Pronto: as regras estão em dia.',
      );
      expect(
        syncResultMessage(const DeviceSyncResult(ok: false, atMs: 1, errorCode: 'network')),
        contains('Sem internet'),
      );
      expect(
        syncResultMessage(const DeviceSyncResult(ok: false, atMs: 1, errorCode: 'device_revoked')),
        contains('removido pelo responsável'),
      );
    });

    test('resumo das regras do dia', () {
      final Policy policy = PolicyMapper.policy(
        PolicyDto.fromJson(decodeJsonObject(fakePolicyJson)),
      );
      final List<String> lines = ruleLines(
        policy,
        status: agentStatus(fakeStatus()),
      ).map((RuleLine line) => line.text).toList();
      expect(lines, <String>[
        'Tempo por dia: 2h 30min.',
        'Hora de dormir: todos os dias, das 21:00 às 07:00.',
        '2 apps bloqueados.',
        'O Navegador ParentaLynx tem filtro de sites.',
      ]);
    });

    test('dias da semana em texto', () {
      expect(daysText(<int>[1, 2, 3, 4, 5]), 'de segunda a sexta');
      expect(daysText(<int>[7, 6]), 'sábado e domingo');
      expect(daysText(<int>[1, 3, 5]), 'seg, qua e sex');
    });
  });

  group('permissoes', () {
    test('modo padrao exige uso, acessibilidade e notificacoes', () {
      final List<PermissionStep> steps = buildPermissionSteps(
        AgentStatusMapper.permissions(fakePermissions(accessibility: false, overlay: false)),
        manufacturer: 'motorola',
      );
      expect(
        steps.where((PermissionStep s) => s.isRequired).map((PermissionStep s) => s.kind),
        <PermissionKind>[
          PermissionKind.usageAccess,
          PermissionKind.accessibility,
          PermissionKind.notifications,
        ],
      );
      expect(requiredPermissionsGranted(steps), isFalse);
      expect(grantedRequiredCount(steps), 2);
      expect(nextPendingStep(steps)!.kind, PermissionKind.accessibility);
      expect(steps.any((PermissionStep s) => s.kind == PermissionKind.autostart), isFalse);
      expect(steps.any((PermissionStep s) => s.kind == PermissionKind.exactAlarms), isFalse);
    });

    test('Device Owner nao exige acessibilidade nem oferece administrador', () {
      final List<PermissionStep> steps = buildPermissionSteps(
        AgentStatusMapper.permissions(fakePermissions(accessibility: false, deviceOwner: true)),
        manufacturer: 'samsung',
      );
      expect(requiredPermissionsGranted(steps), isTrue);
      expect(steps.any((PermissionStep s) => s.kind == PermissionKind.deviceAdmin), isFalse);
    });

    test('fabricante com inicio automatico ganha o passo manual', () {
      final List<PermissionStep> steps = buildPermissionSteps(
        AgentStatusMapper.permissions(fakePermissions(exactAlarms: false)),
        manufacturer: 'Xiaomi',
      );
      final PermissionStep autostart = steps.last;
      expect(autostart.kind, PermissionKind.autostart);
      expect(autostart.granted, isNull);
      expect(steps.any((PermissionStep s) => s.kind == PermissionKind.exactAlarms), isTrue);
    });

    test('plano resume o andamento e o aviso das configuracoes restritas', () {
      final PermissionPlan plan = PermissionPlan(
        facts: AgentStatusMapper.permissions(
          fakePermissions(accessibility: false, restrictedSettingsLikely: true),
        ),
        manufacturer: 'motorola',
      );
      expect(plan.requiredTotal, 3);
      expect(plan.requiredGranted, 2);
      expect(plan.isComplete, isFalse);
      expect(plan.next!.kind, PermissionKind.accessibility);
      expect(plan.needsRestrictedSettingsHint(plan.next!), isTrue);
      expect(plan.needsRestrictedSettingsHint(plan.steps.first), isFalse);
    });
  });

  group('autenticacao do responsavel: mensagens', () {
    test('cada resultado tem a sua mensagem', () {
      expect(adminAuthMessage(const AdminAuth(status: AdminAuthStatus.ok), viaCode: false), isNull);
      expect(
        adminAuthMessage(
          const AdminAuth(status: AdminAuthStatus.invalid, attemptsLeft: 3),
          viaCode: false,
        ),
        'Senha incorreta. Restam 3 tentativas.',
      );
      expect(
        adminAuthMessage(
          const AdminAuth(status: AdminAuthStatus.invalid, attemptsLeft: 1),
          viaCode: true,
        ),
        'Código incorreto. Resta 1 tentativa.',
      );
      expect(
        adminAuthMessage(
          const AdminAuth(status: AdminAuthStatus.locked, retryAfterSec: 290),
          viaCode: false,
        ),
        'Muitas tentativas. Tente de novo em 5min.',
      );
      expect(
        adminAuthMessage(const AdminAuth(status: AdminAuthStatus.offline), viaCode: false),
        contains('código de acesso offline'),
      );
      expect(
        adminAuthMessage(const AdminAuth(status: AdminAuthStatus.error), viaCode: true),
        'Não foi possível conferir o código agora.',
      );
    });

    test('codigo offline fica so com os 8 digitos', () {
      expect(normalizeOfflineCode('1234 5678'), '12345678');
      expect(normalizeOfflineCode('12-34-56-78-90'), '12345678');
    });
  });
}
