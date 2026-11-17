import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/platform/native_providers.dart';
import '../../../../core/security/pairing_code.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../../../shared/widgets/form_widgets.dart';
import '../../agent/data/child_device_repository.dart';
import '../../agent/domain/child_models.dart';
import '../../agent/presentation/child_session.dart';
import '../../shared/child_widgets.dart';
import '../domain/pairing.dart';
import 'linking_controller.dart';

/// Vinculacao deste aparelho ao responsavel: codigo, espera da aprovacao e ativacao.
class LinkPage extends ConsumerStatefulWidget {
  const LinkPage({super.key});

  @override
  ConsumerState<LinkPage> createState() => _LinkPageState();
}

class _LinkPageState extends ConsumerState<LinkPage> {
  final TextEditingController _code = TextEditingController();
  final TextEditingController _name = TextEditingController();
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prefillName());
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _prefillName() async {
    try {
      final DeviceIdentity info = await ref.read(childDeviceRepositoryProvider).deviceInfo();
      if (mounted && _name.text.isEmpty) {
        _name.text = info.name;
      }
    } on AppFailure {
      // Sem o nome sugerido a pessoa digita um.
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
    ref.read(linkingControllerProvider.notifier).clearError();
    setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(linkingControllerProvider.notifier)
        .submit(code: _code.text, deviceName: _name.text);
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
      await ref.read(linkingControllerProvider.notifier).cancelWaiting();
    }
  }

  Future<void> _leaveChildMode() async {
    setState(() => _leaving = true);
    try {
      await ref.read(appModeProvider.notifier).setMode(AppMode.unset);
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _leaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final LinkingState state = ref.watch(linkingControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: switch (state) {
          LinkingForm() => _FormView(
            state: state,
            code: _code,
            name: _name,
            notice: ref.watch(childLinkNoticeProvider),
            leaving: _leaving,
            onChanged: () {
              ref.read(linkingControllerProvider.notifier).clearError();
              setState(() {});
            },
            onPaste: _paste,
            onSubmit: _submit,
            onLeave: _leaveChildMode,
          ),
          LinkingWaiting() => _WaitingView(
            claim: state.claim,
            connectionTrouble: state.connectionTrouble,
            onCancel: _cancelWaiting,
          ),
          LinkingActivating() => const LoadingView(
            message: 'Aprovado! Ligando o controle neste aparelho...',
          ),
        },
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.state,
    required this.code,
    required this.name,
    required this.notice,
    required this.leaving,
    required this.onChanged,
    required this.onPaste,
    required this.onSubmit,
    required this.onLeave,
  });

  final LinkingForm state;
  final TextEditingController code;
  final TextEditingController name;
  final String? notice;
  final bool leaving;
  final VoidCallback onChanged;
  final VoidCallback onPaste;
  final VoidCallback onSubmit;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool busy = state.submitting || state.restoring;
    final bool ready = PairingCode.isComplete(code.text) && name.text.trim().isNotEmpty;
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
        if (state.error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            liveRegion: true,
            child: NoticeBanner(message: state.error!, tone: Tone.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        BusyButton(
          label: 'Vincular',
          icon: Icons.link_rounded,
          busy: state.submitting,
          onPressed: ready && !state.restoring ? onSubmit : null,
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
