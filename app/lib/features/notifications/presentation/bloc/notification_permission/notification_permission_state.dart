part of 'notification_permission_bloc.dart';

/// Se o sistema permite as notificacoes do app.
enum NotificationPermissionStatus {
  /// Ainda conferindo.
  unknown,
  allowed,
  denied,
}

final class NotificationPermissionState extends Equatable {
  const NotificationPermissionState({
    this.status = NotificationPermissionStatus.unknown,
    this.firstRunPrompt = false,
  });

  final NotificationPermissionStatus status;

  /// Verdadeiro quando o painel deve explicar as notificacoes e pedir a permissao agora (so na
  /// primeira vez neste aparelho).
  final bool firstRunPrompt;

  bool get isDenied => status == NotificationPermissionStatus.denied;

  NotificationPermissionState copyWith({
    NotificationPermissionStatus? status,
    bool? firstRunPrompt,
  }) {
    return NotificationPermissionState(
      status: status ?? this.status,
      firstRunPrompt: firstRunPrompt ?? this.firstRunPrompt,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, firstRunPrompt];
}
