import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../../child_device/domain/entities/child_device.dart';
import '../../../device_sync/domain/entities/policy_sync_status.dart';
import '../../../device_sync/presentation/widgets/policy_sync_status_view.dart';
import '../editing/policy_section_state.dart';

/// Estado de aplicacao das regras considerando a versao que a tela ja conhece.
///
/// Logo depois de salvar, a lista de aparelhos ainda pode trazer a versao anterior. Se a tela
/// conhece uma versao mais nova ([knownVersion]), ela ainda nao foi confirmada pelo aparelho:
/// a regra aparece como pendente, nunca como aplicada antes da confirmacao.
PolicySyncStatus effectivePolicySync(ChildDevice device, int knownVersion) {
  final PolicySyncStatus sync = device.policySync;
  if (knownVersion <= sync.serverVersion) {
    return sync;
  }
  return PolicySyncStatus(
    serverVersion: knownVersion,
    appliedVersion: sync.appliedVersion,
    deviceOnline: sync.deviceOnline,
    appliedAt: sync.appliedAt,
  );
}

/// Contexto de uma tela de regras: de quem e qual aparelho ("JOAO · MOTO G54").
String deviceContextLabel(ChildDevice device) {
  final String model = device.model.trim();
  return model.isEmpty ? device.displayName : '${device.displayName} · $model';
}

/// Cabecalho das telas de regras: a crianca e o aparelho, o nome da regra e o que ela faz.
class RuleEditorHeader extends StatelessWidget {
  const RuleEditorHeader({required this.device, required this.title, this.description, super.key});

  final ChildDevice device;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(eyebrow: deviceContextLabel(device), title: title, subtitle: description);
  }
}

/// Distancia de rolagem a partir da qual o titulo da pagina aparece na barra superior (o
/// titulo grande do cabecalho ja saiu da tela).
const double _titleScrollOffset = AppSpacing.xxxl + AppSpacing.sm;

enum _LeaveChoice { save, discard, keepEditing }

/// Estrutura comum das paginas de edicao de regras (padrao "Editores de regras" do Design
/// System).
///
/// Mostra a secao carregada pelo BLoC [B] (qualquer BLoC de regras cujo estado seja
/// [PolicySectionState]) com o cabecalho da crianca e do aparelho, o estado de aplicacao no
/// aparelho, a barra fixa de salvar quando ha alteracoes, os avisos de falha e de conflito (com
/// a opcao de refazer as alteracoes) e pede confirmacao ao sair sem salvar.
///
/// Nao conhece os eventos de cada BLoC: recebe as acoes de salvar, descartar, tentar de novo e
/// refazer as alteracoes recusadas.
class RuleEditorScaffold<B extends StateStreamable<PolicySectionState<T>>, T>
    extends StatefulWidget {
  const RuleEditorScaffold({
    required this.title,
    required this.device,
    required this.onSave,
    required this.onDiscard,
    required this.onRetry,
    this.description,
    this.helpTopics,
    this.onRestoreRejected,
    this.children,
    this.slivers,
    this.floatingActionButton,
    this.actions,
    this.showSyncStatus = true,
    super.key,
  }) : assert(
         (children == null) != (slivers == null),
         'Informe children ou slivers, e so um dos dois.',
       );

  final String title;

  /// O que a regra faz, em uma frase, abaixo do titulo.
  final String? description;

  /// Aparelho em edicao, para mostrar de quem sao as regras e a confirmacao de aplicacao.
  final ChildDevice device;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final VoidCallback onRetry;

  /// Ajuda da tela, aberta pelo botao "?" da barra superior.
  final List<HelpTopic>? helpTopics;

  /// Refaz as alteracoes recusadas por um conflito. Nulo esconde a opcao.
  final VoidCallback? onRestoreRejected;

  /// Conteudo da pagina, abaixo do cabecalho e do estado de aplicacao.
  final List<Widget> Function(BuildContext context, T draft)? children;

  /// Conteudo em slivers, para listas longas construidas sob demanda.
  final List<Widget> Function(BuildContext context, T draft)? slivers;
  final Widget? Function(BuildContext context, T draft)? floatingActionButton;
  final List<Widget> Function(BuildContext context, T draft)? actions;
  final bool showSyncStatus;

  @override
  State<RuleEditorScaffold<B, T>> createState() => _RuleEditorScaffoldState<B, T>();
}

