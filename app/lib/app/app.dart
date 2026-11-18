import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

import '../core/constants/app_constants.dart';
import '../core/time/clock.dart';
import '../features/app_management/presentation/services/app_icon_images.dart';
import '../features/authentication/presentation/bloc/auth/auth_bloc.dart';
import '../features/device_linking/presentation/bloc/child_link/child_link_bloc.dart';
import '../features/user_role/presentation/bloc/user_role_bloc.dart';
import '../shared/services/share_service.dart';
import '../shared/theme/app_frame.dart';
import '../shared/theme/app_theme.dart';
import 'router/app_router.dart';

/// Raiz do aplicativo principal (os dois perfis).
///
/// Entrega a arvore os servicos de interface e os BLoCs que vivem enquanto o app vive
/// (perfil, sessao do responsavel e vinculo da crianca). Os demais BLoCs sao criados pelas
/// rotas.
class ParentaLynxApp extends StatefulWidget {
  const ParentaLynxApp({required this.di, required this.navigatorKey, super.key});

  final GetIt di;

  /// Navegador raiz, compartilhado com o pedido de senha administrativa.
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<ParentaLynxApp> createState() => _ParentaLynxAppState();
}

class _ParentaLynxAppState extends State<ParentaLynxApp> {
  late final AppRouter _router = buildAppRouter(widget.di, navigatorKey: widget.navigatorKey);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GetIt di = widget.di;
    return MultiRepositoryProvider(
      providers: <RepositoryProvider<Object>>[
        RepositoryProvider<ShareService>.value(value: di<ShareService>()),
        RepositoryProvider<Clock>.value(value: di<Clock>()),
        RepositoryProvider<AppIconImages>.value(value: di<AppIconImages>()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<UserRoleBloc>.value(value: di<UserRoleBloc>()),
          BlocProvider<AuthBloc>.value(value: di<AuthBloc>()),
          BlocProvider<ChildLinkBloc>.value(value: di<ChildLinkBloc>()),
        ],
        child: MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          routerConfig: _router.router,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: appLocale,
          supportedLocales: const <Locale>[appLocale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: wrapAppContent,
        ),
      ),
    );
  }
}
