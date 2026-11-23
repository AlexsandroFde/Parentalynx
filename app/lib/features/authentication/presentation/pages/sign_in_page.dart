import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/guardian_session.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/guardian_entry/guardian_entry_bloc.dart';
import '../widgets/auth_widgets.dart';

/// Porta de entrada do modo responsavel: criar conta, entrar e voltar para a escolha do papel
/// do aparelho.
///
/// Le o aviso de sessao encerrada do [AuthBloc] e a volta para a escolha do papel do
/// [GuardianEntryBloc].
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  static const List<String> _steps = <String>[
    'Crie a conta e uma senha administrativa forte.',
    'Gere um código de vinculação e digite no aparelho da criança.',
    'Confirme o vínculo aqui e defina as regras.',
  ];

  @override
  Widget build(BuildContext context) {
    final AuthState session = context.watch<AuthBloc>().state;
    return BlocConsumer<GuardianEntryBloc, GuardianEntryState>(
      listenWhen: (GuardianEntryState previous, GuardianEntryState current) {
        return previous.roleReset != current.roleReset;
      },
      listener: (BuildContext context, GuardianEntryState state) {
        if (state.roleReset case ActionFailed(:final failure)) {
          showAppSnackBar(
            context,
            'Não foi possível trocar o papel deste aparelho. ${failure.message}',
            tone: Tone.danger,
          );
        }
      },
      builder: (BuildContext context, GuardianEntryState state) {
        final bool changingRole = state.roleReset.isRunning;
        return Scaffold(
          body: SafeArea(
            child: AppPageBody(
              maxWidth: AppSpacing.maxFormWidth,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xxl,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              children: <Widget>[
                const Align(alignment: AlignmentDirectional.centerStart, child: BrandLockup()),
                const SizedBox(height: AppSpacing.xxl),
                const AppPageHeader(
                  eyebrow: 'Aparelho do responsável',
                  title: 'Painel do responsável',
                  subtitle:
                      'Crie a conta da família para definir limites, escolher os aplicativos '
                      'permitidos e acompanhar os relatórios.',
                ),
                if (session is AuthSignedOut && session.notice != null) ...<Widget>[
                  _SessionNotice(reason: session.reason, notice: session.notice!),
                  const SizedBox(height: AppSpacing.xl),
                ],
                AppButton.primary(
                  label: 'Criar conta',
                  icon: AppIcons.personAdd,
                  expand: true,
                  onPressed: () => context.push(GuardianPaths.register),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton.secondary(
                  label: 'Já tenho conta',
                  icon: AppIcons.signIn,
                  expand: true,
                  onPressed: () => context.push(GuardianPaths.login),
                ),
                const SectionGap(),
                const AppSection(
                  title: 'Como começar',
                  child: StepList(steps: _steps),
                ),
                const SectionGap(),
                AppSection(
                  title: 'Este aparelho',
                  child: AppListGroup(
                    children: <Widget>[
                      AppListRow(
                        leading: const AppIconTile(icon: AppIcons.swap, tone: Tone.neutral),
                        title: 'Trocar o papel deste aparelho',
                        subtitle: 'Volta para a escolha entre responsável e criança.',
                        trailing: changingRole ? const InlineProgress() : null,
                        onTap: changingRole
                            ? null
                            : () => context.read<GuardianEntryBloc>().add(
                                const GuardianEntryRoleResetRequested(),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Por que a sessao anterior terminou: sessao encerrada (atencao) ou conta excluida
/// (confirmacao do que foi pedido).
class _SessionNotice extends StatelessWidget {
  const _SessionNotice({required this.reason, required this.notice});

  final SessionEndReason? reason;
  final String notice;

  @override
  Widget build(BuildContext context) {
    final bool deleted = reason == SessionEndReason.accountDeleted;
    return AppBanner(
      tone: deleted ? Tone.success : Tone.warning,
      title: deleted ? 'Conta excluída' : 'Sessão encerrada',
      message: notice,
      liveRegion: true,
    );
  }
}
