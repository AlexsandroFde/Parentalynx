import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regras do Design System, conferidas no codigo das funcionalidades e da composicao.
///
/// As telas usam os tokens (cores, tipografia, espacamentos, raios, sombras) e os componentes
/// do Design System em vez de valores e widgets soltos; assim todas as telas seguem a mesma
/// identidade e uma mudanca no Design System vale para o app inteiro.
///
/// Excecao justificada: um comentario `// ds-ignore: <motivo>` na mesma linha ou na linha de
/// cima. Para conferir so uma funcionalidade:
/// `flutter test test/architecture/design_system_test.dart --plain-name <funcionalidade>`.
void main() {
  final Directory features = Directory('lib/features');
  final List<String> names =
      features
          .listSync()
          .whereType<Directory>()
          .map((Directory d) => d.uri.pathSegments.where((String s) => s.isNotEmpty).last)
          .toList()
        ..sort();

  for (final String name in names) {
    test('$name segue o Design System', () {
      final List<String> violations = _check(Directory('lib/features/$name'));
      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  }

  test('a composicao (app/) segue o Design System', () {
    final List<String> violations = _check(Directory('lib/app'));
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

/// Uma regra: o que e recusado e o que usar no lugar.
class _Rule {
  const _Rule(this.pattern, this.advice);

  final RegExp pattern;
  final String advice;
}

final List<_Rule> _rules = <_Rule>[
  _Rule(
    RegExp(r'\bColor\(\s*0x|\bColor\.from(ARGB|RGBO)\('),
    'cor fora dos tokens: use context.colors',
  ),
  _Rule(RegExp(r'\bColors\.(?!transparent\b)\w+'), 'cor do Material: use context.colors'),
  _Rule(
    RegExp(r'\bTextStyle\('),
    'estilo de texto solto: use context.text ou context.textStyles com copyWith',
  ),
  _Rule(RegExp(r'\bfontSize\s*:'), 'tamanho de fonte fora da escala tipografica'),
  _Rule(RegExp(r'\bIcons\.\w+'), 'icone direto do Material: use AppIcons'),
  _Rule(RegExp(r'\b(Box)?Shadow\('), 'sombra solta: use AppElevation'),
  _Rule(
    RegExp(r'\b(FilledButton|OutlinedButton|ElevatedButton|TextButton)(\.\w+)?\('),
    'botao do Material: use AppButton',
  ),
  _Rule(RegExp(r'\bIconButton(\.\w+)?\('), 'botao de icone do Material: use AppIconButton'),
  _Rule(
    RegExp(r'\b(ListTile|SwitchListTile|CheckboxListTile|RadioListTile)\('),
    'linha do Material: use AppListRow, AppSwitchRow, AppCheckboxRow ou AppRadioRow',
  ),
  _Rule(RegExp(r'\bCard\('), 'cartao do Material: use AppPanel ou AppListGroup'),
  _Rule(
    RegExp(r'''import\s+'[^']*shared/(theme/app_theme|widgets/)'''),
    'caminho antigo: importe shared/design_system/design_system.dart',
  ),
];

/// Construcoes que recebem medidas: numeros soltos nelas sao recusados.
final RegExp _measured = RegExp(
  r'\b(EdgeInsets(Directional)?\.(all|symmetric|only|fromLTRB|fromSTEB)|'
  r'BorderRadius\.circular|Radius\.circular|SizedBox)\(',
);
final RegExp _number = RegExp(r'(?<![\w.])\d+(\.\d+)?(?![\w.])');

List<String> _check(Directory dir) {
  final List<String> violations = <String>[];
  if (!dir.existsSync()) {
    return violations;
  }
  final List<File> files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  for (final File file in files) {
    final String source = file.readAsStringSync().replaceAll('\r\n', '\n');
    final List<String> lines = source.split('\n');
    final String code = _stripCommentsAndStrings(source);
    final String path = file.path.replaceAll(r'\', '/');

    bool ignored(int offset) {
      final int line = '\n'.allMatches(source.substring(0, offset)).length;
      return lines[line].contains('ds-ignore') ||
          (line > 0 && lines[line - 1].contains('ds-ignore'));
    }

    void report(int offset, String advice) {
      if (ignored(offset)) {
        return;
      }
      final int line = '\n'.allMatches(source.substring(0, offset)).length + 1;
      violations.add('$path:$line: $advice -> ${lines[line - 1].trim()}');
    }

    // Os imports ficam dentro de texto (o caminho), entao sao conferidos no codigo original.
    for (final _Rule rule in _rules) {
      final String target = rule.advice.startsWith('caminho antigo') ? source : code;
      for (final RegExpMatch match in rule.pattern.allMatches(target)) {
        report(match.start, rule.advice);
      }
    }

    for (final RegExpMatch call in _measured.allMatches(code)) {
      final String args = _arguments(code, call.end - 1);
      final String kind = call.group(1)!;
      if (kind == 'SizedBox') {
        // Espacadores (so altura ou so largura) usam AppSpacing; caixas com as duas medidas
        // sao dimensoes de um elemento e ficam livres.
        final bool width = RegExp(r'\bwidth\s*:').hasMatch(args);
        final bool height = RegExp(r'\bheight\s*:').hasMatch(args);
        final RegExpMatch? literal = RegExp(r'\b(width|height)\s*:\s*\d+(\.\d+)?\s*[,)]')
            .firstMatch('$args)');
        if (width != height && literal != null && !literal.group(0)!.contains(': 0')) {
          report(call.start, 'espaco solto: use AppSpacing');
        }
        continue;
      }
      final bool hasNumber = _number.allMatches(args).any((RegExpMatch m) => m.group(0) != '0');
      if (hasNumber) {
        report(
          call.start,
          kind.contains('Radius')
              ? 'raio solto: use AppRadius ou context.shapes'
              : 'espacamento solto: use AppSpacing',
        );
      }
    }
  }
  return violations;
}

/// Texto entre os parenteses que comecam em [open], com parenteses aninhados.
String _arguments(String code, int open) {
  int depth = 0;
  for (int i = open; i < code.length; i++) {
    final String c = code[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) {
        return code.substring(open + 1, i);
      }
    }
  }
  return code.substring(open + 1);
}

/// Troca comentarios e o conteudo de textos por espacos, mantendo as quebras de linha (para
/// os numeros de linha continuarem certos).
String _stripCommentsAndStrings(String source) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  String blank(String s) => s.replaceAll(RegExp(r'[^\n]'), ' ');
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      final int end = source.indexOf('\n', i);
      final int stop = end < 0 ? source.length : end;
      out.write(blank(source.substring(i, stop)));
      i = stop;
    } else if (source.startsWith('/*', i)) {
      final int end = source.indexOf('*/', i + 2);
      final int stop = end < 0 ? source.length : end + 2;
      out.write(blank(source.substring(i, stop)));
      i = stop;
    } else if (source.startsWith("'''", i) || source.startsWith('"""', i)) {
      final String quote = source.substring(i, i + 3);
      final int end = source.indexOf(quote, i + 3);
      final int stop = end < 0 ? source.length : end + 3;
      out.write(blank(source.substring(i, stop)));
      i = stop;
    } else if (source[i] == "'" || source[i] == '"') {
      final String quote = source[i];
      int j = i + 1;
      while (j < source.length && source[j] != quote && source[j] != '\n') {
        j += source[j] == r'\' ? 2 : 1;
      }
      final int stop = j < source.length ? j + 1 : source.length;
      out.write(blank(source.substring(i, stop)));
      i = stop;
    } else {
      out.write(source[i]);
      i++;
    }
  }
  return out.toString();
}
