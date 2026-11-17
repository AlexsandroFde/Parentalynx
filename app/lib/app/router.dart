import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/platform/native_providers.dart';
import '../features/child/child_routes.dart';
import '../features/guardian/guardian_routes.dart';
import '../features/onboarding/onboarding_routes.dart';

/// Avisa o roteador para reavaliar os redirecionamentos (troca de modo, login, vinculo).
class RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// Roteador do app.
///
/// O redirecionamento de topo decide pela area conforme o modo gravado: sem modo vai para as
/// boas-vindas, modo responsavel fica sob `/guardian` e modo crianca sob `/child`. Dentro de
/// cada area, a propria funcionalidade decide (sessao, bloqueio do app, vinculo).
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final RouterRefresh refresh = RouterRefresh();
  ref.onDispose(refresh.dispose);

  ref.listen<AppMode>(appModeProvider, (AppMode? previous, AppMode next) => refresh.refresh());
  registerGuardianRouterRefresh(ref, refresh.refresh);
  registerChildRouterRefresh(ref, refresh.refresh);

  final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;
      switch (ref.read(appModeProvider)) {
        case AppMode.unset:
          return location.startsWith(OnboardingPaths.welcome) ? null : OnboardingPaths.welcome;
        case AppMode.guardian:
          if (!location.startsWith(GuardianPaths.root)) {
            return GuardianPaths.root;
          }
          return guardianRedirect(ref, state);
        case AppMode.child:
          if (!location.startsWith(ChildPaths.root)) {
            return ChildPaths.root;
          }
          return childRedirect(ref, state);
      }
    },
    routes: <RouteBase>[
      // A raiz nunca e exibida: o redirecionamento sempre leva a uma das areas.
      GoRoute(path: '/', redirect: (BuildContext context, GoRouterState state) => null),
      ...onboardingRoutes,
      ...guardianRoutes,
      ...childRoutes,
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
