import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/result/result.dart';
import '../../domain/usecases/get_app_icon.dart';

/// Imagens dos icones de apps para as telas do responsavel.
///
/// Servico de interface entregue pela arvore de widgets (`RepositoryProvider`). Os testes
/// usam uma versao que nao devolve imagem, para a tela mostrar a inicial do app sem rede.
abstract interface class AppIconImages {
  /// Imagem do icone no caminho informado pelo inventario, ou nulo quando nao ha icone.
  ImageProvider<Object>? imageFor(String? iconPath);
}

/// Busca os icones no servidor pelo caso de uso [GetAppIcon]. O cache de imagens do Flutter
/// guarda cada icone pelo caminho.
class RemoteAppIconImages implements AppIconImages {
  const RemoteAppIconImages(this._getAppIcon);

  final GetAppIcon _getAppIcon;

  @override
  ImageProvider<Object>? imageFor(String? iconPath) {
    if (iconPath == null || iconPath.isEmpty) {
      return null;
    }
    return _AppIconImage(iconPath, _getAppIcon);
  }
}

/// Icone baixado sob demanda. A igualdade e pelo caminho, para o cache reaproveitar.
@immutable
class _AppIconImage extends ImageProvider<_AppIconImage> {
  const _AppIconImage(this.iconPath, this._getAppIcon);

  final String iconPath;
  final GetAppIcon _getAppIcon;

  @override
  Future<_AppIconImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_AppIconImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(_AppIconImage key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_load(decode));
  }

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final Result<Uint8List?> result = await _getAppIcon(iconPath);
    final Uint8List? bytes = result.valueOrNull;
    if (bytes == null) {
      // Sem icone: a tela mostra a inicial do app (errorBuilder).
      throw StateError('Icone indisponivel: $iconPath');
    }
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final ui.Codec codec = await decode(buffer);
    final ui.FrameInfo frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) => other is _AppIconImage && other.iconPath == iconPath;

  @override
  int get hashCode => iconPath.hashCode;
}
