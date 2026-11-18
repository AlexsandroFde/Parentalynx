import 'dart:async';

/// Valor atual com aviso de mudancas.
///
/// Quem assina [stream] recebe o valor atual na hora (se ja houver um) e cada mudanca
/// seguinte, sem janela em que um aviso se perca. Repositorios usam esta classe para ser a
/// fonte unica de verdade em memoria: varios BLoCs observam o mesmo dado e ficam coerentes
/// sem conversar entre si (padrao Observer).
class ObservableValue<T> {
  ObservableValue();

  ObservableValue.seeded(T initial) : _value = initial, _hasValue = true;

  final StreamController<T> _changes = StreamController<T>.broadcast(sync: true);
  T? _value;
  bool _hasValue = false;

  bool get hasValue => _hasValue;

  /// Valor atual. So chame depois de conferir [hasValue] quando `T` nao aceita nulo.
  T get value {
    if (!_hasValue) {
      throw StateError('ObservableValue sem valor');
    }
    return _value as T;
  }

  /// Valor atual, ou nulo quando ainda nao ha um.
  T? get valueOrNull => _value;

  /// Troca o valor e avisa quem assina. Valor igual ao atual nao gera aviso.
  void add(T value) {
    if (_hasValue && _value == value) {
      return;
    }
    _value = value;
    _hasValue = true;
    if (!_changes.isClosed) {
      _changes.add(value);
    }
  }

  /// Valor atual seguido das mudancas.
  Stream<T> get stream {
    return Stream<T>.multi((MultiStreamController<T> controller) {
      if (_hasValue) {
        controller.add(_value as T);
      }
      final StreamSubscription<T> subscription = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  Future<void> close() => _changes.close();
}
