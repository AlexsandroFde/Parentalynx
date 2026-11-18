import 'package:material_ui/material_ui.dart';

import '../../../../shared/design_system/design_system.dart';
import '../../domain/entities/app_entry.dart';

/// Icone que representa cada categoria de app na interface.
extension AppCategoryUi on AppCategory {
  IconData get icon {
    return switch (this) {
      AppCategory.games => AppIcons.categoryGames,
      AppCategory.social => AppIcons.categorySocial,
      AppCategory.video => AppIcons.categoryVideo,
      AppCategory.audio => AppIcons.categoryAudio,
      AppCategory.image => AppIcons.categoryPhotos,
      AppCategory.news => AppIcons.categoryNews,
      AppCategory.maps => AppIcons.categoryMaps,
      AppCategory.productivity => AppIcons.categoryProductivity,
      AppCategory.communication => AppIcons.categoryCommunication,
      AppCategory.browser => AppIcons.webAllowed,
      AppCategory.system => AppIcons.settings,
      AppCategory.other => AppIcons.categoryOther,
    };
  }
}
