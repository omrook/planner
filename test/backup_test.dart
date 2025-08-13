import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:planner/data/hive_boxes.dart';
import 'package:planner/models/app_settings.dart';
import 'package:planner/models/planner_tab.dart';
import 'package:planner/models/task.dart';
import 'package:planner/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Backup and restore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('planner_test');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PlannerTabAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(TaskAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(AppSettingsAdapter());
      }
      await Hive.openBox<PlannerTab>(HiveBoxes.tabs);
      await Hive.openBox<Task>(HiveBoxes.tasks);
      await Hive.openBox<AppSettings>(HiveBoxes.settings);
    });

    tearDown(() async {
      await Hive.close();
    });

    test('Export builds expected JSON shape', () async {
      final tabs = Hive.box<PlannerTab>(HiveBoxes.tabs);
      final tasks = Hive.box<Task>(HiveBoxes.tasks);
      final settings = Hive.box<AppSettings>(HiveBoxes.settings);

      await tabs.put(
        'ALL',
        PlannerTab(
          id: 'ALL',
          name: 'All',
          colorValue: 0xFF9E9E9E,
          isSystem: true,
          orderIndex: 0,
        ),
      );
      await tasks.put(
        't1',
        Task(
          id: 't1',
          title: 'A',
          createdAt: DateTime(2024, 1, 1),
          tabId: 'ALL',
        ),
      );
      await settings.put(
        'app',
        AppSettings(autoBackup: 'daily', lastBackupAt: DateTime(2024, 1, 2)),
      );

      final svc = BackupService(
        tabsBox: tabs,
        tasksBox: tasks,
        settingsBox: settings,
      );
      final data = await svc.buildBackupJson();

      expect(data['version'], 1);
      expect((data['tabs'] as List).isNotEmpty, true);
      expect((data['tasks'] as List).length, 1);
      expect((data['settings'] as Map)['autoBackup'], 'daily');
    });

    test('Restore populates boxes', () async {
      final tabs = Hive.box<PlannerTab>(HiveBoxes.tabs);
      final tasks = Hive.box<Task>(HiveBoxes.tasks);
      final settings = Hive.box<AppSettings>(HiveBoxes.settings);

      final json = {
        'version': 1,
        'tabs': [
          {
            'id': 'ALL',
            'name': 'All',
            'colorValue': 0xFF9E9E9E,
            'isSystem': true,
            'orderIndex': 0,
          },
        ],
        'tasks': [
          {
            'id': 't1',
            'title': 'A',
            'notes': null,
            'createdAt': DateTime(2024, 1, 1).toIso8601String(),
            'completedAt': null,
            'tabId': 'ALL',
          },
        ],
        'settings': {
          'autoBackup': 'weekly',
          'lastBackupAt': DateTime(2024, 1, 2).toIso8601String(),
        },
      };

      final svc = BackupService(
        tabsBox: tabs,
        tasksBox: tasks,
        settingsBox: settings,
      );
      await svc.restoreFromJson(json);

      expect(tabs.length, 1);
      expect(tasks.length, 1);
      expect(settings.get('app')!.autoBackup, 'weekly');
    });
  });
}
