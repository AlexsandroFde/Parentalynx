import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/security/totp.dart';
import 'package:parentalynx/features/child_device/domain/usecases/compute_offline_access_code.dart';
import 'package:parentalynx/features/child_device/presentation/bloc/offline_code/offline_code_bloc.dart';

import '../../../support/fakes.dart';

void main() {
  const String secret = 'JBSWY3DPEHPK3PXP';

  test('calcula o codigo do momento e a contagem ate ele mudar', () async {
    // Dez segundos depois da virada do minuto.
    final FakeClock clock = FakeClock(DateTime(2026, 11, 17, 15, 30, 10));
    final OfflineCodeBloc bloc = OfflineCodeBloc(
      secret: secret,
      compute: const ComputeOfflineAccessCode(),
      clock: clock,
      tick: const Duration(milliseconds: 5),
    );
    addTearDown(bloc.close);

    expect(bloc.state.code.code, const Totp().generate(secret, clock.now().millisecondsSinceEpoch));
    expect(bloc.state.code.secondsRemaining, 50);

    bloc.add(const OfflineCodeStarted());
    clock.advance(const Duration(seconds: 50));
    await bloc.stream.first;

    // Virou o minuto: codigo novo e contagem cheia.
    expect(bloc.state.code.code, const Totp().generate(secret, clock.now().millisecondsSinceEpoch));
    expect(bloc.state.code.secondsRemaining, 60);
  });

  test('segredo invalido vira um codigo invalido, sem erro', () {
    final OfflineCodeBloc bloc = OfflineCodeBloc(
      secret: 'não é base32!',
      compute: const ComputeOfflineAccessCode(),
      clock: FakeClock(),
    );
    addTearDown(bloc.close);

    expect(bloc.state.code.isValid, isFalse);
  });
}
