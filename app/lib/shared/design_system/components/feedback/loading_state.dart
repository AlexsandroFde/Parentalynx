import 'package:material_ui/material_ui.dart';

import '../../foundations/ds_context.dart';
import '../../tokens/motion.dart';
import '../../tokens/radius.dart';
import '../../tokens/sizes.dart';
import '../../tokens/spacing.dart';

/// Carregamento de uma tela inteira, com uma frase opcional do que esta acontecendo
/// ("Conferindo o vinculo deste aparelho").
///
/// Para conteudo com formato conhecido (listas, paineis), prefira os esqueletos ([Skeleton],
/// [SkeletonListGroup]): a pagina ja mostra a sua forma e a troca pelo conteudo e suave.
class LoadingState extends StatelessWidget {
  const LoadingState({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message ?? 'Carregando',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox.square(
                dimension: AppSizes.iconXl - 4,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              if (message != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                ExcludeSemantics(
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulso suave dos esqueletos de carregamento. Fica parado quando o sistema pede para reduzir
/// animacoes. O leitor de tela ouve "Carregando" uma vez, no lugar das formas.
class Skeleton extends StatefulWidget {
  const Skeleton({required this.child, super.key});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.resolve(context, AppMotion.base) == Duration.zero) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando',
      excludeSemantics: true,
      child: FadeTransition(opacity: _controller, child: widget.child),
    );
  }
}

/// Bloco de esqueleto (forma cinza no lugar de um texto ou imagem).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({this.width, this.height = 14, this.radius = AppRadius.xs, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.colors.surfaceStrong,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Esqueleto de uma lista agrupada com [rows] linhas.
class SkeletonListGroup extends StatelessWidget {
  const SkeletonListGroup({this.rows = 3, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: context.shapes.containerRadius,
        ),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < rows; i++)
              Padding(
                padding: AppSpacing.row,
                child: Row(
                  children: <Widget>[
                    SkeletonBox(
                      width: AppSizes.iconTile,
                      height: AppSizes.iconTile,
                      radius: context.shapes.tile,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          FractionallySizedBox(
                            widthFactor: i.isEven ? 0.6 : 0.45,
                            child: const SkeletonBox(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const FractionallySizedBox(
                            widthFactor: 0.8,
                            child: SkeletonBox(height: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Esqueleto de um painel de altura fixa (por exemplo, o resumo do tempo de hoje).
class SkeletonPanel extends StatelessWidget {
  const SkeletonPanel({this.height = 160, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: context.shapes.containerRadius,
        ),
        padding: AppSpacing.panel,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FractionallySizedBox(widthFactor: 0.4, child: SkeletonBox(height: 16)),
            SizedBox(height: AppSpacing.md),
            FractionallySizedBox(widthFactor: 0.7, child: SkeletonBox()),
          ],
        ),
      ),
    );
  }
}
