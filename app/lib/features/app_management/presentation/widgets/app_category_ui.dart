import 'package:material_ui/material_ui.dart';

import '../../domain/entities/app_entry.dart';

/// Icone que representa cada categoria de app na interface.
extension AppCategoryUi on AppCategory {
  IconData get icon {
    return switch (this) {
      AppCategory.games => Icons.sports_esports_outlined,
      AppCategory.social => Icons.groups_outlined,
      AppCategory.video => Icons.smart_display_outlined,
      AppCategory.audio => Icons.headphones_outlined,
      AppCategory.image => Icons.photo_outlined,
      AppCategory.news => Icons.newspaper_outlined,
      AppCategory.maps => Icons.map_outlined,
      AppCategory.productivity => Icons.work_outline,
      AppCategory.communication => Icons.chat_bubble_outline,
      AppCategory.browser => Icons.public,
      AppCategory.system => Icons.settings_outlined,
      AppCategory.other => Icons.widgets_outlined,
    };
  }
}
