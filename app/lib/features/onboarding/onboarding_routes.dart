import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'presentation/welcome_page.dart';

abstract final class OnboardingPaths {
  static const String welcome = '/welcome';
}

final List<RouteBase> onboardingRoutes = <RouteBase>[
  GoRoute(
    path: OnboardingPaths.welcome,
    builder: (BuildContext context, GoRouterState state) => const WelcomePage(),
  ),
];
