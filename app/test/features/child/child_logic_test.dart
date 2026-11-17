import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/core/platform/native_api.g.dart';
import 'package:parentalynx/features/child/agent/data/agent_mappers.dart';
import 'package:parentalynx/features/child/agent/domain/child_models.dart';
import 'package:parentalynx/features/child/browser/domain/browser_navigation.dart';
import 'package:parentalynx/features/child/guardian_area/domain/admin_auth_texts.dart';
import 'package:parentalynx/features/child/home/domain/home_texts.dart';
import 'package:parentalynx/features/child/permissions/domain/permission_steps.dart';
import 'package:parentalynx/shared/domain/policy.dart';

import 'support/child_fakes.dart';

void main() {
  group('tela inicial: bloqueio', () {
    test('liberado nao tem mensagem de bloqueio', () {
      expect(lockMessage(childStatusFrom(fakeStatus())), isNull);
    });

    test('limite diario informa quando o tempo volta', () {
      final ChildStatus status = childStatusFrom(
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
      final ChildStatus status = childStatusFrom(
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
      final ChildStatus status = childStatusFrom(fakeStatus(lockState: LockState.manualLock));
      final LockMessage message = lockMessage(status)!;
      expect(message.title, 'Aparelho em pausa');
      expect(message.body, contains('Fale com Maria'));
    });

    test('liberacao local do responsavel tem prioridade sobre o bloqueio', () {
      final ChildStatus status = childStatusFrom(
        fakeStatus(lockState: LockState.dailyLimit, localOverrideUntilMs: msAt(16, 0)),
      );
      expect(status.isLocked, isFalse);
      expect(lockMessage(status), isNull);
      expect(reliefMessage(status), 'Uso liberado pelo responsável até 16:00.');
    });
  });

  group('tela inicial: tempo e avisos', () {
    test('contagem regressiva e nivel do anel', () {
      final TimeDisplay plenty = timeDisplay(childStatusFrom(fakeStatus()));
      expect(plenty.headline, '1:20:00');
      expect(plenty.detail, 'Você usou 1h 10min de 2h 30min.');
      expect(plenty.level, TimeLevel.plenty);

      final TimeDisplay low = timeDisplay(childStatusFrom(fakeStatus(quotaUsedMs: 8400000)));
      expect(low.headline, '10:00');
      expect(low.level, TimeLevel.low);

      final TimeDisplay over = timeDisplay(childStatusFrom(fakeStatus(quotaUsedMs: 9000000)));
      expect(over.headline, '00:00');
      expect(over.level, TimeLevel.over);
      expect(over.progress, 1);
    });

    test('sem limite mostra o uso total', () {
      final TimeDisplay display = timeDisplay(childStatusFrom(fakeStatus(limitEnabled: false)));
      expect(display.headline, 'Sem limite');
      expect(display.level, TimeLevel.unlimited);
    });

    test('tempo extra aparece no detalhe', () {
      final TimeDisplay display = timeDisplay(
        childStatusFrom(fakeStatus(limitMs: 10800000, extraMs: 1800000)),
      );
      expect(display.detail, contains('(com 30min extras)'));
    });

    test('suspensao de regras e descrita com os escopos', () {
      final ChildStatus status = childStatusFrom(
        fakeStatus(
          suspensionUntilMs: msAt(18, 0),
          suspensionScopes: <String>['dailyLimit', 'schedules'],
        ),
      );
      expect(
        reliefMessage(status),
        'Em pausa até 18:00: limite de tempo e horários e períodos de bloqueio.',
      );
    });

    test('problemas viram aviso em linguagem simples', () {
      expect(attentionMessage(childStatusFrom(fakeStatus())), isNull);
      final String message = attentionMessage(
        childStatusFrom(
          fakeStatus(
            issues: <String>['accessibility_disabled', 'battery_optimized'],
            clockTrusted: false,
          ),
        ),
      )!;
      expect(message, startsWith('A acessibilidade do controle está desligada.'));
      expect(message, contains('E mais 2 avisos'));
    });

    test('estado da conexao', () {
      expect(connectionText(childStatusFrom(fakeStatus())).ok, isTrue);
      final ConnectionText offline = connectionText(childStatusFrom(fakeStatus(lastSyncOk: false)));
      expect(offline.ok, isFalse);
      expect(offline.text, contains('As regras continuam valendo'));
    });

    test('pedidos de tempo', () {
      TimeRequest request(TimeRequestState state, {bool delivered = true, int? granted}) {
        return TimeRequest(
          id: 'r',
          createdAtMs: 0,
          state: state,
          delivered: delivered,
          minutes: 30,
          grantedMinutes: granted,
        );
      }

      expect(timeRequestText(request(TimeRequestState.pending)), 'Esperando a resposta');
      expect(
        timeRequestText(request(TimeRequestState.pending, delivered: false)),
        'Esperando conexão para enviar',
      );
      expect(
        timeRequestText(request(TimeRequestState.approved, granted: 45)),
        'Aprovado: mais 45min',
      );
      expect(timeRequestText(request(TimeRequestState.denied)), 'Não aprovado desta vez');
      expect(timeRequestAmount(request(TimeRequestState.pending)), 'Mais 30min');
    });

    test('resumo das regras do dia', () {
      final Policy policy = Policy.fromJson(decodeJsonObject(fakePolicyJson));
      final List<String> lines = ruleLines(
        policy,
        status: childStatusFrom(fakeStatus()),
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
        permissionFactsFrom(fakePermissions(accessibility: false, overlay: false)),
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
        permissionFactsFrom(fakePermissions(accessibility: false, deviceOwner: true)),
        manufacturer: 'samsung',
      );
      expect(requiredPermissionsGranted(steps), isTrue);
      expect(steps.any((PermissionStep s) => s.kind == PermissionKind.deviceAdmin), isFalse);
    });

    test('fabricante com inicio automatico ganha o passo manual', () {
      final List<PermissionStep> steps = buildPermissionSteps(
        permissionFactsFrom(fakePermissions(exactAlarms: false)),
        manufacturer: 'Xiaomi',
      );
      final PermissionStep autostart = steps.last;
      expect(autostart.kind, PermissionKind.autostart);
      expect(autostart.granted, isNull);
      expect(steps.any((PermissionStep s) => s.kind == PermissionKind.exactAlarms), isTrue);
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

  group('navegador: endereco e bloqueio', () {
    test('texto com formato de endereco vira endereco', () {
      expect(resolveAddressInput('exemplo.com').toString(), 'https://exemplo.com');
      expect(
        resolveAddressInput('wikipedia.org/wiki/Lince').toString(),
        'https://wikipedia.org/wiki/Lince',
      );
      expect(resolveAddressInput('http://exemplo.com/a').toString(), 'http://exemplo.com/a');
      expect(resolveAddressInput('192.168.0.1:8080').toString(), 'http://192.168.0.1:8080');
    });

    test('qualquer outro texto vira busca', () {
      expect(
        resolveAddressInput('lince iberico').toString(),
        'https://www.google.com/search?q=lince+iberico',
      );
      expect(
        resolveAddressInput('javascript:alert(1)').toString(),
        startsWith('https://www.google.com/search?q='),
      );
      expect(resolveAddressInput('dinossauros').toString(), contains('search?q=dinossauros'));
      expect(resolveAddressInput('   '), isNull);
    });

    test('so http e https sao aceitos', () {
      expect(isWebUrl('https://exemplo.com'), isTrue);
      expect(isWebUrl('http://exemplo.com'), isTrue);
      expect(isWebUrl('intent://abrir#Intent;end'), isFalse);
      expect(isWebUrl('file:///sdcard/a.html'), isFalse);
      expect(isWebUrl('about:blank'), isFalse);
    });

    test('endereco curto para a barra', () {
      expect(displayAddress('https://www.exemplo.com/'), 'exemplo.com');
      expect(displayAddress('https://exemplo.com/pagina'), 'exemplo.com/pagina');
      expect(displayAddress('about:blank'), '');
    });

    test('motivos de bloqueio em linguagem simples', () {
      expect(blockedReasonText('domain_blocked', null), contains('bloqueou este site'));
      expect(blockedReasonText('category', 'gambling'), contains('apostas e jogos de azar'));
      expect(blockedReasonText('safe_dns', null), contains('filtro de segurança'));
      expect(blockedReasonText('not_in_allowlist', null), contains('responsável escolheu'));
      expect(blockedReasonText(null, null), contains('não pode ser aberto'));
      expect(const BlockedPage(url: 'https://ruim.com/x').domain, 'ruim.com');
    });
  });
}
