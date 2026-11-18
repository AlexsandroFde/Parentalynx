import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Copiar e compartilhar textos e arquivos pelo sistema.
///
/// E um servico de interface (area de transferencia e folha de compartilhamento), entregue as
/// telas pela arvore de widgets (`RepositoryProvider`). Fica atras de uma interface para que
/// as telas possam ser testadas sem o Android.
abstract interface class ShareService {
  Future<void> copy(String text);

  Future<void> shareText(String text, {String? subject});

  /// Compartilha um arquivo de texto montado em memoria (exportacao de dados).
  Future<void> shareTextFile({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  });
}

class SystemShareService implements ShareService {
  const SystemShareService();

  @override
  Future<void> copy(String text) => Clipboard.setData(ClipboardData(text: text));

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  @override
  Future<void> shareTextFile({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  }) async {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(content));
    await SharePlus.instance.share(
      ShareParams(
        subject: subject,
        files: <XFile>[XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        fileNameOverrides: <String>[fileName],
      ),
    );
  }
}
