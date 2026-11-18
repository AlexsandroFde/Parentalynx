import '../entities/realtime_update.dart';

/// Canal de avisos em tempo real do responsavel.
abstract interface class IRealtimeRepository {
  /// Avisos recebidos enquanto o canal estiver aberto.
  Stream<RealtimeUpdate> get updates;

  /// Estado da conexao (aberta ou nao) seguido das mudancas.
  Stream<bool> watchConnection();

  /// Abre o canal com a sessao atual. Sem sessao ou sem servidor configurado, nao faz nada.
  /// Reconecta sozinho com espera progressiva enquanto nao for fechado.
  void connect();

  /// Fecha o canal.
  Future<void> disconnect();
}
