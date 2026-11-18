import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/authentication/presentation/widgets/session_lifecycle_listener.dart';
import '../../features/child_device/presentation/bloc/devices/devices_bloc.dart';
import '../../features/device_sync/presentation/bloc/device_sync_bloc.dart';
import '../../features/notifications/presentation/bloc/notification_permission/notification_permission_bloc.dart';
import '../../features/notifications/presentation/bloc/notifications/notifications_bloc.dart';

/// Escopo da sessao do painel aberto.
///
/// Envolve todas as telas do painel (abas, vinculacao e aparelhos). Os BLoCs daqui vivem
/// enquanto o painel esta aberto: quando ele bloqueia ou a sessao termina, o roteador sai do
/// escopo e eles sao fechados (lista de aparelhos, canal em tempo real, alertas). Ao voltar,
/// sao criados de novo, sem dados da sessao anterior.
class GuardianSessionScope extends StatelessWidget {
  const GuardianSessionScope({required this.di, required this.child, super.key});

  final GetIt di;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DevicesBloc>(
          lazy: false,
          create: (BuildContext context) => di<DevicesBloc>()..add(const DevicesStarted()),
        ),
        BlocProvider<DeviceSyncBloc>(
          lazy: false,
          create: (BuildContext context) => di<DeviceSyncBloc>()..add(const DeviceSyncStarted()),
        ),
        BlocProvider<NotificationsBloc>(
          lazy: false,
          create: (BuildContext context) {
            return di<NotificationsBloc>()..add(const NotificationsStarted());
          },
        ),
        BlocProvider<NotificationPermissionBloc>(
          lazy: false,
          create: (BuildContext context) {
            return di<NotificationPermissionBloc>()..add(const NotificationPermissionStarted());
          },
        ),
      ],
      child: SessionLifecycleListener(child: child),
    );
  }
}
