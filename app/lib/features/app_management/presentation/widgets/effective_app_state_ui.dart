import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/feedback_views.dart';
import '../../domain/entities/effective_app_state.dart';

/// Cor e icone de cada estado efetivo de um app.
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
      EffectiveAppState.allowed => Icons.check,
      EffectiveAppState.blocked => Icons.block,
      EffectiveAppState.exception => Icons.verified_outlined,
      EffectiveAppState.pendingApproval => Icons.hourglass_empty,
      EffectiveAppState.essential => Icons.lock_outline,
    };
  }
}
