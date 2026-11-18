import 'package:material_ui/material_ui.dart';

import '../../core/errors/app_failure.dart';
import '../theme/app_theme.dart';

/// Tom visual de um aviso.
enum Tone { neutral, info, success, warning, danger }

extension ToneColors on Tone {
  /// Cor de destaque (texto e icone).
  Color foreground(BuildContext context) {
    final StatusColors status = StatusColors.of(context);
    return switch (this) {
      Tone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
      Tone.info => status.info,
      Tone.success => status.success,
      Tone.warning => status.warning,
      Tone.danger => status.danger,
    };
  }

  /// Fundo suave.
  Color background(BuildContext context) {
    final StatusColors status = StatusColors.of(context);
    return switch (this) {
      Tone.neutral => Theme.of(context).colorScheme.surfaceContainerHighest,
      Tone.info => status.infoContainer,
      Tone.success => status.successContainer,
      Tone.warning => status.warningContainer,
      Tone.danger => status.dangerContainer,
    };
  }
}

/// Mostra uma mensagem curta na parte de baixo da tela.
void showAppSnackBar(BuildContext context, String message, {Tone tone = Tone.neutral}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  final IconData? icon = switch (tone) {
    Tone.success => Icons.check_circle_outline,
    Tone.warning => Icons.warning_amber_rounded,
    Tone.danger => Icons.error_outline,
    Tone.info => Icons.info_outline,
    Tone.neutral => null,
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, color: Theme.of(context).colorScheme.onInverseSurface, size: 20),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Mostra a mensagem de uma falha.
void showFailure(BuildContext context, Object error) {
  showAppSnackBar(context, toFailure(error).message, tone: Tone.danger);
}

/// Indicador de carregamento centralizado.
class LoadingView extends StatelessWidget {
  const LoadingView({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          if (message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Estado de erro com a mensagem e a acao de tentar de novo.
class FailureView extends StatelessWidget {
  const FailureView({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppFailure failure = toFailure(error);
    return EmptyState(
      icon: failure is NetworkFailure ? Icons.cloud_off_outlined : Icons.error_outline,
      title: failure is NetworkFailure ? 'Sem conexão' : 'Não foi possível carregar',
      message: failure.message,
      actionLabel: onRetry == null ? null : 'Tentar de novo',
      onAction: onRetry,
    );
  }
}

/// Estado vazio: explica o que apareceria ali e, quando faz sentido, oferece o proximo passo.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Etiqueta curta de estado: icone, texto e fundo suave.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, this.tone = Tone.neutral, this.icon, super.key});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color foreground = tone.foreground(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.background(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faixa de aviso dentro de uma pagina: icone, titulo, texto e acao opcional.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    required this.message,
    this.title,
    this.tone = Tone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String? title;
  final String message;
  final Tone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color foreground = tone.foreground(context);
    final IconData resolvedIcon =
        icon ??
        switch (tone) {
          Tone.success => Icons.check_circle_outline,
          Tone.warning => Icons.warning_amber_rounded,
          Tone.danger => Icons.error_outline,
          Tone.info || Tone.neutral => Icons.info_outline,
        };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: tone.background(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(resolvedIcon, color: foreground, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                ),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: foreground,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
