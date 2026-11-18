import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/bloc/action_status.dart';
import 'package:parentalynx/core/bloc/event_transformers.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/core/logging/app_logger.dart';
import 'package:parentalynx/core/platform/native_call.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/core/utils/observable_value.dart';

class _Tick {
  const _Tick(this.value);

  final int value;
}

class _DebounceBloc extends Bloc<_Tick, List<int>> {
  _DebounceBloc() : super(const <int>[]) {
    on<_Tick>(
      (_Tick event, Emitter<List<int>> emit) => emit(<int>[...state, event.value]),
      transformer: debounceRestartable(const Duration(milliseconds: 30)),
    );
  }
}

void main() {
  group('Result', () {
    test('guard converte excecao em falha tipada', () async {
      final Result<int> ok = await Result.guard(() async => 1);
      final Result<int> err = await Result.guard<int>(() async => throw const NetworkFailure());
      final Result<int> json = await Result.guard<int>(
        () async => throw const JsonFormatException('x'),
      );
      expect(ok, const Ok<int>(1));
      expect(err, const Err<int>(NetworkFailure()));
      expect(json.failureOrNull, isA<UnexpectedFailure>());
    });

    test('map, then e fold seguem o sucesso e param na falha', () async {
      const Result<int> ok = Ok<int>(2);
      const Result<int> err = Err<int>(CancelledFailure());
      expect(ok.map((int v) => v * 2), const Ok<int>(4));
      expect(err.map((int v) => v * 2), const Err<int>(CancelledFailure()));
      expect(await ok.then((int v) async => Ok<String>('$v')), const Ok<String>('2'));
      expect(ok.fold(onOk: (int v) => 'ok $v', onErr: (AppFailure f) => 'erro'), 'ok 2');
      expect(err.fold(onOk: (int v) => 'ok', onErr: (AppFailure f) => 'erro'), 'erro');
    });
  });

  test('cancelamento nao vira aviso de falha', () {
    expect(actionStatusForFailure(const CancelledFailure()), const ActionIdle());
    expect(actionStatusForFailure(const NetworkFailure()), const ActionFailed(NetworkFailure()));
  });

  group('ObservableValue', () {
    test('quem assina recebe o valor atual e as mudancas, sem repetir valor igual', () async {
      final ObservableValue<int> value = ObservableValue<int>.seeded(1);
      final List<int> seen = <int>[];
      final StreamSubscription<int> subscription = value.stream.listen(seen.add);
      value
        ..add(1)
        ..add(2)
        ..add(3);
      await Future<void>.delayed(Duration.zero);
      expect(seen, <int>[1, 2, 3]);
      await subscription.cancel();
    });

    test('sem valor inicial so recebe as mudancas', () async {
      final ObservableValue<String> value = ObservableValue<String>();
      expect(value.hasValue, isFalse);
      expect(() => value.value, throwsStateError);
      final Future<String> first = value.stream.first;
      value.add('a');
      expect(await first, 'a');
    });
  });

  group('callNative', () {
    test('erro esperado do lado nativo traz codigo e texto pronto', () async {
      final Result<void> result = await callNative<void>(
        () async => throw PlatformException(
          code: 'admin_auth_required',
          message: 'Autenticação do responsável necessária.',
        ),
      );
      final NativeFailure failure = result.failureOrNull! as NativeFailure;
      expect(failure.code, NativeErrorCode.adminAuthRequired);
      expect(failure.isAdminAuthRequired, isTrue);
      expect(failure.message, 'Autenticação do responsável necessária.');
    });

    test('excecao inesperada usa o texto padrao, sem nome de classe', () async {
      final Result<void> result = await callNative<void>(
        () async => throw PlatformException(
          code: 'IllegalStateException',
          message: 'java.lang.IllegalStateException: x',
          details: 'Cause: null, Stacktrace: ...',
        ),
        fallback: 'Não deu.',
      );
      final NativeFailure failure = result.failureOrNull! as NativeFailure;
      expect(failure.code, NativeErrorCode.unknown);
      expect(failure.message, 'Não deu.');
    });

    test('falha opcional devolve o valor de reserva', () async {
      expect(await callNativeOr<int>(() async => throw PlatformException(code: 'x'), 7), 7);
    });
  });

  test('debounce processa so o ultimo evento da rajada', () async {
    final _DebounceBloc bloc = _DebounceBloc()
      ..add(const _Tick(1))
      ..add(const _Tick(2))
      ..add(const _Tick(3));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(bloc.state, <int>[3]);
    await bloc.close();
  });

  test('registro estruturado gera uma linha JSON com campos simples', () {
    expect(
      formatLogRecord(LogLevel.warning, 'policy_save_failed', <String, Object?>{
        'deviceId': 'd1',
        'attempt': 2,
        'mode': LogLevel.error,
        // Nomes reservados nao mascaram a gravidade nem o evento.
        'level': 'debug',
        'event': 'outro',
      }),
      '{"level":"warning","event":"policy_save_failed","deviceId":"d1","attempt":2,'
      '"mode":"error"}',
    );
  });
}
