import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../bloc/notification_permission/notification_permission_bloc.dart';
import '../texts/notification_texts.dart';

/// Explica para que servem as notificacoes e, se a pessoa aceitar, pede a permissao ao
/// sistema pelo [NotificationPermissionBloc] da arvore. Devolve verdadeiro se a permissao foi
/// concedida.
///
/// A explicacao vem antes do pedido do sistema (que so pode ser recusado uma vez): diz o que
/// sera avisado, quanto tempo os avisos podem demorar e onde escolher quais receber.
Future<bool> requestNotificationsWithExplanation(BuildContext context) async {
  final NotificationPermissionBloc bloc = context.read<NotificationPermissionBloc>();
  final bool proceed = await showConfirmDialog(
    context,
    icon: AppIcons.notificationActive,
    title: 'Ativar notificações?',
    message: notificationRationale,
    consequence: 'Você escolhe quais avisos receber nas preferências de notificação.',
    confirmLabel: 'Ativar',
    cancelLabel: 'Agora não',
  );
  if (!proceed) {
    return false;
  }
  final Completer<bool> completer = Completer<bool>();
  bloc.add(NotificationPermissionRequested(completer: completer));
  final bool granted = await completer.future;
  if (!context.mounted) {
    return granted;
  }
  if (granted) {
    showAppSnackBar(
      context,
      'Notificações ativadas. Os avisos chegam mesmo com o app fechado.',
      tone: Tone.success,
    );
  } else {
    // Depois de uma recusa o sistema nao mostra mais o pedido: o caminho e pelas configuracoes.
    showAppSnackBar(
      context,
      'As notificações continuam desativadas. Ative nas configurações do aparelho.',
      tone: Tone.warning,
      actionLabel: 'Configurações',
      onAction: () => bloc.add(const NotificationSettingsOpened()),
    );
  }
  return granted;
}
