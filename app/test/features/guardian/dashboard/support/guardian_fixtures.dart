import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/app/app.dart';
import 'package:parentalynx/app/theme/app_theme.dart';
import 'package:parentalynx/core/network/api_client.dart';
import 'package:parentalynx/core/network/network_providers.dart';
import 'package:parentalynx/core/platform/native_providers.dart';
import 'package:parentalynx/features/guardian/apps/presentation/app_icon.dart';
import 'package:parentalynx/features/guardian/guardian_paths.dart';

import '../../../../support/test_app.dart';

/// Momento fixo dos dados de exemplo: terca-feira, 17/11/2026, 15:30.
final DateTime fixtureNow = DateTime(2026, 11, 17, 15, 30);
const String fixtureToday = '2026-11-17';
const String deviceId = 'dev-1';

int msAgo(Duration ago) => fixtureNow.subtract(ago).millisecondsSinceEpoch;

/// Resposta de uma rota simulada: corpo JSON, ou uma resposta HTTP completa.
typedef RouteHandler = Object? Function(http.Request request);

/// Servidor simulado: associa "METODO /caminho" a uma resposta e guarda as requisicoes.
class FakeApi {
  FakeApi(this.routes);

  final Map<String, RouteHandler> routes;
  final List<http.Request> requests = <http.Request>[];

  /// Requisicoes feitas a uma rota ("METODO /caminho").
  List<http.Request> calls(String route) {
    return requests.where((http.Request r) => '${r.method} ${r.url.path}' == route).toList();
  }

  Map<String, Object?> bodyOf(http.Request request) {
    return jsonDecode(request.body) as Map<String, Object?>;
  }

  http.Client get client {
    return MockClient((http.Request request) async {
      requests.add(request);
      final RouteHandler? handler = routes['${request.method} ${request.url.path}'];
      if (handler == null) {
        return jsonResponse(<String, Object?>{
          'error': <String, Object?>{'code': 'not_found', 'message': 'Rota não simulada.'},
        }, 404);
      }
      final Object? result = handler(request);
      return result is http.Response ? result : jsonResponse(result ?? <String, Object?>{});
    });
  }

  List<Override> get overrides {
    return <Override>[
      ...baseOverrides(mode: AppMode.guardian),
      apiClientProvider.overrideWithValue(
        ApiClient(
          httpClient: client,
          baseUrl: () => 'https://servidor.teste',
          sessionToken: () => 'gs_teste',
        ),
      ),
      // Sem rede nos testes: os icones usam a inicial do app.
      appIconImageFactoryProvider.overrideWithValue((Uri uri, Map<String, String> headers) => null),
    ];
  }
}

http.Response jsonResponse(Object body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
  );
}

http.Response errorResponse(String code, int status, [Map<String, Object?>? details]) {
  return jsonResponse(<String, Object?>{
    'error': <String, Object?>{'code': code, 'message': 'Erro $code.', 'details': ?details},
  }, status);
}

Map<String, Object?> policyJson({
  bool limitEnabled = true,
  int minutes = 150,
  Map<String, Object?>? rules,
  String defaultForNewApps = 'allowed',
  Map<String, Object?>? overrides,
}) {
  return <String, Object?>{
    'schema': 1,
    'timezone': 'America/Fortaleza',
    'dailyLimit': <String, Object?>{
      'enabled': limitEnabled,
      'minutes': minutes,
      'resetTime': '00:00',
      'warnAtMinutes': <int>[15, 5],
    },
    'allowedHours': <String, Object?>{'enabled': false, 'windows': <Object?>[]},
    'blockPeriods': <Object?>[
      <String, Object?>{
        'id': 'p1',
        'label': 'Hora de dormir',
        'enabled': true,
        'kind': 'weekly',
        'days': <int>[1, 2, 3, 4, 5, 6, 7],
        'start': '21:00',
        'end': '07:00',
      },
    ],
    'apps': <String, Object?>{
      'defaultForNewApps': defaultForNewApps,
      'rules':
          rules ??
          <String, Object?>{
            'com.whatsapp': <String, Object?>{'state': 'exception', 'countsTowardLimit': false},
            'com.zhiliaoapp.musically': <String, Object?>{'state': 'blocked'},
            'com.google.android.youtube': <String, Object?>{
              'state': 'allowed',
              'dailyLimitMinutes': 45,
            },
          },
    },
    'web': <String, Object?>{
      'managedBrowser': true,
      'logHistory': true,
      'safeDns': true,
      'safeSearch': true,
      'mode': 'blocklist',
      'blockedDomains': <String>[],
      'allowedDomains': <String>[],
      'blockedCategories': <String>['adult', 'gambling'],
    },
    'protection': <String, Object?>{'lockOnTamper': false},
    'overrides':
        overrides ??
        <String, Object?>{
          'extraTime': <Object?>[],
          'manualLock': <String, Object?>{'active': false, 'until': null, 'setAt': null},
          'suspension': <String, Object?>{'until': 0, 'scopes': <String>[], 'setAt': null},
        },
  };
}

