import 'package:material_ui/material_ui.dart';

import '../../tokens/motion.dart';

/// Troca suave entre estados de uma tela (carregando, conteudo, vazio, erro): o novo estado
/// entra com um leve deslize e o antigo sai em seguida, para a pessoa perceber que algo mudou.
///
/// Cada estado precisa de uma chave propria, por exemplo
/// `KeyedSubtree(key: const ValueKey<String>('carregando'), child: ...)`.
class StateSwitcher extends StatelessWidget {
  const StateSwitcher({required this.child, this.alignment = Alignment.topCenter, super.key});

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.resolve(context, AppMotion.base),
      switchInCurve: AppMotion.standard,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (Widget? current, List<Widget> previous) {
        return Stack(alignment: alignment, children: <Widget>[...previous, ?current]);
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
