/// Enderecos que outros apps pedem para o navegador gerenciado abrir (link tocado).
abstract interface class IBrowserUrlRequests {
  /// Endereco com que o navegador foi aberto, quando houver, seguido dos enderecos recebidos
  /// com o navegador ja aberto. Cada endereco chega uma unica vez.
  Stream<String> watch();
}
