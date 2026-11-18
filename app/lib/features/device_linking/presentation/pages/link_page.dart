import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/security/pairing_code.dart';
import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/pairing_claim.dart';
import '../bloc/child_link/child_link_bloc.dart';
import '../bloc/child_linking/child_linking_bloc.dart';

/// Vinculacao deste aparelho ao responsavel: codigo, espera da aprovacao e ativacao.
///
/// Espera um [ChildLinkingBloc] acima na arvore e le o aviso de vinculo desfeito do
/// [ChildLinkBloc].
class LinkPage extends StatefulWidget {
  const LinkPage({super.key});

  @override
  State<LinkPage> createState() => _LinkPageState();
}

class _LinkPageState extends State<LinkPage> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _name = TextEditingController();
  bool _nameFilled = false;

  @override
  void initState() {
    super.initState();
    _fillName(context.read<ChildLinkingBloc>().state.suggestedDeviceName);
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Preenche o nome sugerido uma vez, sem sobrescrever o que a pessoa digitar.
  void _fillName(String? suggestion) {
    if (suggestion == null || _nameFilled) {
      return;
    }
    _nameFilled = true;
    if (_name.text.isEmpty) {
      _name.text = suggestion;
    }
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (!mounted || text == null) {
      return;
    }
    final String formatted = PairingCode.format(text);
    if (formatted.isEmpty) {
      showAppSnackBar(context, 'Não há um código copiado.');
      return;
    }
    _code.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _changed();
  }

  void _changed() {
    context.read<ChildLinkingBloc>().add(const ChildLinkingErrorCleared());
    setState(() {});
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<ChildLinkingBloc>().add(
      ChildLinkingCodeSubmitted(code: _code.text, deviceName: _name.text),
    );
  }

  Future<void> _cancelWaiting() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Cancelar o pedido?',
      message: 'O responsável não vai mais conseguir aprovar este pedido.',
      consequence: 'Para vincular depois, será preciso digitar um código de novo.',
      confirmLabel: 'Cancelar pedido',
      cancelLabel: 'Continuar esperando',
    );
    if (confirmed && mounted) {
      context.read<ChildLinkingBloc>().add(const ChildLinkingWaitCancelled());
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? notice = context.select<ChildLinkBloc, String?>(
      (ChildLinkBloc bloc) => bloc.state.notice,
    );
    return BlocConsumer<ChildLinkingBloc, ChildLinkingState>(
      listener: (BuildContext context, ChildLinkingState state) {
        _fillName(state.suggestedDeviceName);
        if (state case ChildLinkingForm(leaveFailure: final Object failure)) {
          showFailure(context, failure);
        }
      },
      listenWhen: (ChildLinkingState previous, ChildLinkingState current) {
        return previous.suggestedDeviceName != current.suggestedDeviceName ||
            (current is ChildLinkingForm && current.leaveFailure != null && current != previous);
      },
      builder: (BuildContext context, ChildLinkingState state) {
        return Scaffold(
          body: SafeArea(
            child: StateSwitcher(
              child: switch (state) {
                ChildLinkingForm(activity: LinkFormActivity.restoring) => const KeyedSubtree(
                  key: ValueKey<String>('conferindo'),
                  child: LoadingState(message: 'Conferindo este aparelho...'),
                ),
                ChildLinkingForm() => KeyedSubtree(
                  key: const ValueKey<String>('codigo'),
                  child: _FormView(
                    state: state,
                    code: _code,
                    name: _name,
                    notice: notice,
                    onChanged: _changed,
                    onPaste: _paste,
                    onSubmit: _submit,
                    onLeave: () =>
                        context.read<ChildLinkingBloc>().add(const ChildLinkingLeaveRequested()),
                  ),
                ),
                ChildLinkingWaiting() => KeyedSubtree(
                  key: const ValueKey<String>('esperando'),
                  child: _WaitingView(
                    claim: state.claim,
                    connectionTrouble: state.connectionTrouble,
                    onCancel: _cancelWaiting,
                  ),
                ),
                ChildLinkingActivating() => const KeyedSubtree(
                  key: ValueKey<String>('ativando'),
                  child: LoadingState(message: 'Aprovado! Ligando o controle neste aparelho...'),
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.state,
    required this.code,
    required this.name,
    required this.notice,
    required this.onChanged,
    required this.onPaste,
    required this.onSubmit,
    required this.onLeave,
  });

  final ChildLinkingForm state;
  final TextEditingController code;
  final TextEditingController name;
  final String? notice;
  final VoidCallback onChanged;
  final VoidCallback onPaste;
  final VoidCallback onSubmit;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final bool busy = state.activity.isBusy;
    final bool leaving = state.activity == LinkFormActivity.leaving;
    final bool ready = PairingCode.isComplete(code.text) && name.text.trim().isNotEmpty;
    final String? error = state.error;
    final TextStyle? codeStyle = context.text.headlineSmall?.copyWith(letterSpacing: AppSpacing.xs);
    return ChildPageBody(
      children: <Widget>[
        const ChildHeader(
          icon: AppIcons.link,
          title: 'Vincular este aparelho',
          message:
              'Peça o código ao seu responsável. Ele aparece no app do responsável, na opção '
              '"Vincular aparelho".',
        ),
        if (notice != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppBanner(icon: AppIcons.unlink, message: notice!, liveRegion: true),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          controller: code,
          enabled: !busy,
          label: 'Código de vinculação',
          hint: 'XXXX-XXXX',
          helper: '8 letras e números, do jeito que aparece no app do responsável.',
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          inputFormatters: <TextInputFormatter>[PairingCodeFormatter()],
          onChanged: (String value) => onChanged(),
          style: codeStyle,
          suffix: AppIconButton(
            icon: AppIcons.paste,
            tooltip: 'Colar o código copiado',
            onPressed: busy ? null : onPaste,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: name,
          enabled: !busy,
          label: 'Nome deste aparelho',
          helper: 'É como o responsável vai reconhecer este aparelho.',
          prefixIcon: AppIcons.device,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onChanged: (String value) => onChanged(),
          onSubmitted: (String value) => ready ? onSubmit() : null,
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          AppBanner(
            tone: Tone.danger,
            title: 'Não deu para vincular',
            message: error,
            liveRegion: true,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton.primary(
          label: 'Vincular',
          icon: AppIcons.link,
          expand: true,
          busy: state.activity == LinkFormActivity.submitting,
          onPressed: ready ? onSubmit : null,
        ),
        const SectionGap(),
        const AppSection(
          title: 'O que acontece depois',
          child: StepList(
            steps: <String>[
              'O responsável confere um número no aparelho dele e aprova.',
              'Você vê o que o app controla e o que ele não vê.',
              'O aparelho pede algumas permissões para o controle funcionar.',
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton.tertiary(
          label: 'Voltar e escolher outro modo',
          icon: AppIcons.back,
          busy: leaving,
          onPressed: busy ? null : onLeave,
        ),
      ],
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({
    required this.claim,
    required this.connectionTrouble,
    required this.onCancel,
  });

  final PairingClaim claim;
  final bool connectionTrouble;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bool named = claim.guardianName.isNotEmpty;
    final String guardian = named ? claim.guardianName : 'O responsável';
    final String guardianLower = named ? claim.guardianName : 'o responsável';
    final String digits = claim.confirmCode.split('').join(' ');
    return ChildPageBody(
      children: <Widget>[
        ChildHeader(
          icon: AppIcons.timeStarting,
          title: 'Quase lá!',
          message: '$guardian precisa aprovar este aparelho no app do responsável.',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppPanel(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: <Widget>[
              Text('Número de confirmação'.toUpperCase(), style: context.textStyles.eyebrow),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                label: 'Número de confirmação: $digits',
                excludeSemantics: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    digits,
                    maxLines: 1,
                    style: context.textStyles.metricHero.copyWith(color: context.colors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Confira se o mesmo número aparece no aparelho de $guardianLower. Se for '
                'diferente, o pedido não deve ser aprovado.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SyncStatusLine(
          state: connectionTrouble ? SyncState.offline : SyncState.pending,
          label: connectionTrouble
              ? 'Sem conexão com o servidor. Tentando de novo...'
              : 'Esperando a aprovação...',
          detail: connectionTrouble
              ? 'O pedido continua valendo. Confira a internet deste aparelho.'
              : 'Esta tela muda sozinha quando $guardianLower aprovar.',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton.tertiary(label: 'Cancelar pedido', onPressed: onCancel),
      ],
    );
  }
}

/// Formata o codigo enquanto a pessoa digita: maiusculas, sem letras ambiguas, com hifen.
class PairingCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final String formatted = PairingCode.format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
