import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/data/local_prefs.dart';

/// Tempo em segundo plano depois do qual o painel pede a senha de novo.
enum AppLockTimeout {
  immediately(0, 'Imediatamente'),
  oneMinute(60, '1 minuto'),
  fiveMinutes(300, '5 minutos'),
  fifteenMinutes(900, '15 minutos');

  const AppLockTimeout(this.seconds, this.label);

  final int seconds;
  final String label;

  Duration get duration => Duration(seconds: seconds);

  static AppLockTimeout fromSeconds(int seconds) {
    for (final AppLockTimeout option in values) {
      if (option.seconds == seconds) {
        return option;
      }
    }
    return AppLockTimeout.oneMinute;
  }
}

/// Tempo de bloqueio do app escolhido pelo responsavel. O padrao e 1 minuto.
final NotifierProvider<AppLockTimeoutController, AppLockTimeout> appLockTimeoutProvider =
    NotifierProvider<AppLockTimeoutController, AppLockTimeout>(AppLockTimeoutController.new);

class AppLockTimeoutController extends Notifier<AppLockTimeout> {
  @override
  AppLockTimeout build() {
    Future<void>.microtask(_load);
    return AppLockTimeout.oneMinute;
  }

  Future<void> _load() async {
    final int? stored = await ref
        .read(localPrefsProvider)
        .readInt(LocalPrefKeys.appLockTimeoutSeconds);
    if (stored != null && ref.mounted) {
      state = AppLockTimeout.fromSeconds(stored);
    }
  }

  Future<void> set(AppLockTimeout timeout) async {
    state = timeout;
    await ref
        .read(localPrefsProvider)
        .writeInt(LocalPrefKeys.appLockTimeoutSeconds, timeout.seconds);
  }
}
