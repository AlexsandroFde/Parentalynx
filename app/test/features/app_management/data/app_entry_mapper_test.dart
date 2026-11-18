import 'package:flutter_test/flutter_test.dart';
import 'package:parentalynx/core/json/json_reader.dart';
import 'package:parentalynx/features/app_management/data/dto/app_entry_dto.dart';
import 'package:parentalynx/features/app_management/data/mappers/app_entry_mapper.dart';
import 'package:parentalynx/features/app_management/domain/entities/app_entry.dart';

void main() {
  group('AppEntry', () {
    test('le o inventario e ordena os mais usados do dia', () {
      final DeviceApps apps = AppEntryMapper.deviceApps(
        DeviceAppsDto.fromJson(
          decodeJsonObject(
            '{"day":"2026-11-17","apps":['
            '{"package":"com.a","label":"A","category":"games","todayMs":10},'
            '{"package":"com.b","label":"","category":"desconhecida","todayMs":30,"system":true,'
            '"launchable":false,"essential":true},'
            '{"package":"com.c","label":"C","category":"video","todayMs":0}]}',
          ),
        ),
      );
      expect(apps.apps[0].category, AppCategory.games);
      expect(apps.apps[1].label, 'com.b');
      expect(apps.apps[1].category, AppCategory.other);
      expect(apps.apps[1].isUserFacing, isFalse);
      expect(apps.apps[0].isUserFacing, isTrue);
      expect(apps.topToday().map((AppEntry app) => app.package), <String>['com.b', 'com.a']);
    });
  });
}