class _RuleEditorScaffoldState<B extends StateStreamable<PolicySectionState<T>>, T>
    extends State<RuleEditorScaffold<B, T>> {
  final ScrollController _scroll = ScrollController();

  /// A pessoa escolheu "Salvar e sair": depois do envio aceito, a pagina fecha.
  bool _leaveAfterSave = false;

  /// O titulo grande ja rolou para fora da tela: a barra superior mostra o titulo.
  bool _titleInBar = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get _childName => widget.device.displayName;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0) {
      final bool inBar = notification.metrics.pixels > _titleScrollOffset;
      if (inBar != _titleInBar) {
        setState(() => _titleInBar = inBar);
      }
    }
    return false;
  }

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
          widget.device.online
              ? 'Alterações salvas. O aparelho de $_childName aplica em instantes.'
              : 'Alterações salvas. O aparelho de $_childName está sem conexão e recebe '
                    'quando voltar.',
          tone: Tone.success,
        );
        if (_leaveAfterSave) {
          _leaveAfterSave = false;
          Navigator.of(context).pop();
        }
      case SectionSaveStatus.conflict:
        _leaveAfterSave = false;
        // O aviso do conflito fica no topo: leva a pessoa ate ele.
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: AppMotion.resolve(context, AppMotion.slow),
            curve: AppMotion.standard,
          );
        }
      case SectionSaveStatus.failed || SectionSaveStatus.idle:
        _leaveAfterSave = false;
    }
  }

  Future<void> _onPopBlocked() async {
    final _LeaveChoice choice =
        await showDialog<_LeaveChoice>(
          context: context,
          builder: (BuildContext context) => _LeaveDialog(childName: _childName),
        ) ??
        _LeaveChoice.keepEditing;
    if (!mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<B, PolicySectionState<T>>(
      listenWhen: _statusChanged,
      listener: _onStatus,
      builder: (BuildContext context, PolicySectionState<T> state) {
        final PolicySectionEditing<T>? editing = state is PolicySectionEditing<T> ? state : null;
        final bool dirty = editing?.isDirty ?? false;
        final List<HelpTopic>? help = widget.helpTopics;
        return PopScope<Object?>(
          canPop: !dirty,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) {
              _onPopBlocked();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: AnimatedSwitcher(
                duration: AppMotion.resolve(context, AppMotion.base),
                child: _titleInBar
                    ? Text(widget.title, key: const ValueKey<String>('bar-title'))
                    : const SizedBox.shrink(),
              ),
              actions: <Widget>[
                if (editing != null) ...?widget.actions?.call(context, editing.draft),
                if (help != null) HelpButton(title: widget.title, topics: help),
              ],
            ),
            body: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: StateSwitcher(
                child: switch (state) {
                  PolicySectionLoading<T>() => KeyedSubtree(
                    key: const ValueKey<String>('carregando'),
                    child: _loading(),
                  ),
                  PolicySectionError<T>(:final failure) => KeyedSubtree(
                    key: const ValueKey<String>('erro'),
                    child: _error(failure),
                  ),
                  PolicySectionEditing<T>() => KeyedSubtree(
                    key: const ValueKey<String>('editando'),
                    child: _editor(context, state),
                  ),
                },
              ),
            ),
            floatingActionButton: editing == null
                ? null
                : widget.floatingActionButton?.call(context, editing.draft),
            bottomNavigationBar: _AnimatedBar(
              child: editing != null && (dirty || editing.isSaving)
                  ? _SaveBar(
                      childName: _childName,
                      saving: editing.isSaving,
                      failed: editing.status == SectionSaveStatus.failed,
                      onSave: widget.onSave,
                      onDiscard: widget.onDiscard,
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  Widget _header() {
    return RuleEditorHeader(
      device: widget.device,
      title: widget.title,
      description: widget.description,
    );
  }

  Widget _loading() {
    return AppPageBody(
      children: <Widget>[
        _header(),
        const SkeletonListGroup(rows: 1),
        const SectionGap(),
        const SkeletonPanel(height: 120),
        const SizedBox(height: AppSpacing.lg),
        const SkeletonListGroup(),
      ],
    );
  }

  Widget _error(Object failure) {
    return AppPageBody(
      children: <Widget>[
        _header(),
        AppPanel(
          child: ErrorState.fromError(
            failure,
            subject: 'as regras de $_childName',
            onRetry: widget.onRetry,
            compact: true,
          ),
        ),
      ],
    );
  }

  Widget _editor(BuildContext context, PolicySectionEditing<T> state) {
    final List<Widget> Function(BuildContext, T)? childrenBuilder = widget.children;
    final List<Widget> content = childrenBuilder != null
        ? <Widget>[SliverList.list(children: childrenBuilder(context, state.draft))]
        : widget.slivers!(context, state.draft);
    return IgnorePointer(
      // Durante o envio o rascunho fica parado: os controles nao respondem.
      ignoring: state.isSaving,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
          child: CustomScrollView(
            controller: _scroll,
            slivers: <Widget>[
              SliverPadding(
                padding: AppSpacing.page,
                sliver: SliverMainAxisGroup(
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _header(),
                          if (widget.showSyncStatus || state.status != SectionSaveStatus.idle)
                            ..._status(state),
                        ],
                      ),
                    ),
                    ...content,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Estado do envio e da aplicacao no aparelho, logo abaixo do cabecalho.
  List<Widget> _status(PolicySectionEditing<T> state) {
    final Widget sync = PolicySyncStatusView(
      status: effectivePolicySync(widget.device, state.base.version),
    );
    final VoidCallback? restore = widget.onRestoreRejected;
    final List<Widget> lines = switch (state.status) {
      SectionSaveStatus.saving => <Widget>[
        const SyncStatusLine(
          state: SyncState.sending,
          label: 'Enviando as alterações',
          detail: 'As regras atuais continuam valendo até o servidor confirmar.',
        ),
      ],
      SectionSaveStatus.failed => <Widget>[
        AppBanner(
          tone: Tone.danger,
          liveRegion: true,
          title: 'Não foi possível salvar',
          message:
              '${state.failure?.message ?? 'O envio não foi concluído.'} Nada foi enviado ao '
              'aparelho: as regras anteriores continuam valendo e as suas alterações continuam '
              'nesta tela.',
          actionLabel: 'Tentar de novo',
          onAction: widget.onSave,
        ),
      ],
      SectionSaveStatus.conflict => <Widget>[
        AppBanner(
          tone: Tone.warning,
          icon: AppIcons.syncProblem,
          liveRegion: true,
          title: 'As regras mudaram em outra sessão',
          message:
              'Enquanto você editava, estas regras de $_childName foram alteradas em outro '
              'lugar. A tela já mostra a versão atual e as suas alterações não foram salvas.'
              '${state.rejected != null && restore != null ? ' Você pode refazê-las sobre esta versão e salvar de novo.' : ''}',
          actionLabel: state.rejected != null && restore != null
              ? 'Refazer minhas alterações'
              : null,
          onAction: restore,
        ),
        const SizedBox(height: AppSpacing.lg),
        sync,
      ],
      SectionSaveStatus.idle || SectionSaveStatus.saved => <Widget>[sync],
    };
    return <Widget>[...lines, const SectionGap()];
  }
}

/// Barra de salvar que entra e sai deslizando, para a pessoa perceber que ha (ou nao ha mais)
/// alteracoes pendentes.
class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.resolve(context, AppMotion.base),
      switchInCurve: AppMotion.standard,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: child ?? const SizedBox.shrink(key: ValueKey<String>('sem-barra')),
    );
  }
}

/// Barra fixa com salvar e descartar, visivel so quando ha alteracoes. A mensagem diz o que
/// acontece ao salvar (ou o que falhou), e o botao fica ocupado durante o envio.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.childName,
    required this.saving,
    required this.failed,
    required this.onSave,
    required this.onDiscard,
  });

  final String childName;
  final bool saving;
  final bool failed;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final String message = saving
        ? 'Enviando as alterações ao servidor.'
        : failed
        ? 'Não foi possível salvar. As regras anteriores continuam valendo.'
        : 'Alterações não salvas. Ao salvar, elas vão para o aparelho de $childName.';
    return Semantics(
      container: true,
      liveRegion: true,
      child: StickyActionBar(
        key: const ValueKey<String>('save-bar'),
        message: message,
        child: Row(
          children: <Widget>[
            Expanded(
              child: AppButton.tertiary(label: 'Descartar', onPressed: saving ? null : onDiscard),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: AppButton.primary(
                label: saving
                    ? 'Salvando'
                    : failed
                    ? 'Tentar de novo'
                    : 'Salvar',
                icon: failed ? AppIcons.refresh : null,
                busy: saving,
                expand: true,
                onPressed: onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pergunta o que fazer com as alteracoes ao sair: salvar, descartar ou continuar editando.
class _LeaveDialog extends StatelessWidget {
  const _LeaveDialog({required this.childName});

  final String childName;

  @override
  Widget build(BuildContext context) {
    void close(_LeaveChoice choice) => Navigator.of(context).pop(choice);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxFormWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconMedallion(icon: AppIcons.edit, size: AppSizes.avatarLg - AppSpacing.sm),
              ),
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                header: true,
                child: Text('Salvar as alterações?', style: context.text.headlineSmall),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Você mudou regras de $childName que ainda não foram enviadas ao aparelho.',
                style: context.text.bodyLarge?.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Se descartar, as regras atuais continuam valendo.',
                style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton.primary(
                label: 'Salvar e sair',
                expand: true,
                onPressed: () => close(_LeaveChoice.save),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton.tertiary(
                label: 'Descartar alterações',
                expand: true,
                onPressed: () => close(_LeaveChoice.discard),
              ),
              AppButton.tertiary(
                label: 'Continuar editando',
                expand: true,
                onPressed: () => close(_LeaveChoice.keepEditing),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
