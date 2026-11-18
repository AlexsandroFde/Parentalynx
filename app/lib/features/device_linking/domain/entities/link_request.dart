import 'package:equatable/equatable.dart';

/// Pedido de vinculo feito pelo aparelho da crianca, visto pelo responsavel.
///
/// Depois da aprovacao, os mesmos dados descrevem o aparelho vinculado (com o nome da crianca
/// e, quando o aparelho ja era conhecido da conta, o identificador do cadastro antigo).
final class LinkRequest extends Equatable {
  const LinkRequest({
    required this.id,
    required this.deviceName,
    required this.childName,
    required this.model,
    required this.manufacturer,
    required this.androidRelease,
    required this.relink,
    required this.createdAt,
    this.confirmCode,
  });

  final String id;

  /// Nome do aparelho informado pelo sistema, por exemplo "Moto G de João".
  final String deviceName;

  /// Nome da crianca. Vazio enquanto o pedido nao foi aprovado, a menos que o aparelho ja
  /// tenha sido vinculado antes.
  final String childName;
  final String model;
  final String manufacturer;
  final String androidRelease;

  /// O aparelho ja foi vinculado a esta conta: aprovar mantem as regras e o historico.
  final bool relink;
  final int createdAt;

  /// Numero de confirmacao mostrado nos dois aparelhos.
  final String? confirmCode;

  /// Nome para mostrar: o da crianca, ou o do aparelho.
  String get displayName => childName.isNotEmpty ? childName : deviceName;

  /// Descricao do hardware: "motorola moto g54, Android 14".
  String get hardwareLabel {
    final String name = <String>[
      manufacturer,
      model,
    ].where((String part) => part.isNotEmpty).join(' ');
    return androidRelease.isEmpty ? name : '$name, Android $androidRelease';
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    deviceName,
    childName,
    model,
    manufacturer,
    androidRelease,
    relink,
    createdAt,
    confirmCode,
  ];
}
