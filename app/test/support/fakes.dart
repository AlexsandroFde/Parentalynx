import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:parentalynx/core/navigation/launch_action.dart';
import 'package:parentalynx/core/storage/local_preferences.dart';
import 'package:parentalynx/core/storage/secure_store.dart';
import 'package:parentalynx/core/time/clock.dart';
import 'package:parentalynx/core/utils/observable_value.dart';
import 'package:parentalynx/features/app_management/presentation/services/app_icon_images.dart';
import 'package:parentalynx/features/authentication/domain/services/i_elevation_prompter.dart';
import 'package:parentalynx/features/device_sync/domain/entities/realtime_update.dart';
import 'package:parentalynx/features/device_sync/domain/repositories/i_realtime_repository.dart';
import 'package:parentalynx/shared/services/share_service.dart';

// Dubles usados so nos testes. Nenhum deles existe no codigo do app.

/// Armazenamento seguro em memoria.
class InMemorySecureStore implements SecureStore {
  InMemorySecureStore([Map<String, String>? initial]) : values = <String, String>{...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

/// Preferencias locais em memoria.
class InMemoryLocalPreferences implements LocalPreferences {
  InMemoryLocalPreferences([Map<String, Object>? initial]) : values = <String, Object>{...?initial};

  final Map<String, Object> values;

  @override
  Future<int?> readInt(String key) async {
    final Object? value = values[key];
    return value is int ? value : null;
  }

  @override
  Future<void> writeInt(String key, int value) async {
    values[key] = value;
  }

  @override
  Future<bool?> readBool(String key) async {
    final Object? value = values[key];
    return value is bool ? value : null;
  }

  @override
  Future<void> writeBool(String key, bool value) async {
    values[key] = value;
  }
}

/// Relogio controlado pelo teste.
class FakeClock implements Clock {
  FakeClock([DateTime? start]) : current = start ?? DateTime(2026, 11, 17, 15, 30);

  DateTime current;

  @override
  DateTime now() => current;

  void advance(Duration duration) {
    current = current.add(duration);
  }
}

/// Servico de compartilhamento que so registra o que foi pedido.
class FakeShareService implements ShareService {
  final List<String> copied = <String>[];
  final List<String> shared = <String>[];
  final List<String> files = <String>[];

  @override
  Future<void> copy(String text) async => copied.add(text);

  @override
  Future<void> shareText(String text, {String? subject}) async => shared.add(text);

  @override
  Future<void> shareTextFile({
    required String fileName,
    required String content,
    required String mimeType,
    String? subject,
  }) async => files.add(fileName);
}

/// Canal em tempo real controlado pelo teste: [emit] entrega um aviso.
class FakeRealtimeRepository implements IRealtimeRepository {
  final StreamController<RealtimeUpdate> _updates = StreamController<RealtimeUpdate>.broadcast();
  final ObservableValue<bool> _connected = ObservableValue<bool>.seeded(false);
  int connects = 0;
  int disconnects = 0;

  void emit(RealtimeUpdate update) => _updates.add(update);

  void setConnected({required bool connected}) => _connected.add(connected);

  @override
  Stream<RealtimeUpdate> get updates => _updates.stream;

  @override
  Stream<bool> watchConnection() => _connected.stream;

  @override
  void connect() => connects++;

  @override
  Future<void> disconnect() async => disconnects++;
}

/// Pedido de senha que responde sozinho (aceita ou recusa) e conta quantas vezes foi chamado.
class FakeElevationPrompter implements IElevationPrompter {
  FakeElevationPrompter({this.accept = true});

  bool accept;
  int requests = 0;

  @override
  Future<bool> requestElevation() async {
    requests++;
    return accept;
  }
}

/// Fonte de acoes de abertura controlada pelo teste.
class FakeLaunchActionSource implements LaunchActionSource {
  final ObservableValue<LaunchAction?> _pending = ObservableValue<LaunchAction?>.seeded(null);

  void open(LaunchAction action) => _pending.add(action);

  LaunchAction? get pending => _pending.valueOrNull;

  @override
  Stream<LaunchAction?> watchPending() => _pending.stream;

  @override
  void consume() => _pending.add(null);
}

/// Icones de apps sem rede: a tela mostra a inicial de cada app.
class NoAppIconImages implements AppIconImages {
  const NoAppIconImages();

  @override
  ImageProvider<Object>? imageFor(String? iconPath) => null;
}
