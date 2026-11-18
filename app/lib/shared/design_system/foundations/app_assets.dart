import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Arquivos embutidos usados pelo Design System.
abstract final class AppAssets {
  /// Licenca da fonte Manrope (SIL Open Font License 1.1).
  static const String manropeLicense = 'assets/fonts/manrope/OFL.txt';

  /// Registra a licenca da fonte para aparecer na tela de licencas do app.
  static void registerLicenses() {
    LicenseRegistry.addLicense(() async* {
      final String text = await rootBundle.loadString(manropeLicense);
      yield LicenseEntryWithLineBreaks(<String>['Manrope'], text);
    });
  }
}
