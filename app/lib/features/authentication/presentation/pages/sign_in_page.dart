import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/guardian_entry/guardian_entry_bloc.dart';

/// Porta de entrada do modo responsavel: criar conta, entrar ou voltar para a escolha de modo.
///
/// Le o aviso de sessao encerrada do [AuthBloc] e o servidor do [GuardianEntryBloc].
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthState session = context.watch<AuthBloc>().state;
    final String? notice = session is AuthSignedOut ? session.notice : null;
    return BlocConsumer<GuardianEntryBloc, GuardianEntryState>(
      listenWhen: (GuardianEntryState previous, GuardianEntryState current) {
        return previous.roleReset != current.roleReset;
      },
      listener: (BuildContext context, GuardianEntryState state) {
        if (state.roleReset case ActionFailed(:final failure)) {
          showFailure(context, failure);
        }
      },
      builder: (BuildContext context, GuardianEntryState state) {
        final bool changingMode = state.roleReset.isRunning;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            size: 34,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text('Painel do responsável', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Crie a conta da família para definir limites, escolher os aplicativos '
                        'permitidos e acompanhar os relatórios. Se a conta já existe, entre '
                        'com ela.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (notice != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        NoticeBanner(message: notice, tone: Tone.warning),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton.icon(
                        onPressed: () => context.push(GuardianPaths.register),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Criar conta'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: () => context.push(GuardianPaths.login),
                        icon: const Icon(Icons.login),
                        label: const Text('Já tenho conta'),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _Step(
                        number: '1',
                        text: 'Crie a conta e uma senha administrativa forte.',
                      ),
                      const _Step(
                        number: '2',
                        text: 'Gere um código de vinculação e digite no aparelho da criança.',
                      ),
                      const _Step(number: '3', text: 'Confirme o vínculo aqui e defina as regras.'),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Servidor: ${state.serverAddress}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: TextButton.icon(
                          onPressed: changingMode
                              ? null
                              : () => context.read<GuardianEntryBloc>().add(
                                  const GuardianEntryRoleResetRequested(),
                                ),
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('Voltar para a escolha de modo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text(number, style: theme.textTheme.labelLarge),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
