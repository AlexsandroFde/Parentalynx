import 'package:equatable/equatable.dart';

import 'alert_type.dart';

/// Quais tipos de alerta geram notificacao para a conta.
///
/// Tipo ausente do mapa vale como ligado. Desligar um tipo nao apaga os alertas: eles
/// continuam na central, so deixam de notificar.
final class NotificationPreferences extends Equatable {
  const NotificationPreferences(this.byType);

  /// Preferencia por codigo de tipo.
  final Map<String, bool> byType;

  bool notifies(AlertType type) => byType[type.code] ?? true;

  /// Preferencias completas (todos os tipos conhecidos) com um tipo trocado.
  NotificationPreferences withType(AlertType type, {required bool enabled}) {
    return NotificationPreferences(<String, bool>{
      for (final AlertType item in AlertType.values) item.code: notifies(item),
      type.code: enabled,
    });
  }

  @override
  List<Object?> get props => <Object?>[byType];
}
