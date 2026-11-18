part of 'notification_permission_bloc.dart';

sealed class NotificationPermissionEvent extends Equatable {
  const NotificationPermissionEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// O painel abriu: confere se o sistema permite as notificacoes.
final class NotificationPermissionStarted extends NotificationPermissionEvent {
  const NotificationPermissionStarted();
}

/// O painel apareceu pela primeira vez: decide se deve explicar e pedir a permissao.
final class NotificationFirstRunCheckRequested extends NotificationPermissionEvent {
  const NotificationFirstRunCheckRequested();
}

/// A explicacao da primeira vez ja foi mostrada.
final class NotificationFirstRunPromptShown extends NotificationPermissionEvent {
  const NotificationFirstRunPromptShown();
}

/// A pessoa aceitou ativar as notificacoes: pede a permissao ao sistema.
///
/// [completer] recebe verdadeiro se a permissao ficou concedida. Nao entra na comparacao.
final class NotificationPermissionRequested extends NotificationPermissionEvent {
  const NotificationPermissionRequested({this.completer});

  final Completer<bool>? completer;
}

/// Abrir as configuracoes de notificacao do app no sistema.
final class NotificationSettingsOpened extends NotificationPermissionEvent {
  const NotificationSettingsOpened();
}
