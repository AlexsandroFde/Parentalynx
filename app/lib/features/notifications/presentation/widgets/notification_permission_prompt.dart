import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/feedback_views.dart';
import '../bloc/notification_permission/notification_permission_bloc.dart';
import '../texts/notification_texts.dart';

/// Explica para que servem as notificacoes e, se a pessoa aceitar, pede a permissao ao
/// sistema pelo [NotificationPermissionBloc] da arvore. Devolve verdadeiro se a permissao foi
/// concedida.
Future<bool> requestNotificationsWithExplanation(BuildContext context) async {
  final NotificationPermissionBloc bloc = context.read<NotificationPermissionBloc>();
  final bool? proceed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: const Text('Ativar notificações?'),
        content: const Text(
          'O ParentaLynx avisa quando o limite diário é atingido, quando a criança pede mais '
          'tempo e quando alguma proteção é desativada.\n\n$alertDeliveryNote\n\n'
          'Você escolhe quais avisos quer receber nas preferências de notificação.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ativar'),
          ),
        ],
      );
    },
  );
  if (proceed != true) {
    return false;
  }
  final Completer<bool> completer = Completer<bool>();
  bloc.add(NotificationPermissionRequested(completer: completer));
  final bool granted = await completer.future;
  if (!context.mounted) {
    return granted;
  }
  if (!granted) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('As notificações continuam desativadas para o ParentaLynx.'),
          action: SnackBarAction(
            label: 'Configurações',
            onPressed: () => bloc.add(const NotificationSettingsOpened()),
          ),
        ),
      );
  } else {
    showAppSnackBar(context, 'Notificações ativadas.', tone: Tone.success);
  }
  return granted;
}