Map<String, Object?> deviceJson({
  String id = deviceId,
  String childName = 'João',
  int policyVersion = 12,
  int appliedPolicyVersion = 12,
  String lockState = 'none',
  int? releaseAt,
  int quotaUsedMs = 4200000,
  int totalUsedMs = 5400000,
  int? limitMs = 9000000,
  bool online = true,
  int pendingTimeRequests = 0,
  List<String> issues = const <String>[],
  String managementMode = 'standard',
  bool withState = true,
}) {
  return <String, Object?>{
    'id': id,
    'status': 'active',
    'childName': childName,
    'deviceName': 'Moto G de $childName',
    'model': 'moto g54',
    'manufacturer': 'motorola',
    'androidRelease': '14',
    'sdkInt': 34,
    'appVersion': '1.0.0',
    'timezone': 'America/Fortaleza',
    'createdAt': msAgo(const Duration(days: 20)),
    'approvedAt': msAgo(const Duration(days: 20)),
    'lastSyncAt': msAgo(const Duration(minutes: 1)),
    'online': online,
    'today': fixtureToday,
    'managementMode': managementMode,
    'policyVersion': policyVersion,
    'appliedPolicyVersion': appliedPolicyVersion,
    'policyAppliedAt': null,
    'pendingTimeRequests': pendingTimeRequests,
    'state': withState
        ? <String, Object?>{
            'reportedAt': msAgo(const Duration(minutes: 1)),
            'day': fixtureToday,
            'quotaUsedMs': quotaUsedMs,
            'totalUsedMs': totalUsedMs,
            'limitMs': limitMs,
            'extraMs': 0,
            'remainingMs': limitMs == null ? null : (limitMs - quotaUsedMs).clamp(0, limitMs),
            'limitReachedAt': null,
            'lock': <String, Object?>{'state': lockState, 'releaseAt': releaseAt},
            'foregroundApp': 'com.whatsapp',
            'screenOn': true,
            'batteryPercent': 76,
            'permissions': <String, Object?>{'usageAccess': true, 'accessibility': true},
            'enforcement': <String, Object?>{'active': true, 'issues': issues},
            'clockTrusted': true,
          }
        : null,
  };
}

Map<String, Object?> appJson(
  String package,
  String label,
  String category, {
  int todayMs = 0,
  int weekMs = 0,
  bool system = false,
  bool essential = false,
  String state = 'allowed',
}) {
  return <String, Object?>{
    'package': package,
    'label': label,
    'category': category,
    'system': system,
    'launchable': true,
    'essential': essential,
    'versionName': '1.0',
    'iconUrl': '/v1/guardian/devices/$deviceId/apps/icon?package=$package&v=abc',
    'state': state,
    'countsTowardLimit': false,
    'dailyLimitMinutes': null,
    'todayMs': todayMs,
    'weekMs': weekMs,
    'removed': false,
  };
}

Map<String, Object?> appsJson() {
  return <String, Object?>{
    'day': fixtureToday,
    'apps': <Object?>[
      appJson('com.google.android.youtube', 'YouTube', 'video', todayMs: 1980000, weekMs: 9000000),
      appJson(
        'com.supercell.brawlstars',
        'Brawl Stars',
        'games',
        todayMs: 1500000,
        weekMs: 7200000,
      ),
      appJson('com.whatsapp', 'WhatsApp', 'communication', todayMs: 1200000, state: 'exception'),
      appJson('com.zhiliaoapp.musically', 'TikTok', 'social', state: 'blocked'),
      appJson('com.android.chrome', 'Chrome', 'browser', todayMs: 480000, system: true),
      appJson('com.duolingo', 'Duolingo', 'productivity', todayMs: 240000),
      appJson('com.android.dialer', 'Telefone', 'communication', system: true, essential: true),
    ],
  };
}

Map<String, Object?> alertsJson() {
  return <String, Object?>{
    'alerts': <Object?>[
      <String, Object?>{
        'id': 3,
        'type': 'blocked_app_attempt',
        'deviceId': deviceId,
        'childName': 'João',
        'createdAt': msAgo(const Duration(minutes: 12)),
        'readAt': null,
        'title': 'Tentativa de abrir app bloqueado',
        'body': 'João tentou abrir o TikTok.',
      },
      <String, Object?>{
        'id': 2,
        'type': 'low_time',
        'deviceId': deviceId,
        'childName': 'João',
        'createdAt': msAgo(const Duration(hours: 2)),
        'readAt': 1,
        'title': 'Pouco tempo restante',
        'body': 'Faltam 10 minutos para o limite de João.',
      },
    ],
    'latestId': 3,
    'unread': 1,
  };
}

