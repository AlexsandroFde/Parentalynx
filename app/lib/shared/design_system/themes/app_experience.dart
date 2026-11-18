import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';

/// Perfil de uso. Os dois perfis compartilham tokens e componentes; o da crianca usa formas
/// mais arredondadas e texto maior, para uma experiencia acolhedora sem ficar infantilizada.
enum AppExperience { guardian, child }

/// Aplica o tema de um perfil a uma parte da arvore, mantendo o brilho (claro ou escuro)
/// escolhido pelo sistema.
///
/// A area da crianca e o navegador gerenciado ficam dentro de um
/// `AppExperienceScope(experience: AppExperience.child, ...)`; o restante do app usa o tema do
/// responsavel definido no `MaterialApp`.
class AppExperienceScope extends StatelessWidget {
  const AppExperienceScope({required this.experience, required this.child, super.key});

  final AppExperience experience;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    return Theme(data: AppTheme.build(brightness, experience), child: child);
  }
}
