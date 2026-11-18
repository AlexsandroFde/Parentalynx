import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/child_device.dart';
import '../../domain/entities/offline_access_code.dart';
import '../bloc/offline_code/offline_code_bloc.dart';

/// Conteudo da folha do codigo de acesso offline: o codigo do momento, em digitos grandes, e a
/// contagem ate ele mudar. O titulo e as instrucoes ficam na moldura da folha.
///
/// Espera um [OfflineCodeBloc] acima na arvore.
class OfflineCodeSheet extends StatelessWidget {
  const OfflineCodeSheet({required this.device, super.key});

  final ChildDevice device;

  /// Duracao de cada codigo, em segundos (ver `ComputeOfflineAccessCode`).
  static const int stepSeconds = 60;

  @override
  Widget build(BuildContext context) {
    final OfflineAccessCode current = context.watch<OfflineCodeBloc>().state.code;
    final String code = current.code;
    final int remaining = current.secondsRemaining;
    final String spaced = code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;
    final bool ending = remaining <= 10;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!current.isValid)
          const AppBanner(
            tone: Tone.danger,
            title: 'Não foi possível calcular o código',
            message:
                'O segredo deste aparelho não pôde ser lido. Feche e abra de novo; se continuar, '
                'desvincule e vincule o aparelho outra vez.',
          )
        else
          AppPanel(
            tone: Tone.info,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  label: 'Código ${code.split('').join(' ')}',
                  excludeSemantics: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      spaced,
                      maxLines: 1,
                      style: context.text.displayMedium?.copyWith(
                        fontFeatures: AppTypography.tabularFigures,
                        letterSpacing: AppSpacing.xs,
                        color: context.colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                UsageBar(
                  fraction: remaining / stepSeconds,
                  color: (ending ? Tone.warning : Tone.info).foreground(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Muda em $remaining s',
                  textAlign: TextAlign.center,
                  style: context.text.labelLarge?.copyWith(
                    color: context.colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        AppBanner(
          tone: Tone.warning,
          icon: AppIcons.lock,
          message:
              'Não mostre este código para ${device.displayName}. Ele vale só por alguns minutos '
              'e depende de os dois aparelhos estarem com a hora certa.',
        ),
      ],
    );
  }
}
