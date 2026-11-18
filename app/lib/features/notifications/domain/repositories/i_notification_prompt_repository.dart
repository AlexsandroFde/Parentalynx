/// Lembra se o pedido de permissao de notificacoes ja foi apresentado neste aparelho.
abstract interface class INotificationPromptRepository {
  Future<bool> wasPrompted();

  Future<void> markPrompted();
}
