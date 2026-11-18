import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/child_layout.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../blocking/domain/usecases/grant_local_override.dart';
import '../../domain/entities/agent_status.dart';
import '../../domain/services/offline_access_code_rules.dart';
import '../bloc/child_device_status/child_device_status_bloc.dart';
import '../bloc/guardian_area/guardian_area_bloc.dart';

/// Area do responsavel no aparelho da crianca: autenticacao e operacoes administrativas.
///
/// Precisa, acima na arvore, do [GuardianAreaBloc] (rota da tela) e do
/// [ChildDeviceStatusBloc] (casca do modo crianca).
class GuardianAreaPage extends StatefulWidget {
  const GuardianAreaPage({super.key});

  @override
  State<GuardianAreaPage> createState() => _GuardianAreaPageState();
}

class _GuardianAreaPageState extends State<GuardianAreaPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  GuardianAreaBloc get _bloc => context.read<GuardianAreaBloc>();

  void _submit(bool codeMode) {
    FocusScope.of(context).unfocus();
    _bloc.add(
      codeMode
          ? GuardianAreaCodeSubmitted(_code.text)
          : GuardianAreaPasswordSubmitted(_password.text),
    );
  }

  Future<void> _unlink() async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Desvincular este aparelho?',
      message:
          'O controle parental deixa de valer aqui: os limites e os bloqueios são removidos. '
          'Para voltar a controlar este aparelho será preciso um novo código.',
      confirmLabel: 'Desvincular',
      destructive: true,
    );
    if (confirmed && mounted) {
      _bloc.add(const GuardianAreaUnlinkRequested());
    }
  }

  Future<void> _releaseOwner() async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Deixar de gerenciar o aparelho?',
      message:
          'O aparelho deixa de ser um dispositivo gerenciado. A desinstalação volta a ser '
          'possível e o bloqueio passa a depender das permissões do controle.',
      confirmLabel: 'Deixar de gerenciar',
      destructive: true,
    );
    if (confirmed && mounted) {
      _bloc.add(const GuardianAreaOwnershipReleased());
    }
  }

  Future<void> _removeAdmin() async {
    final bool confirmed = await confirmAction(
      context,
      title: 'Desativar o administrador?',
      message: 'Sem o administrador, o app pode ser desinstalado direto pelas configurações.',
      confirmLabel: 'Desativar',
    );
    if (confirmed && mounted) {
      _bloc.add(const GuardianAreaDeviceAdminRemoved());
    }
  }

  void _leave() {
    _bloc.add(const GuardianAreaLeft());
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(ChildPaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AgentStatus? status = context.select<ChildDeviceStatusBloc, AgentStatus?>(
      (ChildDeviceStatusBloc bloc) => bloc.state.statusOrNull,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Área do responsável')),
      body: SafeArea(
        child: BlocConsumer<GuardianAreaBloc, GuardianAreaState>(
          listener: (BuildContext context, GuardianAreaState state) {
            if (state is GuardianAreaUnlocked && state.action is ActionIdle) {
              // Acabou de entrar: os campos nao guardam a senha nem o codigo.
              _password.clear();
              _code.clear();
            }
            if (state is GuardianAreaUnlocked) {
              switch (state.action) {
                case ActionSucceeded(:final String message?):
                  showAppSnackBar(context, message, tone: Tone.success);
                case ActionFailed(:final failure):
                  showAppSnackBar(context, failure.message, tone: Tone.danger);
                case ActionIdle() || ActionRunning() || ActionSucceeded():
                  break;
              }
            }
          },
          listenWhen: (GuardianAreaState previous, GuardianAreaState current) {
            if (current is! GuardianAreaUnlocked) {
              return false;
            }
            return previous is! GuardianAreaUnlocked || previous.action != current.action;
          },
          builder: (BuildContext context, GuardianAreaState state) {
            return switch (state) {
              GuardianAreaUnlocked() => _AdminView(
                status: status,
                running: state.running,
                onGrant: (int minutes) => _bloc.add(GuardianAreaOverrideGranted(minutes)),
                onClearOverride: () => _bloc.add(const GuardianAreaOverrideCleared()),
                onPermissions: () => context.push(ChildPaths.permissions),
                onRequestAdmin: () => _bloc.add(const GuardianAreaDeviceAdminRequested()),
                onRemoveAdmin: _removeAdmin,
                onReleaseOwner: _releaseOwner,
                onUnlink: _unlink,
                onLeave: _leave,
              ),
              GuardianAreaLocked() => _AuthView(
                state: state,
                password: _password,
                code: _code,
                guardianName: status?.guardianName ?? '',
                onSubmit: () => _submit(state.codeMode),
                onToggleMode: () => _bloc.add(const GuardianAreaModeToggled()),
              ),
            };
          },
        ),
      ),
    );
  }
}

class _AuthView extends StatelessWidget {
  const _AuthView({
    required this.state,
    required this.password,
    required this.code,
    required this.guardianName,
    required this.onSubmit,
    required this.onToggleMode,
  });

