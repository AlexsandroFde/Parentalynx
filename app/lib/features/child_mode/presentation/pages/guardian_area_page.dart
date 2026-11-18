import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/bloc/action_status.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/time/formatters.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../../blocking/domain/usecases/grant_local_override.dart';
import '../../domain/entities/agent_status.dart';
import '../../domain/services/offline_access_code_rules.dart';
import '../bloc/child_device_status/child_device_status_bloc.dart';
import '../bloc/guardian_area/guardian_area_bloc.dart';

/// Area do responsavel no aparelho da crianca: autenticacao e operacoes administrativas.
///
/// Tudo aqui exige a senha do responsavel (ou o codigo de acesso offline): nada desta tela
/// deixa a crianca desligar ou contornar as regras. As operacoes que retiram protecao pedem
/// confirmacao e dizem a consequencia.
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
    final GuardianAreaState state = _bloc.state;
    final bool viaCode = state is GuardianAreaUnlocked && state.codeMode;
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Desvincular este aparelho?',
      message:
          'O controle parental deixa de valer aqui: os limites e os bloqueios são removidos.'
          '${viaCode ? ' Como a entrada foi pelo código offline, o app do responsável fica sabendo quando este aparelho tiver internet.' : ''}',
      consequence: 'Para controlar este aparelho de novo, será preciso um novo código.',
      confirmLabel: 'Desvincular',
      destructive: true,
      icon: AppIcons.unlink,
    );
    if (confirmed && mounted) {
      _bloc.add(const GuardianAreaUnlinkRequested());
    }
  }

  Future<void> _releaseOwner() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Deixar de gerenciar o aparelho?',
      message:
          'O aparelho deixa de ser um dispositivo gerenciado. A desinstalação volta a ser '
          'possível e o bloqueio passa a depender das permissões do controle.',
      consequence:
          'Para gerenciar de novo, será preciso configurar o aparelho do zero, sem contas.',
      confirmLabel: 'Deixar de gerenciar',
      destructive: true,
    );
    if (confirmed && mounted) {
      _bloc.add(const GuardianAreaOwnershipReleased());
    }
  }

  Future<void> _removeAdmin() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Desativar o administrador?',
      message: 'Sem o administrador, o app pode ser desinstalado direto pelas configurações.',
      consequence: 'Dá para ativar de novo depois, aqui mesmo.',
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
            return StateSwitcher(
              child: switch (state) {
                GuardianAreaUnlocked() => KeyedSubtree(
                  key: const ValueKey<String>('liberada'),
                  child: _AdminView(
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
                ),
                GuardianAreaLocked() => KeyedSubtree(
                  key: const ValueKey<String>('trancada'),
                  child: _AuthView(
                    state: state,
                    password: _password,
                    code: _code,
                    guardianName: status?.guardianName ?? '',
                    onSubmit: () => _submit(state.codeMode),
                    onToggleMode: () => _bloc.add(const GuardianAreaModeToggled()),
                  ),
                ),
              },
            );
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
    final String? error = state.error;
    return ChildPageBody(
      children: <Widget>[
        ChildHeader(
          icon: AppIcons.lock,
          tone: Tone.neutral,
          title: 'Só para o responsável',
          message:
              'Aqui $who pode liberar o uso, rever as permissões ou desvincular o aparelho. '
              'Para entrar, é preciso a senha do responsável.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Chegou aqui sem querer? É só voltar.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (state.codeMode) ...<Widget>[
          AppTextField(
            controller: code,
            enabled: !state.verifying,
            autofocus: true,
            label: 'Código de acesso offline',
            hint: '8 números',
            helper: 'Muda a cada minuto e funciona sem internet.',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: offlineCodeLength,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            prefixIcon: AppIcons.pinCode,
            onSubmitted: (String value) => onSubmit(),
            style: context.text.headlineSmall?.copyWith(letterSpacing: AppSpacing.xs),
          ),
          const SizedBox(height: AppSpacing.md),
          const AppBanner(
            icon: AppIcons.help,
            title: 'Onde achar o código',
            message:
                'No aparelho do responsável, abra o ParentaLynx, entre em Aparelhos, escolha '
                'este aparelho e toque em "Código de acesso offline".',
          ),
        ] else
          AppPasswordField(
            controller: password,
            enabled: !state.verifying,
            autofocus: true,
            helper: 'A mesma senha do app do responsável.',
            onSubmitted: (String value) => onSubmit(),
          ),
        if (error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppBanner(tone: Tone.danger, message: error, liveRegion: true),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton.primary(
          label: state.codeMode ? 'Entrar com o código' : 'Entrar',
          busy: state.verifying,
          expand: true,
          onPressed: onSubmit,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton.tertiary(
          label: state.codeMode ? 'Usar a senha administrativa' : 'Usar o código de acesso offline',
          onPressed: state.verifying ? null : onToggleMode,
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

  /// Acao de um botao: desabilitada enquanto outra operacao roda.
  VoidCallback? _action(GuardianOperation operation, VoidCallback callback) {
    return running == null || running == operation ? callback : null;
  }

  @override
  Widget build(BuildContext context) {
    final AgentStatus? current = status;
    final bool overrideActive = current?.localOverrideActive ?? false;
    final bool owner = current?.permissions.deviceOwner ?? false;
    final bool admin = current?.permissions.deviceAdmin ?? false;
    final bool attention = current?.needsAttention ?? false;
    final TextStyle? muted = context.text.bodyMedium?.copyWith(color: context.colors.textSecondary);
    return ChildPageBody(
      children: <Widget>[
        const AppBanner(
          tone: Tone.success,
          icon: AppIcons.unlock,
          title: 'Acesso liberado por 5 minutos',
          message: 'Ao terminar, toque em "Sair da área do responsável".',
        ),
        const SectionGap(),
        AppSection(
          title: 'Liberar o uso agora',
          child: AppPanel(
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
                  AppButton.secondary(
                    label: 'Encerrar a liberação',
                    busy: running == GuardianOperation.clearOverride,
                    onPressed: _action(GuardianOperation.clearOverride, onClearOverride),
                  )
                else
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final int minutes in GrantLocalOverride.options)
                        AppButton.secondary(
                          label: formatMinutes(minutes),
                          icon: AppIcons.extraTime,
                          size: AppButtonSize.compact,
                          onPressed: running == null ? () => onGrant(minutes) : null,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SectionGap(),
        AppSection(
          title: 'Proteção deste aparelho',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppListGroup(
                children: <Widget>[
                  AppListRow(
                    leading: AppIconTile(
                      icon: AppIcons.protection,
                      tone: attention ? Tone.warning : Tone.info,
                    ),
                    title: 'Permissões do controle',
                    subtitle: attention
                        ? 'Há permissões desligadas. O controle está incompleto.'
                        : 'Confira se o controle tem tudo de que precisa.',
                    onTap: running == null ? onPermissions : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (owner)
                _ProtectionPanel(
                  title: 'Dispositivo gerenciado',
                  badge: const StatusBadge(label: 'Ativo', tone: Tone.success),
                  text:
                      'O Android impede abrir apps bloqueados e desinstalar o controle. Para '
                      'desinstalar o app é preciso deixar de gerenciar antes.',
                  action: AppButton.secondary(
                    label: 'Deixar de gerenciar este aparelho',
                    busy: running == GuardianOperation.releaseOwnership,
                    onPressed: _action(GuardianOperation.releaseOwnership, onReleaseOwner),
                  ),
                )
              else
                _ProtectionPanel(
                  title: 'Administrador do dispositivo',
                  badge: StatusBadge(
                    label: admin ? 'Ativo' : 'Desativado',
                    tone: admin ? Tone.success : Tone.neutral,
                  ),
                  text:
                      'Reforço opcional. Com ele ativo, para desinstalar o app é preciso '
                      'desativar o administrador antes, e o responsável é avisado.',
                  action: admin
                      ? AppButton.secondary(
                          label: 'Desativar o administrador',
                          busy: running == GuardianOperation.removeDeviceAdmin,
                          onPressed: _action(GuardianOperation.removeDeviceAdmin, onRemoveAdmin),
                        )
                      : AppButton.secondary(
                          label: 'Ativar o administrador',
                          busy: running == GuardianOperation.requestDeviceAdmin,
                          onPressed: _action(GuardianOperation.requestDeviceAdmin, onRequestAdmin),
                        ),
                ),
            ],
          ),
        ),
        const SectionGap(),
        AppSection(
          title: 'Desvincular este aparelho',
          child: AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Remove o controle parental deste aparelho. Os relatórios já enviados '
                  'continuam na conta do responsável.',
                  style: muted,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton.danger(
                  label: 'Desvincular',
                  icon: AppIcons.unlink,
                  busy: running == GuardianOperation.unlink,
                  onPressed: _action(GuardianOperation.unlink, onUnlink),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton.tertiary(
          label: 'Sair da área do responsável',
          icon: AppIcons.signOut,
          onPressed: running == null ? onLeave : null,
        ),
      ],
    );
  }
}

/// Reforco de protecao do aparelho: titulo com o estado, explicacao e a acao.
class _ProtectionPanel extends StatelessWidget {
  const _ProtectionPanel({
    required this.title,
    required this.badge,
    required this.text,
    required this.action,
  });

  final String title;
  final Widget badge;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(title, style: context.text.titleSmall),
              badge,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(text, style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          action,
        ],
      ),
    );
  }
}
