import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/security/pairing_code.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/child_layout.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
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
    final bool confirmed = await confirmAction(
      context,
      title: 'Cancelar o pedido?',
      message: 'Para vincular depois será preciso digitar o código de novo.',
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
            child: switch (state) {
              ChildLinkingForm() => _FormView(
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
              ChildLinkingWaiting() => _WaitingView(
                claim: state.claim,
                connectionTrouble: state.connectionTrouble,
                onCancel: _cancelWaiting,
              ),
              ChildLinkingActivating() => const LoadingView(
                message: 'Aprovado! Ligando o controle neste aparelho...',
              ),
            },
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
    final ThemeData theme = Theme.of(context);
    final bool busy = state.activity.isBusy;
    final bool leaving = state.activity == LinkFormActivity.leaving;
    final bool restoring = state.activity == LinkFormActivity.restoring;
    final bool ready = PairingCode.isComplete(code.text) && name.text.trim().isNotEmpty;
    final String? error = state.error;
    return ChildPageBody(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: <Widget>[
        const ChildHeader(
          icon: Icons.link_rounded,
          title: 'Vincular este aparelho',
          message:
              'Peça o código de vinculação ao seu responsável. Ele aparece no aparelho dele, '
              'na opção "Vincular aparelho".',
        ),
        if (notice != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          NoticeBanner(message: notice!, tone: Tone.warning),
        ],
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: code,
          enabled: !busy,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.next,
          inputFormatters: <TextInputFormatter>[PairingCodeFormatter()],
          onChanged: (String value) => onChanged(),
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 3),
          decoration: InputDecoration(
            labelText: 'Código de vinculação',
            hintText: 'XXXX-XXXX',
            hintStyle: theme.textTheme.headlineSmall?.copyWith(
              letterSpacing: 3,
              color: theme.colorScheme.outline,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            suffixIcon: IconButton(
              tooltip: 'Colar o código copiado',
              icon: const Icon(Icons.content_paste_rounded),
              onPressed: busy ? null : onPaste,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: name,
          enabled: !busy,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onChanged: (String value) => onChanged(),
          onSubmitted: (String value) => ready ? onSubmit() : null,
          decoration: const InputDecoration(
            labelText: 'Nome deste aparelho',
            helperText: 'É como o responsável vai reconhecer este aparelho.',
            helperMaxLines: 2,
            counterText: '',
            prefixIcon: Icon(Icons.smartphone_rounded),
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            liveRegion: true,
            child: NoticeBanner(message: error, tone: Tone.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        BusyButton(
          label: 'Vincular',
          icon: Icons.link_rounded,
          busy: state.activity == LinkFormActivity.submitting,
          onPressed: ready && !restoring ? onSubmit : null,
        ),
        const SizedBox(height: AppSpacing.xl),
        const SectionCard(
          title: 'O que acontece depois',
          child: Column(
            children: <Widget>[
              BulletLine(
                icon: Icons.looks_one_outlined,
                text: 'O responsável confere um número no aparelho dele e aprova.',
              ),
              BulletLine(
                icon: Icons.looks_two_outlined,
                text: 'Você vê o que o app controla e o que ele não vê.',
              ),
              BulletLine(
                icon: Icons.looks_3_outlined,
                text: 'O aparelho pede algumas permissões para o controle funcionar.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton.icon(
            onPressed: busy || leaving ? null : onLeave,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Voltar e escolher outro modo'),
          ),
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
    final ThemeData theme = Theme.of(context);
    final String guardian = claim.guardianName.isEmpty ? 'O responsável' : claim.guardianName;
    return ChildPageBody(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: <Widget>[
        ChildHeader(
          icon: Icons.hourglass_top_rounded,
          title: 'Quase lá!',
          message: '$guardian precisa aprovar este aparelho no app do responsável.',
        ),
        const SizedBox(height: AppSpacing.xl),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
            child: Column(
              children: <Widget>[
                Text(
                  'Número de confirmação',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  label: 'Número de confirmação: ${claim.confirmCode.split('').join(' ')}',
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      claim.confirmCode.split('').join(' '),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const NoticeBanner(
          icon: Icons.fact_check_outlined,
          title: 'Confira o número',
          message:
              'O mesmo número precisa aparecer no aparelho do responsável. Se o número de lá '
              'for diferente, o responsável não deve aprovar.',
        ),
        const SizedBox(height: AppSpacing.xl),
        const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          child: LinearProgressIndicator(minHeight: 6),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          liveRegion: true,
          child: Text(
            connectionTrouble
                ? 'Sem conexão com o servidor. Tentando de novo...'
                : 'Esperando a aprovação...',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: connectionTrouble
                  ? StatusColors.of(context).warning
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton(onPressed: onCancel, child: const Text('Cancelar pedido')),
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