  final GuardianAreaLocked state;
  final TextEditingController password;
  final TextEditingController code;
  final String guardianName;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final String who = guardianName.isEmpty ? 'o responsável' : guardianName;
    return ChildPageBody(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: <Widget>[
        ChildHeader(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Só para o responsável',
          message: 'Aqui $who pode liberar o uso, rever as permissões ou desvincular o aparelho.',
        ),
        const SizedBox(height: AppSpacing.xl),
        if (state.codeMode) ...<Widget>[
          TextField(
            controller: code,
            enabled: !state.verifying,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: offlineCodeLength,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (String value) => onSubmit(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 4),
            decoration: const InputDecoration(
              labelText: 'Código de acesso offline',
              counterText: '',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const NoticeBanner(
            title: 'Onde achar o código',
            message:
                'No aparelho do responsável, abra o ParentaLynx, entre em Aparelhos, escolha '
                'este aparelho e toque em "Código de acesso offline". O código tem 8 números '
                'e muda a cada minuto. Funciona sem internet.',
          ),
        ] else
          PasswordField(
            controller: password,
            enabled: !state.verifying,
            autofocus: true,
            onSubmitted: (String value) => onSubmit(),
          ),
        if (state.error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            liveRegion: true,
            child: NoticeBanner(message: state.error!, tone: Tone.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        BusyButton(
          label: state.codeMode ? 'Entrar com o código' : 'Entrar',
          busy: state.verifying,
          onPressed: onSubmit,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: state.verifying ? null : onToggleMode,
            child: Text(
              state.codeMode ? 'Usar a senha administrativa' : 'Usar o código de acesso offline',
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminView extends StatelessWidget {
  const _AdminView({
    required this.status,
    required this.running,
    required this.onGrant,
    required this.onClearOverride,
    required this.onPermissions,
    required this.onRequestAdmin,
    required this.onRemoveAdmin,
    required this.onReleaseOwner,
    required this.onUnlink,
    required this.onLeave,
  });

  final AgentStatus? status;
  final GuardianOperation? running;
  final ValueChanged<int> onGrant;
  final VoidCallback onClearOverride;
  final VoidCallback onPermissions;
  final VoidCallback onRequestAdmin;
  final VoidCallback onRemoveAdmin;
  final VoidCallback onReleaseOwner;
  final VoidCallback onUnlink;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AgentStatus? current = status;
    final bool busy = running != null;
    final bool overrideActive = current?.localOverrideActive ?? false;
    final bool owner = current?.permissions.deviceOwner ?? false;
    final bool admin = current?.permissions.deviceAdmin ?? false;
    final TextStyle? muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ChildPageBody(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: <Widget>[
        const NoticeBanner(
          tone: Tone.success,
          icon: Icons.lock_open_rounded,
          message:
              'Acesso do responsável liberado. Ele vale por 5 minutos. Ao terminar, toque em '
              '"Sair da área do responsável".',
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          title: 'Liberar o uso agora',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                overrideActive && current != null
                    ? 'O uso está liberado até ${formatClockMs(current.localOverrideUntilMs)}.'
                    : 'Libera o aparelho por alguns minutos, mesmo com o tempo esgotado ou em '
                          'horário de pausa. Funciona sem internet e fica registrado.',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.md),
              if (overrideActive)
                OutlinedButton(
                  onPressed: busy ? null : onClearOverride,
                  child: const Text('Encerrar a liberação'),
                )
              else
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final int minutes in GrantLocalOverride.options)
                      FilledButton.tonal(
                        onPressed: busy ? null : () => onGrant(minutes),
                        child: Text(formatMinutes(minutes)),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'Permissões do controle',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                current != null && current.needsAttention
                    ? 'Há permissões desligadas. O controle está incompleto.'
                    : 'Confira se o controle tem tudo de que precisa para funcionar.',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: busy ? null : onPermissions,
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Rever as permissões'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (owner)
          SectionCard(
            title: 'Dispositivo gerenciado',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Este aparelho é gerenciado pelo ParentaLynx: o Android impede abrir apps '
                  'bloqueados e desinstalar o controle. Para desinstalar o app é preciso '
                  'deixar de gerenciar antes.',
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: busy ? null : onReleaseOwner,
                  child: const Text('Deixar de gerenciar este aparelho'),
                ),
              ],
            ),
          )
        else
          SectionCard(
            title: 'Administrador do dispositivo',
            trailing: StatusPill(
              label: admin ? 'Ativo' : 'Desativado',
              tone: admin ? Tone.success : Tone.neutral,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Reforço opcional. Com ele ativo, para desinstalar o app é preciso desativar '
                  'o administrador antes, e o responsável é avisado.',
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: busy ? null : (admin ? onRemoveAdmin : onRequestAdmin),
                  child: Text(admin ? 'Desativar o administrador' : 'Ativar o administrador'),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'Desvincular este aparelho',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Remove o controle parental deste aparelho. Os relatórios já enviados '
                'continuam na conta do responsável.',
                style: muted,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: busy ? null : onUnlink,
                child: running == GuardianOperation.unlink
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Desvincular'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: TextButton.icon(
            onPressed: busy ? null : onLeave,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sair da área do responsável'),
          ),
        ),
      ],
    );
  }
}
