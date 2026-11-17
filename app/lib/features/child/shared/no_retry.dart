/// Desliga a repeticao automatica de um provedor que falhou.
///
/// As telas do modo crianca mostram o erro com o botao "Tentar de novo", em vez de repetir em
/// silencio: a pessoa enxerga o que aconteceu e decide quando tentar.
Duration? noRetry(int retryCount, Object error) => null;
