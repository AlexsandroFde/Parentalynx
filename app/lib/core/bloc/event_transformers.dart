import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:stream_transform/stream_transform.dart';

export 'package:bloc_concurrency/bloc_concurrency.dart'
    show concurrent, droppable, restartable, sequential;

/// Transformadores de eventos usados pelos BLoCs.
///
/// Regra de escolha (ver `docs/adr/0001-bloc-clean-architecture.md`):
/// - `droppable()`: comandos (salvar, aprovar, bloquear). Toques repetidos enquanto o comando
///   anterior roda sao descartados, evitando operacoes duplicadas.
/// - `restartable()`: cargas e consultas. Uma nova consulta cancela a anterior, que ficaria
///   desatualizada.
/// - `sequential()`: edicoes locais em que a ordem importa.
/// - [debounceRestartable]: rajadas de avisos (tempo real, busca digitada). So o ultimo evento
///   da rajada e processado.

/// Espera [duration] sem novos eventos antes de processar o ultimo, cancelando o
/// processamento anterior se outro evento chegar.
EventTransformer<E> debounceRestartable<E>(Duration duration) {
  return (Stream<E> events, EventMapper<E> mapper) {
    return restartable<E>().call(events.debounce(duration), mapper);
  };
}