/// Relatorio de sete dias com dados plausiveis.
Map<String, Object?> summaryJson() {
  const List<int> totals = <int>[150, 95, 130, 0, 175, 240, 90];
  const List<int> quotas = <int>[130, 80, 110, 0, 150, 200, 70];
  const List<int> blocked = <int>[2, 0, 1, 0, 3, 5, 1];
  final List<int> hourly = List<int>.filled(24, 0);
  const Map<int, int> minutesByHour = <int, int>{
    7: 20, 8: 35, 12: 60, 13: 45, 16: 80, 17: 110, 18: 150, 19: 190, 20: 140, 21: 50, //
  };
  minutesByHour.forEach((int hour, int minutes) => hourly[hour] = minutes * 60000);
  return <String, Object?>{
    'from': '2026-11-11',
    'to': fixtureToday,
    'timezone': 'America/Fortaleza',
    'totals': <String, Object?>{
      'totalMs': 880 * 60000,
      'quotaMs': 740 * 60000,
      'daysWithUse': 6,
      'avgPerDayMs': 126 * 60000,
      'blockedAttempts': 12,
      'sessions': 84,
      'opens': 143,
    },
    'daily': <Object?>[
      for (int i = 0; i < 7; i++)
        <String, Object?>{
          'day': '2026-11-${11 + i}',
          'totalMs': totals[i] * 60000,
          'quotaMs': quotas[i] * 60000,
          'limitMs': (i == 3 || i == 4 ? 240 : 150) * 60000,
          'limitReachedAt': null,
          'blockedAttempts': blocked[i],
          'firstUseAt': null,
          'lastUseAt': null,
        },
    ],
    'apps': <Object?>[
      _usage('com.google.android.youtube', 'YouTube', 'video', 310, 41),
      _usage('com.supercell.brawlstars', 'Brawl Stars', 'games', 240, 22),
      _usage('com.whatsapp', 'WhatsApp', 'communication', 140, 48),
      _usage('com.android.chrome', 'Chrome', 'browser', 110, 19),
      _usage('com.duolingo', 'Duolingo', 'productivity', 80, 13),
    ],
    'categories': <Object?>[
      <String, Object?>{'category': 'video', 'totalMs': 310 * 60000},
      <String, Object?>{'category': 'games', 'totalMs': 240 * 60000},
      <String, Object?>{'category': 'communication', 'totalMs': 140 * 60000},
      <String, Object?>{'category': 'browser', 'totalMs': 110 * 60000},
      <String, Object?>{'category': 'productivity', 'totalMs': 80 * 60000},
    ],
    'hourly': hourly,
    'blockedByApp': <Object?>[
      <String, Object?>{'package': 'com.zhiliaoapp.musically', 'label': 'TikTok', 'count': 9},
      <String, Object?>{'package': 'com.instagram.android', 'label': 'Instagram', 'count': 3},
    ],
  };
}

Map<String, Object?> _usage(String package, String label, String category, int minutes, int opens) {
  return <String, Object?>{
    'package': package,
    'label': label,
    'category': category,
    'totalMs': minutes * 60000,
    'opens': opens,
    'days': 5,
    'blockedAttempts': 0,
  };
}

/// Rotas de leitura de um aparelho ativo com politica, apps, alertas e relatorio.
Map<String, RouteHandler> standardRoutes({
  Map<String, Object?>? device,
  Map<String, Object?>? policy,
  int policyVersion = 12,
}) {
  final Map<String, Object?> deviceBody = device ?? deviceJson();
  return <String, RouteHandler>{
    'GET /v1/guardian/devices': (http.Request r) => <String, Object?>{
      'devices': <Object?>[deviceBody],
    },
    'GET /v1/guardian/devices/$deviceId': (http.Request r) => <String, Object?>{
      'device': deviceBody,
      'policyVersion': policyVersion,
      'policy': policy ?? policyJson(),
    },
    'GET /v1/guardian/devices/$deviceId/apps': (http.Request r) => appsJson(),
    'GET /v1/guardian/alerts': (http.Request r) => alertsJson(),
    'GET /v1/guardian/devices/$deviceId/reports/summary': (http.Request r) => summaryJson(),
  };
}

/// Monta as rotas informadas em um roteador de teste, com o tema e a localizacao do app.
Future<void> pumpGuardianRoutes(
  WidgetTester tester, {
  required List<RouteBase> routes,
  required String location,
  required List<Override> overrides,
  Size size = phoneSize,
  Brightness brightness = Brightness.light,
}) async {
  await initializeDateFormatting('pt_BR');
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = size * 2.0;
  addTearDown(tester.view.reset);
  final GoRouter router = GoRouter(
    initialLocation: location,
    routes: <RouteBase>[
      ...routes,
      for (final String path in <String>[GuardianPaths.pairing, GuardianPaths.alerts])
        GoRoute(
          path: path,
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(body: Center(child: Text('destino $path')));
          },
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
        locale: appLocale,
        supportedLocales: const <Locale>[appLocale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: wrapAppContent,
      ),
    ),
  );
  await settle(tester);
}

/// Avanca o tempo simulado o bastante para as respostas chegarem e as animacoes terminarem,
/// sem depender de `pumpAndSettle`.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
