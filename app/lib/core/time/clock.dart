/// Fonte da hora atual.
///
/// Regras que dependem do tempo (bloqueio do painel, alertas lidos, validade de codigos)
/// recebem um [Clock] pelo construtor, para que os testes controlem a passagem do tempo.
abstract interface class Clock {
  DateTime now();
}

/// Relogio do aparelho.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

extension ClockMillis on Clock {
  /// Instante atual em milissegundos desde a epoca.
  int nowMs() => now().millisecondsSinceEpoch;
}
