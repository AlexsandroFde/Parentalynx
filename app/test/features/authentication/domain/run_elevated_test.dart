import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/errors/app_failure.dart';
import 'package:parentalynx/core/result/result.dart';
import 'package:parentalynx/features/authentication/domain/usecases/run_elevated.dart';

import '../../../support/fakes.dart';

void main() {
  const ApiFailure elevationRequired = ApiFailure(
    status: 403,
    code: 'elevation_required',
    message: 'Confirme a senha.',
  );

  test('operacao aceita de primeira nao pede a senha', () async {
    final FakeElevationPrompter prompter = FakeElevationPrompter();
    final Result<int> result = await RunElevated(prompter)<int>(() async => const Ok<int>(7));

    expect(result, const Ok<int>(7));
    expect(prompter.requests, 0);
  });

  test('pede a senha quando o servidor exige e repete a operacao uma vez', () async {
    final FakeElevationPrompter prompter = FakeElevationPrompter();
    int calls = 0;
    final Result<int> result = await RunElevated(prompter)<int>(() async {
      calls++;
      return calls == 1 ? const Err<int>(elevationRequired) : const Ok<int>(7);
    });

    expect(result, const Ok<int>(7));
    expect(prompter.requests, 1);
    expect(calls, 2);
  });

  test('desistir do pedido de senha devolve cancelamento sem repetir', () async {
    final FakeElevationPrompter prompter = FakeElevationPrompter(accept: false);
    int calls = 0;
    final Result<int> result = await RunElevated(prompter)<int>(() async {
      calls++;
      return const Err<int>(elevationRequired);
    });

    expect(result.failureOrNull, isA<CancelledFailure>());
    expect(calls, 1);
  });

  test('outras falhas passam direto, sem pedir a senha', () async {
    final FakeElevationPrompter prompter = FakeElevationPrompter();
    final Result<int> result = await RunElevated(prompter)<int>(
      () async => const Err<int>(NetworkFailure()),
    );

    expect(result, const Err<int>(NetworkFailure()));
    expect(prompter.requests, 0);
  });
}
