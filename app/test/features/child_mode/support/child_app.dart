import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parentalynx/core/constants/route_paths.dart';
import 'package:parentalynx/core/time/clock.dart';
import 'package:parentalynx/features/app_management/presentation/services/app_icon_images.dart';
import 'package:parentalynx/features/app_management/presentation/services/installed_app_icons.dart';
import 'package:parentalynx/features/child_mode/child_mode_routes.dart';
import 'package:parentalynx/features/child_mode/presentation/bloc/child_device_status/child_device_status_bloc.dart';
import 'package:parentalynx/features/child_mode/presentation/services/foreground_tracker.dart';
import 'package:parentalynx/features/device_linking/presentation/bloc/child_link/child_link_bloc.dart';
import 'package:parentalynx/shared/services/share_service.dart';
import 'package:parentalynx/shared/theme/app_frame.dart';
import 'package:parentalynx/shared/theme/app_theme.dart';

import '../../../support/fakes.dart';
import '../../../support/test_app.dart';

/// Monta uma tela do modo crianca com o que a casca da area entrega a todas as telas: o
/// [ChildLinkBloc], o [ChildDeviceStatusBloc], o [ForegroundTracker] e os icones dos apps.
/// Os BLoCs da propria tela ficam por conta de [page].
Future<void> pumpChildPage(WidgetTester tester, GetIt di, Widget page, {Size size = phoneSize}) {
  return pumpWidgetInApp(
    tester,
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ForegroundTracker>.value(value: di<ForegroundTracker>()),
        RepositoryProvider<InstalledAppIcons>.value(value: di<InstalledAppIcons>()),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<Object?>>[
          BlocProvider<ChildLinkBloc>.value(value: di<ChildLinkBloc>()),
          BlocProvider<ChildDeviceStatusBloc>(
            lazy: false,
            create: (BuildContext context) {
              return di<ChildDeviceStatusBloc>()..add(const ChildDeviceStatusStarted());
            },
          ),
        ],
        child: page,
      ),
    ),
    di: di,
    size: size,
  );
}

/// Desmonta a arvore para encerrar os temporizadores periodicos das telas e fecha o
/// [ChildLinkBloc] do conteiner.
///
/// Tudo o que foi criado durante o teste roda no tempo simulado do `testWidgets` e precisa
/// ser encerrado dentro dele: o descarte do conteiner (no fim do teste) ja roda fora.
Future<void> unmountChildApp(WidgetTester tester, GetIt di) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  // No tempo simulado o fechamento nao pode ser esperado direto: os quadros seguintes o
  // concluem.
  unawaited(di<ChildLinkBloc>().close());
  await tester.pump();
  await tester.pump();
}

/// Deixa as respostas dos dubles chegarem e as animacoes de entrada terminarem.
Future<void> settleChild(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Avisa o roteador a cada mudanca do vinculo, como o roteador do app.
class _LinkRefresh extends ChangeNotifier {
  _LinkRefresh(Stream<ChildLinkState> changes) {
    _subscription = changes.listen((ChildLinkState state) => notifyListeners());
  }

  late final StreamSubscription<ChildLinkState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

/// Roteador so com a area da crianca, ligado como o roteador do app deve fazer: redireciona
/// pela fase do [ChildLinkBloc] com [childRedirect] e monta a area com [childShellRoute].
Future<void> pumpChildArea(WidgetTester tester, GetIt di) async {
  final ChildLinkBloc link = di<ChildLinkBloc>();
  final _LinkRefresh refresh = _LinkRefresh(link.stream);
  final GoRouter router = GoRouter(
    initialLocation: ChildPaths.root,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      return childRedirect(link.state.phase, state.matchedLocation);
    },
    routes: <RouteBase>[childShellRoute(di)],
  );
  addTearDown(() {
    router.dispose();
    refresh.dispose();
  });
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = phoneSize * 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ShareService>.value(value: di<ShareService>()),
        RepositoryProvider<Clock>.value(value: di<Clock>()),
        RepositoryProvider<AppIconImages>.value(value: const NoAppIconImages()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: appLocale,
        supportedLocales: const <Locale>[appLocale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: wrapAppContent,
      ),
    ),
  );
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
