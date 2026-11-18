import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/time/clock.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../authentication/domain/entities/guardian_session.dart';
import '../bloc/sessions/sessions_bloc.dart';
import '../texts/settings_texts.dart';

/// Sessoes da conta (aparelhos de responsaveis conectados), com a opcao de encerrar cada uma.
///
/// Espera um [SessionsBloc] acima na arvore.
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  Future<void> _revoke(BuildContext context, GuardianSessionInfo session) async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Encerrar a sessão?',
      message:
          '"${sessionNameForRevoke(session)}" perde o acesso à conta e precisa entrar de novo '
          'com a senha.',
      confirmLabel: 'Encerrar',
      destructive: true,
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
        showFailure(context, failure);
      case ActionIdle() || ActionRunning():
        break;
    }
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
          body: switch (state) {
            SessionsLoading() => const LoadingView(),
            SessionsError(:final failure) => FailureView(
              error: failure,
              onRetry: () => context.read<SessionsBloc>().add(const SessionsLoadRequested()),
            ),
            SessionsLoaded(:final List<GuardianSessionInfo> sessions) => _SessionsList(
              sessions: sessions,
              onRevoke: (GuardianSessionInfo session) => _revoke(context, session),
            ),
          },
        );
      },
    );
  }
}

class _SessionsList extends StatelessWidget {
  const _SessionsList({required this.sessions, required this.onRevoke});

  final List<GuardianSessionInfo> sessions;
  final ValueChanged<GuardianSessionInfo> onRevoke;

  @override
  Widget build(BuildContext context) {
    final DateTime now = context.read<Clock>().now();
    return PageBody(
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
              for (int index = 0; index < sessions.length; index++) ...<Widget>[
                if (index > 0) const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    sessions[index].current ? Icons.smartphone : Icons.smartphone_outlined,
                  ),
                  title: Text(sessionTitle(sessions[index])),
                  subtitle: Text(sessionSubtitle(sessions[index], now: now)),
                  trailing: sessions[index].current
                      ? const StatusPill(label: 'Atual', tone: Tone.success)
                      : TextButton(
                          onPressed: () => onRevoke(sessions[index]),
                          child: const Text('Encerrar'),
                        ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
