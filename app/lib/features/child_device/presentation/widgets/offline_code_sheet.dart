import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/feedback_views.dart';
import '../../domain/entities/child_device.dart';
import '../../domain/entities/offline_access_code.dart';
import '../bloc/offline_code/offline_code_bloc.dart';

/// Mostra o codigo de acesso offline do momento, com a contagem ate ele mudar.
///
/// Espera um [OfflineCodeBloc] acima na arvore.
class OfflineCodeSheet extends StatelessWidget {
  const OfflineCodeSheet({required this.device, super.key});

  final ChildDevice device;

  /// Duracao de cada codigo, em segundos (ver `ComputeOfflineAccessCode`).
  static const int stepSeconds = 60;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final OfflineAccessCode current = context.watch<OfflineCodeBloc>().state.code;
    final String code = current.code;
    final int remaining = current.secondsRemaining;
    final String spaced = code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Código de acesso offline', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No aparelho de ${device.displayName}, abra o ParentaLynx, toque em "Área '
            'do responsável" e escolha "Usar código de acesso".',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (!current.isValid)
            const NoticeBanner(
              tone: Tone.danger,
              message: 'Não foi possível calcular o código para este aparelho.',
            )
          else ...<Widget>[
            Semantics(
              label: 'Código ${code.split('').join(' ')}',
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  spaced,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: remaining / stepSeconds, minHeight: 6),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Muda em $remaining s',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const NoticeBanner(
            tone: Tone.warning,
            message:
                'Não mostre este código para a criança. Ele vale por poucos minutos e depende '
                'de os dois aparelhos estarem com a hora certa.',
          ),
        ],
      ),
    );
  }
}
