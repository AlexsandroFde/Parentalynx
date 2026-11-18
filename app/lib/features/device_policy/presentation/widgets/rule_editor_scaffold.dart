import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_sync/presentation/widgets/policy_sync_status_view.dart';
import '../editing/policy_section_state.dart';

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

Future<void> _showConflict(BuildContext context) {
  return showDialog<void>(
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
}

/// Estrutura comum das paginas de edicao de regras.
///
/// Mostra a secao carregada pelo BLoC [B] (qualquer BLoC de regras cujo estado seja
/// [PolicySectionState]), o estado de aplicacao no aparelho, a barra de salvar quando ha
/// alteracoes, os avisos de envio e de conflito, e pede confirmacao ao sair sem salvar.
///
/// Nao conhece os eventos de cada BLoC: recebe as acoes de salvar, descartar e tentar de novo.
class RuleEditorScaffold<B extends StateStreamable<PolicySectionState<T>>, T>
    extends StatefulWidget {
  const RuleEditorScaffold({
    required this.title,
    required this.device,
    required this.onSave,
    required this.onDiscard,
    required this.onRetry,
    this.children,
    this.body,
    this.floatingActionButton,
    this.actions,
    this.showSyncStatus = true,
    super.key,
  }) : assert((children == null) != (body == null), 'Informe children ou body, e so um dos dois.');

  final String title;

  /// Aparelho em edicao, para mostrar a confirmacao de aplicacao das regras.
  final ChildDevice device;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final VoidCallback onRetry;

  /// Conteudo em lista rolavel, com a margem padrao de pagina.
  final List<Widget> Function(BuildContext context, T draft)? children;

  /// Corpo proprio (para listas longas construidas sob demanda).
  final Widget Function(BuildContext context, T draft)? body;
  final Widget? Function(BuildContext context, T draft)? floatingActionButton;
  final List<Widget> Function(BuildContext context, T draft)? actions;
  final bool showSyncStatus;

  @override
  State<RuleEditorScaffold<B, T>> createState() => _RuleEditorScaffoldState<B, T>();
}

class _RuleEditorScaffoldState<B extends StateStreamable<PolicySectionState<T>>, T>
    extends State<RuleEditorScaffold<B, T>> {
  /// A pessoa escolheu "Salvar" ao sair: depois do envio aceito, a pagina fecha.
  bool _leaveAfterSave = false;

  bool _statusChanged(PolicySectionState<T> previous, PolicySectionState<T> current) {
    return current is PolicySectionEditing<T> &&
        (previous is! PolicySectionEditing<T> || previous.status != current.status);
  }

  void _onStatus(BuildContext context, PolicySectionState<T> state) {
    if (state is! PolicySectionEditing<T>) {
      return;
    }
    switch (state.status) {
      case SectionSaveStatus.saving:
        return;
      case SectionSaveStatus.saved:
        showAppSnackBar(
          context,
          'Regras enviadas. Aguardando o aparelho confirmar.',
          tone: Tone.success,
        );
        if (_leaveAfterSave) {
          _leaveAfterSave = false;
          Navigator.of(context).pop();
        }
      case SectionSaveStatus.conflict:
        _leaveAfterSave = false;
        _showConflict(context);
      case SectionSaveStatus.failed:
        _leaveAfterSave = false;
        final Object? failure = state.failure;
        if (failure != null) {
          showFailure(context, failure);
        }
      case SectionSaveStatus.idle:
        _leaveAfterSave = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<B, PolicySectionState<T>>(
      listenWhen: _statusChanged,
      listener: _onStatus,
      builder: (BuildContext context, PolicySectionState<T> state) {
        return switch (state) {
          PolicySectionLoading<T>() => Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: const LoadingView(message: 'Carregando as regras'),
          ),
          PolicySectionError<T>(:final failure) => Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: FailureView(error: failure, onRetry: widget.onRetry),
          ),
          PolicySectionEditing<T>() => _editor(context, state),
        };
      },
    );
  }

  Widget _editor(BuildContext context, PolicySectionEditing<T> state) {
    final bool dirty = state.isDirty;
    final List<Widget> Function(BuildContext, T)? childrenBuilder = widget.children;
    final Widget content = childrenBuilder != null
        ? PageBody(
            children: <Widget>[
              if (widget.showSyncStatus) ...<Widget>[
                PolicySyncStatusView(status: widget.device.policySync),
                const SizedBox(height: AppSpacing.md),
              ],
              ...childrenBuilder(context, state.draft),
              const SizedBox(height: AppSpacing.xl),
            ],
          )
        : widget.body!(context, state.draft);

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
            widget.onDiscard();
            Navigator.of(context).pop();
          case _LeaveChoice.save:
            _leaveAfterSave = true;
            widget.onSave();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: widget.actions?.call(context, state.draft),
        ),
        body: content,
        floatingActionButton: widget.floatingActionButton?.call(context, state.draft),
        bottomNavigationBar: dirty
            ? SaveBar(saving: state.isSaving, onSave: widget.onSave, onDiscard: widget.onDiscard)
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
