import 'package:material_ui/material_ui.dart';

import '../../../../core/errors/app_failure.dart';
import '../../foundations/app_icons.dart';
import '../../foundations/tone.dart';
import 'empty_state.dart';

/// Estado de erro de uma tela ou secao que nao conseguiu carregar.
///
/// Segue a mesma estrutura em todo o app: o titulo diz o que nao funcionou ("Nao foi possivel
/// carregar os relatorios"), a mensagem diz por que e o que fazer, e a acao tenta de novo.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Tentar de novo',
    this.icon = AppIcons.error,
    this.compact = false,
    super.key,
  });

  /// Monta o estado a partir de uma falha. [subject] completa o titulo
  /// ("Nao foi possivel carregar [subject]").
  factory ErrorState.fromError(
    Object error, {
    String? subject,
    VoidCallback? onRetry,
    bool compact = false,
    Key? key,
  }) {
    final AppFailure failure = toFailure(error);
    final bool offline = failure is NetworkFailure;
    return ErrorState(
      key: key,
      icon: offline ? AppIcons.offline : AppIcons.error,
      title: offline
          ? 'Sem conexão com o servidor'
          : subject == null
          ? 'Não foi possível carregar'
          : 'Não foi possível carregar $subject',
      message: failure.message,
      onRetry: onRetry,
      compact: compact,
    );
  }

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: EmptyState(
        icon: icon,
        tone: icon == AppIcons.offline ? Tone.neutral : Tone.danger,
        title: title,
        message: message,
        actionLabel: onRetry == null ? null : retryLabel,
        onAction: onRetry,
        compact: compact,
      ),
    );
  }
}
