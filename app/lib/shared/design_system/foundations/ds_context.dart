import 'package:material_ui/material_ui.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';

/// Atalhos para ler os tokens do tema atual.
///
/// ```dart
/// Text('Online', style: context.text.labelMedium?.copyWith(color: context.colors.success));
/// ```
extension DesignSystemContext on BuildContext {
  /// Papeis de cor do perfil e do brilho atuais.
  AppColors get colors => AppColors.of(this);

  /// Formas do perfil atual (raio de controles, conteineres e folhas).
  AppShapes get shapes => AppShapes.of(this);

  /// Escala de texto do perfil atual.
  TextTheme get text => Theme.of(this).textTheme;

  /// Estilos numericos e o sobretitulo.
  AppTextStyles get textStyles => AppTextStyles.of(this);
}
