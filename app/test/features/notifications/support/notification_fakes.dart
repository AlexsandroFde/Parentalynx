import 'package:mocktail/mocktail.dart';
import 'package:parentalynx/core/utils/observable_value.dart';
import 'package:parentalynx/features/authentication/domain/entities/guardian_account.dart';
import 'package:parentalynx/features/authentication/domain/repositories/i_current_account_repository.dart';
import 'package:parentalynx/features/notifications/domain/repositories/i_alerts_repository.dart';
import 'package:parentalynx/features/notifications/domain/repositories/i_notification_prompt_repository.dart';
import 'package:parentalynx/features/notifications/domain/services/i_notification_permission_service.dart';

// Dubles das notificacoes usados nos testes de dominio e de BLoC.

class MockAlertsRepository extends Mock implements IAlertsRepository {}

class MockNotificationPermissionService extends Mock implements INotificationPermissionService {}

class MockNotificationPromptRepository extends Mock implements INotificationPromptRepository {}

/// Conta do painel em memoria.
class FakeCurrentAccount implements ICurrentAccountRepository {
  FakeCurrentAccount([GuardianAccount? initial])
    : _account = ObservableValue<GuardianAccount?>.seeded(initial);

  final ObservableValue<GuardianAccount?> _account;

  @override
  GuardianAccount? get currentAccount => _account.valueOrNull;

  @override
  Stream<GuardianAccount?> watchAccount() => _account.stream;

  @override
  void replaceAccount(GuardianAccount account) => _account.add(account);

  void signOut() => _account.add(null);
}

/// Conta de exemplo com algumas preferencias de notificacao.
GuardianAccount accountWithPrefs(Map<String, bool> prefs) {
  return GuardianAccount(
    id: 'g1',
    email: 'maria@exemplo.com',
    displayName: 'Maria Souza',
    createdAt: 1,
    notificationPrefs: prefs,
  );
}
