import 'package:equatable/equatable.dart';

/// Pagina que o filtro nao deixou abrir.
final class BlockedPage extends Equatable {
  const BlockedPage({required this.url, this.reason, this.category});

  final String url;
  final String? reason;
  final String? category;

  /// Dominio do endereco bloqueado, para mostrar na tela.
  String get domain => Uri.tryParse(url)?.host ?? url;

  @override
  List<Object?> get props => <Object?>[url, reason, category];
}
