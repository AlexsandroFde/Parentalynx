import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../../../core/errors/app_failure.dart';
import '../../../../../shared/domain/policy.dart';
import '../../../../../shared/widgets/feedback_views.dart';
import '../../../../../shared/widgets/form_widgets.dart';
import '../../../auth/presentation/elevation.dart';
import '../../../devices/domain/device.dart';
import '../../../devices/presentation/devices_providers.dart';
import '../policy_editor.dart';
import 'policy_sync_status.dart';

/// O que uma pagina de regras recebe para desenhar e editar: o aparelho, o rascunho e a
/// forma de altera-lo.
class RuleEditing {
  const RuleEditing({required this.device, required this.state, required this.editor});

  final Device device;
  final PolicyEditorState state;
  final PolicyEditor editor;

  /// Politica com as alteracoes locais.
  Policy get draft => state.draft;

  /// Aplica uma alteracao ao rascunho.
  void update(Policy Function(Policy policy) change) => editor.edit(change);
}

/// Salva o rascunho das regras, pedindo a senha administrativa se o servidor exigir, e mostra
/// o resultado. Devolve verdadeiro quando as regras foram enviadas.
Future<bool> savePolicyDraft(BuildContext context, WidgetRef ref, String deviceId) async {
  final PolicySaveResult result;
  try {
    result = await runElevated<PolicySaveResult>(
      context,
      ref,
      () => ref.read(policyEditorProvider(deviceId).notifier).save(),
    );
  } on CancelledFailure {
    return false;
  } on Object catch (error) {
    if (context.mounted) {
      showFailure(context, error);
    }
    return false;
  }
  if (!context.mounted) {
    return result == PolicySaveResult.saved;
  }
  switch (result) {
    case PolicySaveResult.saved:
      showAppSnackBar(
        context,
        'Regras enviadas. Aguardando o aparelho confirmar.',
        tone: Tone.success,
      );
      return true;
    case PolicySaveResult.conflictReloaded:
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            icon: const Icon(Icons.sync_problem_outlined),
            title: const Text('As regras mudaram'),
            content: const Text(
              'Outra sessão alterou as regras deste aparelho enquanto você editava. '
              'Carregamos a versão mais recente e suas alterações não foram aplicadas. '
              'Revise e refaça o que ainda for necessário.',
            ),
            actions: <Widget>[
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendi'),
              ),
            ],
          );
        },
      );
      return false;
  }
}

enum _LeaveChoice { save, discard, keepEditing }

Future<_LeaveChoice> _askBeforeLeaving(BuildContext context) async {
  final _LeaveChoice? choice = await showDialog<_LeaveChoice>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Salvar as alterações?'),
        content: const Text('Você alterou regras que ainda não foram enviadas ao aparelho.'),
        actionsOverflowButtonSpacing: AppSpacing.xs,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.keepEditing),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.discard),
            child: const Text('Descartar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.of(context).pop(_LeaveChoice.save),
            child: const Text('Salvar'),
          ),
        ],
      );
    },
  );
  return choice ?? _LeaveChoice.keepEditing;
}

/// Estrutura comum das paginas de edicao de regras.
///
/// Carrega a politica do aparelho em foco, mostra o estado de aplicacao no aparelho, a barra
/// de salvar quando ha alteracoes e pede confirmacao ao sair sem salvar.
class RuleEditorScaffold extends ConsumerWidget {
  const RuleEditorScaffold({
    required this.title,
    this.children,
    this.body,
    this.floatingActionButton,
    this.actions,
    this.showSyncStatus = true,
    super.key,
  }) : assert((children == null) != (body == null), 'Informe children ou body, e so um dos dois.');

  final String title;

  /// Conteudo em lista rolavel, com a margem padrao de pagina.
  final List<Widget> Function(BuildContext context, RuleEditing editing)? children;

  /// Corpo proprio (para listas longas construidas sob demanda).
  final Widget Function(BuildContext context, RuleEditing editing)? body;
  final Widget? Function(BuildContext context, RuleEditing editing)? floatingActionButton;
  final List<Widget> Function(BuildContext context, RuleEditing editing)? actions;
  final bool showSyncStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Device? device = ref.watch(selectedDeviceProvider);
    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const EmptyState(
          icon: Icons.phonelink_off_outlined,
          title: 'Nenhum aparelho vinculado',
          message: 'Vincule o aparelho da criança para definir as regras.',
        ),
      );
    }
    final AsyncValue<PolicyEditorState> value = ref.watch(policyEditorProvider(device.id));
    final PolicyEditorState? state = value.value;
    if (state == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: value.hasError
            ? FailureView(
                error: value.error!,
                onRetry: () => ref.invalidate(policyEditorProvider(device.id)),
              )
            : const LoadingView(message: 'Carregando as regras'),
      );
    }

    final PolicyEditor editor = ref.read(policyEditorProvider(device.id).notifier);
    final RuleEditing editing = RuleEditing(device: device, state: state, editor: editor);
    final bool dirty = state.isDirty;

    Future<void> save() => savePolicyDraft(context, ref, device.id);

    final List<Widget> Function(BuildContext, RuleEditing)? childrenBuilder = children;
    final Widget content = childrenBuilder != null
        ? PageBody(
            children: <Widget>[
              if (showSyncStatus) ...<Widget>[
                PolicySyncStatus(device: device),
                const SizedBox(height: AppSpacing.md),
              ],
              ...childrenBuilder(context, editing),
              const SizedBox(height: AppSpacing.xl),
            ],
          )
        : body!(context, editing);

    return PopScope<Object?>(
      canPop: !dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        final _LeaveChoice choice = await _askBeforeLeaving(context);
        if (!context.mounted) {
          return;
        }
        switch (choice) {
          case _LeaveChoice.keepEditing:
            return;
          case _LeaveChoice.discard:
            editor.discard();
            Navigator.of(context).pop();
          case _LeaveChoice.save:
            final bool saved = await savePolicyDraft(context, ref, device.id);
            if (saved && context.mounted) {
              Navigator.of(context).pop();
            }
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title), actions: actions?.call(context, editing)),
        body: content,
        floatingActionButton: floatingActionButton?.call(context, editing),
        bottomNavigationBar: dirty
            ? SaveBar(saving: state.saving, onSave: save, onDiscard: editor.discard)
            : null,
      ),
    );
  }
}

/// Barra fixa com as acoes de salvar e descartar, visivel so quando ha alteracoes.
class SaveBar extends StatelessWidget {
  const SaveBar({required this.saving, required this.onSave, required this.onDiscard, super.key});

  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
          child: Row(
            children: <Widget>[
              Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Alterações não salvas',
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(onPressed: saving ? null : onDiscard, child: const Text('Descartar')),
              const SizedBox(width: AppSpacing.xs),
              BusyButton(label: 'Salvar', busy: saving, expand: false, onPressed: onSave),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cartao com um interruptor principal: titulo, explicacao e o controle.
class SwitchCard extends StatelessWidget {
  const SwitchCard({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: icon == null ? null : Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}

/// Linha de interruptor dentro de um cartao com varias opcoes.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      contentPadding: EdgeInsets.zero,
    );
  }
}
