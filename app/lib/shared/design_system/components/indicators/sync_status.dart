import 'package:material_ui/material_ui.dart';

import '../../foundations/app_icons.dart';
import '../../foundations/ds_context.dart';
import '../../foundations/tone.dart';
import '../../tokens/motion.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';

/// Estado de uma configuracao entre o painel e o aparelho da crianca.
///
/// Uma regra so e "aplicada" depois que o aparelho confirma; antes disso fica "aguardando o
/// aparelho". O app nunca mostra como aplicado o que o aparelho ainda nao confirmou.
enum SyncState {
  /// O aparelho confirmou a versao atual.
  applied,

  /// Salvo no servidor; o aparelho ainda nao confirmou.
  pending,

  /// Enviando ao servidor neste momento.
  sending,

  /// O aparelho esta sem conexao; recebe as mudancas quando voltar.
  offline,

  /// O envio falhou; a configuracao anterior continua valendo.
  failed,
}

extension SyncStateStyle on SyncState {
  Tone get tone => switch (this) {
    SyncState.applied => Tone.success,
    SyncState.pending => Tone.warning,
    SyncState.sending => Tone.info,
    SyncState.offline => Tone.neutral,
    SyncState.failed => Tone.danger,
  };

  IconData get icon => switch (this) {
    SyncState.applied => AppIcons.synced,
    SyncState.pending => AppIcons.pending,
    SyncState.sending => AppIcons.sync,
    SyncState.offline => AppIcons.offline,
    SyncState.failed => AppIcons.syncProblem,
  };

  /// Rotulo padrao, em linguagem de quem usa o app.
  String get label => switch (this) {
    SyncState.applied => 'Aplicado no aparelho',
    SyncState.pending => 'Aguardando o aparelho confirmar',
    SyncState.sending => 'Enviando ao aparelho',
    SyncState.offline => 'Aparelho sem conexão',
    SyncState.failed => 'Não foi possível enviar',
  };
}

/// Linha de estado de sincronizacao: icone na cor do estado, rotulo e um detalhe opcional
/// ("O aparelho confirmou a versao atual ha 2 min").
///
/// O leitor de tela anuncia quando o estado muda.
class SyncStatusLine extends StatelessWidget {
  const SyncStatusLine({required this.state, this.label, this.detail, super.key});

  final SyncState state;

  /// Substitui o rotulo padrao do estado.
  final String? label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final Tone tone = state.tone;
    final Widget icon = Icon(state.icon, size: AppSizes.iconMd, color: tone.foreground(context));
    final TextStyle? labelStyle = context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // O icone tem a altura da linha do rotulo: os dois ficam alinhados no topo.
          if (state == SyncState.sending) _Spin(child: icon) else icon,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label ?? state.label, style: labelStyle),
                if (detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(detail!, style: context.text.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gira o icone de sincronizacao enquanto o envio acontece (parado se o sistema pede para
/// reduzir animacoes).
class _Spin extends StatefulWidget {
  const _Spin({required this.child});

  final Widget child;

  @override
  State<_Spin> createState() => _SpinState();
}

class _SpinState extends State<_Spin> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.resolve(context, AppMotion.base) == Duration.zero) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _controller, child: widget.child);
  }
}
