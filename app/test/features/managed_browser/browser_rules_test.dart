import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/managed_browser/domain/entities/blocked_page.dart';
import 'package:parentalynx/features/managed_browser/domain/entities/browser_settings.dart';
import 'package:parentalynx/features/managed_browser/domain/entities/browser_visit.dart';
import 'package:parentalynx/features/managed_browser/domain/entities/navigation_verdict.dart';
import 'package:parentalynx/features/managed_browser/domain/services/browser_navigation_rules.dart';
import 'package:parentalynx/features/managed_browser/domain/services/i_web_filter_service.dart';
import 'package:parentalynx/features/managed_browser/domain/usecases/evaluate_navigation.dart';
import 'package:parentalynx/features/managed_browser/domain/usecases/record_browser_visit.dart';
import 'package:parentalynx/features/managed_browser/presentation/texts/browser_texts.dart';

class _MockWebFilter extends Mock implements IWebFilterService {}

const BrowserSettings _logging = BrowserSettings(
  enabled: true,
  logHistory: true,
  safeSearch: true,
  allowlistMode: false,
);

void main() {
  setUpAll(() => registerFallbackValue(const BrowserVisit.opened(url: '')));

  group('endereco digitado', () {
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
  });

  group('textos', () {
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

  group('decisao do filtro', () {
    test('a busca segura troca o endereco so por outro endereco web', () {
      const NavigationVerdict safe = NavigationVerdict(
        allowed: true,
        rewrittenUrl: 'https://busca.com/?q=x&safe=active',
      );
      expect(safe.targetFor('https://busca.com/?q=x'), 'https://busca.com/?q=x&safe=active');
      const NavigationVerdict odd = NavigationVerdict(allowed: true, rewrittenUrl: 'intent://x');
      expect(odd.targetFor('https://busca.com/?q=x'), 'https://busca.com/?q=x');
      expect(const NavigationVerdict.checkFailed().isCheckFailure, isTrue);
    });

    test('sem resposta do filtro a pagina nao abre', () async {
      final _MockWebFilter filter = _MockWebFilter();
      when(() => filter.evaluate(any()))
          .thenAnswer((_) async => const Err<NavigationVerdict>(UnexpectedFailure()));

      final NavigationVerdict verdict = await EvaluateNavigation(filter)('https://exemplo.com');

      expect(verdict.allowed, isFalse);
      expect(verdict.reason, NavigationVerdict.checkFailedReason);
    });
  });

  group('historico', () {
    late _MockWebFilter filter;
    late RecordBrowserVisit record;

    setUp(() {
      filter = _MockWebFilter();
      record = RecordBrowserVisit(filter);
      when(() => filter.recordVisit(any())).thenAnswer((_) async => okVoid);
    });

    test('registra so quando a politica pede o historico', () async {
      const BrowserVisit visit = BrowserVisit.opened(url: 'https://exemplo.com', title: 'E');

      await record(visit, settings: _logging);
      await record(
        visit,
        settings: const BrowserSettings(
          enabled: true,
          logHistory: false,
          safeSearch: false,
          allowlistMode: false,
        ),
      );

      verify(() => filter.recordVisit(visit)).called(1);
    });

    test('bloqueio por falta de resposta do filtro nao vai para o historico', () async {
      await record(
        const BrowserVisit.blocked(
          url: 'https://exemplo.com',
          reason: NavigationVerdict.checkFailedReason,
        ),
        settings: _logging,
      );

      verifyNever(() => filter.recordVisit(any()));
    });

    test('falha ao registrar nao interrompe a navegacao', () async {
      when(() => filter.recordVisit(any()))
          .thenAnswer((_) async => const Err<void>(UnexpectedFailure()));

      await expectLater(
        record(const BrowserVisit.opened(url: 'https://exemplo.com'), settings: _logging),
        completes,
      );
    });
  });
}
