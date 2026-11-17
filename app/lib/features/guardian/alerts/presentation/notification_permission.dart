import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/platform/native_api.g.dart' show DeviceApi;
import '../../../../core/platform/native_providers.dart';
import '../../../../shared/widgets/feedback_views.dart';
import 'alerts_controller.dart';

/// Texto unico sobre a entrega dos alertas, usado em mais de uma tela para nao prometer mais
/// do que o app entrega.
const String alertDeliveryNote =
    'Com o app aberto, os alertas chegam na hora. Com o app fechado, o aparelho busca novos '
    'alertas em segundo plano e eles podem levar até cerca de 15 minutos para aparecer.';

/// Explica para que servem as notificacoes e, se a pessoa aceitar, pede a permissao ao
/// sistema. Devolve verdadeiro se a permissao foi concedida.
Future<bool> requestNotificationsWithExplanation(BuildContext context, WidgetRef ref) async {
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
  final DeviceApi api = ref.read(deviceApiProvider);
  bool granted = false;
  try {
    granted = await api.requestNotificationPermission();
  } on PlatformException {
    granted = false;
  }
  ref.invalidate(notificationsAllowedProvider);
  if (!granted && context.mounted) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('As notificações continuam desativadas para o ParentaLynx.'),
          action: SnackBarAction(
            label: 'Configurações',
            onPressed: () async {
              try {
                await api.openNotificationSettings();
              } on PlatformException {
                // Sem tela de configuracoes disponivel. Nada a fazer.
              }
            },
          ),
        ),
      );
  } else if (granted && context.mounted) {
    showAppSnackBar(context, 'Notificações ativadas.', tone: Tone.success);
  }
  return granted;
}
