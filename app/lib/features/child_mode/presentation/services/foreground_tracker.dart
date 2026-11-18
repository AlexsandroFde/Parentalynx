/// Se o app esta em primeiro plano.
///
/// A casca do modo crianca ([ChildShell]) atualiza a cada mudanca do ciclo de vida. Os BLoCs
/// com consulta periodica ao agente consultam antes de cada rodada: com o app em segundo
/// plano as consultas param, para nao gastar bateria.
class ForegroundTracker {
  bool _foreground = true;

  bool get isForeground => _foreground;

  void update({required bool foreground}) {
    _foreground = foreground;
  }
}
