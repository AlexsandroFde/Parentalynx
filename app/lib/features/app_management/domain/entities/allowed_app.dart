import 'package:equatable/equatable.dart';

/// App que continua disponivel durante um bloqueio geral (excecao), neste aparelho.
final class AllowedApp extends Equatable {
  const AllowedApp({required this.packageName, required this.label, required this.category});

  final String packageName;
  final String label;

  /// Categoria do protocolo (games, social, video...).
  final String category;

  @override
  List<Object?> get props => <Object?>[packageName, label, category];
}
