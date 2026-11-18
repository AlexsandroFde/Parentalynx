import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/effective_app_state.dart';

/// Tom e icone de cada estado efetivo de um app. O estado sempre aparece com icone e texto,
/// nunca so pela cor.
extension EffectiveAppStateUi on EffectiveAppState {
  Tone get tone {
    return switch (this) {
      EffectiveAppState.allowed => Tone.neutral,
      EffectiveAppState.blocked => Tone.danger,
      EffectiveAppState.exception => Tone.success,
      EffectiveAppState.pendingApproval => Tone.warning,
      EffectiveAppState.essential => Tone.info,
    };
  }

  IconData get icon {
    return switch (this) {
      EffectiveAppState.allowed => AppIcons.check,
      EffectiveAppState.blocked => AppIcons.blocked,
      EffectiveAppState.exception => AppIcons.exception,
      EffectiveAppState.pendingApproval => AppIcons.pending,
      EffectiveAppState.essential => AppIcons.lock,
    };
  }
}
