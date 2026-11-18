import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regras de dependencia da arquitetura (ver `docs/adr/0001-bloc-clean-architecture.md`).
///
/// Le os imports de todos os arquivos de `lib/` e confere as camadas, as dependencias entre
/// funcionalidades e a ausencia de ciclos. Quebrar uma regra aqui e quebrar a arquitetura.
void main() {
  final Map<String, List<_Import>> graph = _readImports(Directory('lib'));

  test('o projeto tem os arquivos esperados', () {
    expect(graph.keys, contains('features/authentication/presentation/bloc/auth/auth_bloc.dart'));
    expect(graph.length, greaterThan(150));
  });

  test('nucleo e compartilhado nao dependem de funcionalidades nem da composicao', () {
    final List<String> violations = <String>[
      for (final MapEntry<String, List<_Import>> file in graph.entries)
        if (file.key.startsWith('core/') || file.key.startsWith('shared/'))
          for (final _Import import in file.value)
            if (import.isLocal &&
                (import.path.startsWith('features/') ||
                    import.path.startsWith('app/') ||
                    (file.key.startsWith('core/') && import.path.startsWith('shared/'))))
              '${file.key} -> ${import.path}',
    ];
    expect(violations, isEmpty);
  });

  test('funcionalidades nunca importam a camada de composicao (app/)', () {
    expect(
      _violations(graph, (String from, _Import import) {
        return from.startsWith('features/') && import.isLocal && import.path.startsWith('app/');
      }),
      isEmpty,
    );
  });

  test('domain e Dart puro: sem Flutter, rede, armazenamento, ponte nativa ou outras camadas', () {
    const List<String> forbiddenPackages = <String>[
      'package:flutter/',
      'package:flutter_bloc/',
      'package:bloc/',
      'package:bloc_concurrency/',
      'package:get_it/',
      'package:go_router/',
      'package:http/',
      'package:material_ui/',
      'package:shared_preferences/',
      'package:share_plus/',
      'package:web_socket_channel/',
      'package:webview_flutter/',
      'package:fl_chart/',
    ];
    const List<String> forbiddenCore = <String>[
      'core/bloc/',
      'core/json/',
      'core/network/',
      'core/platform/',
      'core/storage/',
    ];
    expect(
      _violations(graph, (String from, _Import import) {
        if (_layerOf(from) != 'domain') {
          return false;
        }
        if (!import.isLocal) {
          return forbiddenPackages.any(import.uri.startsWith);
        }
        return forbiddenCore.any(import.path.startsWith) ||
            import.path.startsWith('shared/') ||
            _layerOf(import.path) == 'data' ||
            _layerOf(import.path) == 'presentation';
      }),
      isEmpty,
    );
  });

  test('data nao conhece a apresentacao', () {
    const List<String> forbiddenPackages = <String>[
      'package:flutter_bloc/',
      'package:bloc/',
      'package:get_it/',
      'package:go_router/',
      'package:material_ui/',
    ];
    expect(
      _violations(graph, (String from, _Import import) {
        if (_layerOf(from) != 'data') {
          return false;
        }
        if (!import.isLocal) {
          return forbiddenPackages.any(import.uri.startsWith);
        }
        return _layerOf(import.path) == 'presentation' || import.path.startsWith('shared/');
      }),
      isEmpty,
    );
  });

  test('apresentacao depende so do dominio: sem dados, rede, armazenamento ou ponte nativa', () {
    const List<String> forbiddenCore = <String>[
      'core/json/',
      'core/network/',
      'core/platform/',
      'core/storage/',
    ];
    expect(
      _violations(graph, (String from, _Import import) {
        if (_layerOf(from) != 'presentation') {
          return false;
        }
        if (!import.isLocal) {
          return import.uri.startsWith('package:get_it/') || import.uri.startsWith('package:http/');
        }
        return _layerOf(import.path) == 'data' || forbiddenCore.any(import.path.startsWith);
      }),
      isEmpty,
    );
  });

  test('entre funcionalidades so se usa domain ou presentation, e domain so usa domain', () {
    expect(
      _violations(graph, (String from, _Import import) {
        final String? source = _featureOf(from);
        final String? target = import.isLocal ? _featureOf(import.path) : null;
        if (source == null || target == null || source == target) {
          return false;
        }
        // Arquivos de composicao da funcionalidade (modulo de dependencias e rotas) podem usar
        // os auxiliares de composicao de outra funcionalidade.
        if (_isFeatureRoot(from) && _isFeatureRoot(import.path)) {
          return false;
        }
        final String? targetLayer = _layerOf(import.path);
        if (targetLayer != 'domain' && targetLayer != 'presentation') {
          return true;
        }
        return _layerOf(from) == 'domain' && targetLayer != 'domain';
      }),
      isEmpty,
    );
  });

  test('nao ha ciclos entre funcionalidades', () {
    final Map<String, Set<String>> features = <String, Set<String>>{};
    for (final MapEntry<String, List<_Import>> file in graph.entries) {
      final String? source = _featureOf(file.key);
      if (source == null) {
        continue;
      }
      final Set<String> targets = features.putIfAbsent(source, () => <String>{});
      for (final _Import import in file.value) {
        final String? target = import.isLocal ? _featureOf(import.path) : null;
        if (target != null && target != source) {
          targets.add(target);
        }
      }
    }
    expect(_findCycle(features), isNull, reason: 'Ciclo entre funcionalidades');
  });

  test('o conteiner de dependencias so aparece na composicao', () {
    expect(
      _violations(graph, (String from, _Import import) {
        if (import.uri != 'package:get_it/get_it.dart') {
          return false;
        }
        return !(from.startsWith('app/') || _isFeatureRoot(from));
      }),
      isEmpty,
    );
  });

  test('nao ha mais Riverpod', () {
    expect(
      _violations(graph, (String from, _Import import) {
        return import.uri.contains('riverpod');
      }),
      isEmpty,
    );
  });

  test('cada BLoC separa eventos e estados em arquivos proprios', () {
    final List<String> missing = <String>[
      for (final String file in graph.keys)
        if (file.endsWith('_bloc.dart') && file.contains('/presentation/bloc/'))
          for (final String part in <String>['_event.dart', '_state.dart'])
            if (!File('lib/${file.replaceFirst('_bloc.dart', part)}').existsSync())
              file.replaceFirst('_bloc.dart', part),
    ];
    expect(missing, isEmpty);
  });
}

