import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../auth/domain/guardian_account.dart';
import '../../auth/presentation/app_lock.dart';
import '../../auth/presentation/elevation.dart';
import '../../auth/presentation/session_controller.dart';
import '../data/api_account_repository.dart';

Duration? _noRetry(int retryCount, Object error) => null;

/// Sessoes da conta (aparelhos de responsaveis conectados).
final FutureProvider<List<GuardianSessionInfo>> guardianSessionsProvider =
    FutureProvider.autoDispose<List<GuardianSessionInfo>>(
      (Ref ref) => ref.watch(accountRepositoryProvider).listSessions(),
      retry: _noRetry,
    );

/// Aparelhos de responsaveis conectados a conta, com a opcao de encerrar cada sessao.
class SessionsPage extends ConsumerWidget {
  const SessionsPage({super.key});

  Future<void> _revoke(BuildContext context, WidgetRef ref, GuardianSessionInfo session) async {
    final String name = session.deviceName.isEmpty ? 'este aparelho' : session.deviceName;
    final bool confirmed = await confirmAction(
      context,
      title: 'Encerrar a sessão?',
      message: '"$name" perde o acesso à conta e precisa entrar de novo com a senha.',
      confirmLabel: 'Encerrar',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final bool? done = await guardedAction<bool>(context, ref, () async {
      await ref.read(accountRepositoryProvider).revokeSession(session.id);
      return true;
    }, successMessage: 'Sessão encerrada.');
    if (done ?? false) {
      ref.invalidate(guardianSessionsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GuardianSessionInfo>> sessions = ref.watch(guardianSessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sessões conectadas')),
      body: AsyncValueView<List<GuardianSessionInfo>>(
        value: sessions,
        onRetry: () => ref.invalidate(guardianSessionsProvider),
        data: (List<GuardianSessionInfo> list) => PageBody(
          children: <Widget>[
            const NoticeBanner(
              message:
                  'Cada aparelho em que um responsável entrou na conta aparece aqui. Encerre '
                  'as sessões que você não reconhece e troque a senha.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  for (int index = 0; index < list.length; index++) ...<Widget>[
                    if (index > 0) const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        list[index].current ? Icons.smartphone : Icons.smartphone_outlined,
                      ),
                      title: Text(
                        list[index].deviceName.isEmpty
                            ? 'Aparelho sem nome'
                            : list[index].deviceName,
                      ),
                      subtitle: Text(
                        list[index].current
                            ? 'Este aparelho'
                            : 'Último acesso ${formatRelativeMs(list[index].lastSeenAt)}',
                      ),
                      trailing: list[index].current
                          ? const StatusPill(label: 'Atual', tone: Tone.success)
                          : TextButton(
                              onPressed: () => _revoke(context, ref, list[index]),
                              child: const Text('Encerrar'),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloqueio do painel: quando pedir a senha administrativa de novo.
class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLockTimeout selected = ref.watch(appLockTimeoutProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bloqueio do painel')),
      body: PageBody(
        children: <Widget>[
          const NoticeBanner(
            icon: Icons.lock_outline,
            message:
                'O painel pede a senha administrativa sempre que o app é aberto e quando ele '
                'volta do segundo plano depois do tempo escolhido. Assim, quem pegar o seu '
                'aparelho desbloqueado não consegue mudar as regras.',
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionCard(
            title: 'Pedir a senha de novo após',
            padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
            child: RadioGroup<AppLockTimeout>(
              groupValue: selected,
              onChanged: (AppLockTimeout? value) {
                if (value != null) {
                  ref.read(appLockTimeoutProvider.notifier).set(value);
                }
              },
              child: Column(
                children: <Widget>[
                  for (final AppLockTimeout option in AppLockTimeout.values)
                    RadioListTile<AppLockTimeout>(
                      value: option,
                      title: Text(option.label),
                      subtitle: option == AppLockTimeout.immediately
                          ? const Text('Bloqueia sempre que você sai do app')
                          : null,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: () => ref.read(guardianSessionProvider.notifier).lockNow(),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Bloquear agora'),
          ),
        ],
      ),
    );
  }
}
