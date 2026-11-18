import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../authentication/domain/entities/guardian_session.dart';
import '../../../authentication/presentation/widgets/auth_widgets.dart';
import '../bloc/sessions/sessions_bloc.dart';
import '../texts/settings_texts.dart';

/// Sessoes da conta (celulares de responsaveis conectados), com a opcao de encerrar cada uma.
///
/// Espera um [SessionsBloc] acima na arvore.
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  Future<void> _revoke(BuildContext context, GuardianSessionInfo session) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Encerrar a sessão?',
      message:
          '"${sessionNameForRevoke(session)}" perde o acesso à conta e precisa entrar de novo '
          'com a senha.',
      consequence: 'Se você não reconhece esse aparelho, troque também a senha administrativa.',
      confirmLabel: 'Encerrar sessão',
      destructive: true,
      icon: AppIcons.signOut,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    context.read<SessionsBloc>().add(SessionRevokeRequested(session.id));
  }

  void _onAction(BuildContext context, SessionsState state) {
    if (state is! SessionsLoaded) {
      return;
    }
    switch (state.action) {
      case ActionSucceeded(:final String? message):
        if (message != null) {
          showAppSnackBar(context, message, tone: Tone.success);
        }
      case ActionFailed(:final failure):
        showAppSnackBar(
          context,
          'Não foi possível encerrar a sessão. Ela continua ativa. ${failure.message}',
          tone: Tone.danger,
        );
      case ActionIdle() || ActionRunning():
        break;
    }
  }

  void _reload(BuildContext context) {
    context.read<SessionsBloc>().add(const SessionsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SessionsBloc, SessionsState>(
      listenWhen: (SessionsState previous, SessionsState current) {
        return current is SessionsLoaded &&
            (previous is! SessionsLoaded || previous.action != current.action);
      },
      listener: _onAction,
      builder: (BuildContext context, SessionsState state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Sessões conectadas')),
          body: StateSwitcher(
            child: switch (state) {
              SessionsLoading() => const KeyedSubtree(
                key: ValueKey<String>('carregando'),
                child: _SessionsSkeleton(),
              ),
              SessionsError(:final failure) => KeyedSubtree(
                key: const ValueKey<String>('erro'),
                child: ErrorState.fromError(
                  failure,
                  subject: 'as sessões',
                  onRetry: () => _reload(context),
                ),
              ),
              SessionsLoaded() => KeyedSubtree(
                key: const ValueKey<String>('lista'),
                child: _SessionsList(
                  state: state,
                  onRevoke: (GuardianSessionInfo session) => _revoke(context, session),
                ),
              ),
            },
          ),
        );
      },
    );
  }
}

class _SessionsSkeleton extends StatelessWidget {
  const _SessionsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppPageBody(children: <Widget>[SkeletonListGroup(rows: 2)]);
  }
}

class _SessionsList extends StatelessWidget {
  const _SessionsList({required this.state, required this.onRevoke});

  final SessionsLoaded state;
  final ValueChanged<GuardianSessionInfo> onRevoke;

  @override
  Widget build(BuildContext context) {
    final DateTime now = context.read<Clock>().now();
    // Este aparelho primeiro; os outros em seguida, na ordem do servidor.
    final List<GuardianSessionInfo> sessions = <GuardianSessionInfo>[
      ...state.sessions.where((GuardianSessionInfo s) => s.current),
      ...state.sessions.where((GuardianSessionInfo s) => !s.current),
    ];
    final bool busy = state.action.isRunning;
    return AppPageBody(
      children: <Widget>[
        AppSection(
          title: 'Celulares com acesso à conta',
          subtitle:
              'Cada celular em que um responsável entrou na conta aparece aqui. Encerre as '
              'sessões que você não reconhece.',
          child: AppListGroup(
            footer: sessions.length == 1
                ? 'Só este aparelho está conectado à conta.'
                : 'Quem tiver a sessão encerrada precisa entrar de novo com a senha.',
            children: <Widget>[
              for (final GuardianSessionInfo session in sessions)
                AppListRow(
                  leading: AppIconTile(
                    icon: AppIcons.device,
                    tone: session.current ? Tone.success : Tone.neutral,
                  ),
                  title: sessionTitle(session),
                  subtitle: sessionSubtitle(session, now: now),
                  trailing: session.current
                      ? const StatusBadge(label: 'Atual', tone: Tone.success)
                      : state.revokingId == session.id
                      ? const InlineProgress(label: 'Encerrando a sessão')
                      : AppButton.tertiary(
                          label: 'Encerrar',
                          size: AppButtonSize.compact,
                          onPressed: busy ? null : () => onRevoke(session),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
