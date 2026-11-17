import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../domain/app_entry.dart';

/// Cria o provedor de imagem de um icone autenticado. Os testes trocam por um que devolve
/// nulo, para nao fazer rede.
typedef AppIconImageFactory = ImageProvider<Object>? Function(Uri uri, Map<String, String> headers);

final Provider<AppIconImageFactory> appIconImageFactoryProvider = Provider<AppIconImageFactory>((
  Ref ref,
) {
  return (Uri uri, Map<String, String> headers) => NetworkImage(uri.toString(), headers: headers);
});

/// Icone de um app do aparelho monitorado.
///
/// O icone vem do servidor por um caminho autenticado. Enquanto carrega, se nao existir ou se
/// falhar, mostra a inicial do app sobre uma cor derivada do nome do pacote.
class AppIconView extends ConsumerWidget {
  const AppIconView({
    required this.package,
    required this.label,
    this.iconUrl,
    this.size = 40,
    super.key,
  });

  factory AppIconView.forApp(AppEntry app, {double size = 40, Key? key}) {
    return AppIconView(
      package: app.package,
      label: app.label,
      iconUrl: app.iconUrl,
      size: size,
      key: key,
    );
  }

  final String package;
  final String label;
  final String? iconUrl;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget fallback = _LetterIcon(package: package, label: label, size: size);
    final ImageProvider<Object>? image = _resolveImage(ref);
    if (image == null) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image(
        image: image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        frameBuilder: (BuildContext context, Widget child, int? frame, bool sync) {
          return frame == null && !sync ? fallback : child;
        },
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) => fallback,
      ),
    );
  }

  ImageProvider<Object>? _resolveImage(WidgetRef ref) {
    final String? path = iconUrl;
    if (path == null || path.isEmpty) {
      return null;
    }
    final ApiClient api = ref.watch(apiClientProvider);
    try {
      final Uri relative = Uri.parse(path);
      final Uri absolute = relative.hasScheme
          ? relative
          : api.resolve(relative.path, query: relative.queryParameters);
      return ref.watch(appIconImageFactoryProvider)(absolute, api.sessionHeaders());
    } on AppFailure {
      return null;
    } on FormatException {
      return null;
    }
  }
}

class _LetterIcon extends StatelessWidget {
  const _LetterIcon({required this.package, required this.label, required this.size});

  final String package;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    // Matiz estavel por pacote: o mesmo app tem sempre a mesma cor.
    final double hue = (package.hashCode & 0x7fffffff) % 360.0;
    final Color background = HSLColor.fromAHSL(1, hue, 0.45, dark ? 0.36 : 0.46).toColor();
    final String trimmed = label.trim();
    final String initial = trimmed.isEmpty
        ? '?'
        : String.fromCharCode(trimmed.runes.first).toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.24),
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.46,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
