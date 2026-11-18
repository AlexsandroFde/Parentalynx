import 'package:equatable/equatable.dart';

/// Resultado de uma sincronizacao pedida no aparelho da crianca.
///
/// A sincronizacao em si e feita pelo agente nativo, que funciona com a interface fechada:
/// fila persistente de eventos com identificadores unicos, reenvio ate a confirmacao do
/// servidor e confirmacao da versao de politica aplicada.
final class DeviceSyncResult extends Equatable {
  const DeviceSyncResult({required this.ok, required this.atMs, this.errorCode});

  final bool ok;
  final int atMs;

  /// Codigo de erro do protocolo ou `network`, quando [ok] e falso.
  final String? errorCode;

  @override
  List<Object?> get props => <Object?>[ok, atMs, errorCode];
}