final class _Import {
  const _Import(this.uri, this.path);

  /// Texto do import como escrito.
  final String uri;

  /// Caminho relativo a `lib/`, quando o import e do proprio pacote.
  final String path;

  bool get isLocal => path.isNotEmpty;
}

final RegExp _directive = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

Map<String, List<_Import>> _readImports(Directory lib) {
  final Map<String, List<_Import>> graph = <String, List<_Import>>{};
  for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart') || entity.path.endsWith('.g.dart')) {
      continue;
    }
    final String relative = _normalize(entity.path.substring(lib.path.length + 1));
    final List<_Import> imports = <_Import>[];
    for (final RegExpMatch match in _directive.allMatches(entity.readAsStringSync())) {
      final String uri = match.group(1)!;
      imports.add(_Import(uri, _resolve(relative, uri)));
    }
    graph[relative] = imports;
  }
  return graph;
}

String _normalize(String path) => path.replaceAll(r'\', '/');

/// Caminho relativo a `lib/` do arquivo importado, ou vazio para pacotes externos e `dart:`.
String _resolve(String from, String uri) {
  if (uri.startsWith('package:parentalynx/')) {
    return uri.substring('package:parentalynx/'.length);
  }
  if (uri.startsWith('package:') || uri.startsWith('dart:')) {
    return '';
  }
  final List<String> parts = from.split('/')..removeLast();
  for (final String segment in uri.split('/')) {
    if (segment == '..') {
      parts.removeLast();
    } else if (segment != '.') {
      parts.add(segment);
    }
  }
  return parts.join('/');
}

String? _featureOf(String path) {
  final List<String> parts = path.split('/');
  return parts.length > 2 && parts[0] == 'features' ? parts[1] : null;
}

/// `domain`, `data` ou `presentation`, para arquivos de funcionalidades.
String? _layerOf(String path) {
  final List<String> parts = path.split('/');
  if (parts.length > 3 && parts[0] == 'features') {
    return parts[2];
  }
  return null;
}

/// Arquivos na raiz da funcionalidade: modulo de dependencias e rotas (composicao).
bool _isFeatureRoot(String path) {
  final List<String> parts = path.split('/');
  return parts.length == 3 && parts[0] == 'features';
}

List<String> _violations(Map<String, List<_Import>> graph, bool Function(String, _Import) rule) {
  return <String>[
    for (final MapEntry<String, List<_Import>> file in graph.entries)
      for (final _Import import in file.value)
        if (rule(file.key, import)) '${file.key} -> ${import.isLocal ? import.path : import.uri}',
  ];
}

/// Devolve um ciclo (lista de funcionalidades) ou nulo.
List<String>? _findCycle(Map<String, Set<String>> graph) {
  final Set<String> done = <String>{};
  final List<String> stack = <String>[];

  List<String>? visit(String node) {
    if (stack.contains(node)) {
      return <String>[...stack.sublist(stack.indexOf(node)), node];
    }
    if (done.contains(node)) {
      return null;
    }
    stack.add(node);
    for (final String next in graph[node] ?? const <String>{}) {
      final List<String>? cycle = visit(next);
      if (cycle != null) {
        return cycle;
      }
    }
    stack.removeLast();
    done.add(node);
    return null;
  }

  for (final String node in graph.keys) {
    final List<String>? cycle = visit(node);
    if (cycle != null) {
      return cycle;
    }
  }
  return null;
}
