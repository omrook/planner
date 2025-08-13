import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';
import '../models/planner_tab.dart';
import '../models/task.dart';

class BackupService {
  final Box<PlannerTab> tabsBox;
  final Box<Task> tasksBox;
  final Box<AppSettings> settingsBox;

  BackupService({
    required this.tabsBox,
    required this.tasksBox,
    required this.settingsBox,
  });

  Future<String> get backupPath async {
    if (!kIsWeb) {
      // Try external storage directory first (more reliable on Android)
      try {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          final backupDir = Directory('${dir.path}/Backups');
          await backupDir.create(recursive: true);
          return '${backupDir.path}/planner_backup.json';
        }
      } catch (e) {
        debugPrint('External storage not available: $e');
      }
    }

    // Fallback to application documents directory
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/Backups');
    await backupDir.create(recursive: true);
    return '${backupDir.path}/planner_backup.json';
  }

  Future<String> generateBackupFilename() async {
    return 'planner_backup_${DateTime.now().toIso8601String().replaceAll(':', '-')}.json';
  }

  Future<File> exportToDocuments() async {
    try {
      final path = await backupPath;
      final file = File(path);
      final data = await _buildBackupJson();
      await file.writeAsString(jsonEncode(data));
      return file;
    } catch (e) {
      debugPrint('Backup failed: $e');
      rethrow;
    }
  }

  Future<String> get backupDirectoryPath async {
    if (!kIsWeb) {
      try {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          final backupDir = Directory('${dir.path}/Backups');
          await backupDir.create(recursive: true);
          return backupDir.path;
        }
      } catch (e) {
        debugPrint('External storage not available: $e');
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/Backups');
    await backupDir.create(recursive: true);
    return backupDir.path;
  }

  Future<List<FileSystemEntity>> listBackups() async {
    final dir = Directory(await backupDirectoryPath);
    final files = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .toList();

    // Sort by modification time, newest first
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files;
  }

  Future<File?> getLatestBackup() async {
    try {
      final backups = await listBackups();
      if (backups.isNotEmpty) {
        return backups.first as File;
      }
    } catch (e) {
      debugPrint('Failed to get latest backup: $e');
    }
    return null;
  }

  Future<File> exportToDownloads() async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir == null) {
        throw Exception('Could not access Downloads directory');
      }
      final filename = await generateBackupFilename();
      final file = File('${dir.path}/$filename');
      final data = await _buildBackupJson();
      await file.writeAsString(jsonEncode(data));
      return file;
    } catch (e) {
      debugPrint('Export to downloads failed: $e');
      rethrow;
    }
  }

  Future<void> importFromFilePath(String path) async {
    final file = File(path);
    final str = await file.readAsString();
    final json = jsonDecode(str) as Map<String, dynamic>;
    await _restoreFromJson(json);
  }

  Future<void> maybeAutoBackup() async {
    try {
      final settings = settingsBox.get('app') ?? AppSettings();
      final now = DateTime.now();
      bool should = false;
      if (settings.autoBackup == 'daily') {
        if (settings.lastBackupAt == null ||
            !_isSameDay(settings.lastBackupAt!, now)) {
          should = true;
        }
      } else if (settings.autoBackup == 'weekly') {
        if (settings.lastBackupAt == null ||
            now.difference(settings.lastBackupAt!).inDays >= 7) {
          should = true;
        }
      }
      if (should) {
        await exportToDocuments();
        settings.lastBackupAt = now;
        await settingsBox.put('app', settings);
      }
    } catch (e) {
      // Silently fail auto-backup to avoid blocking app startup
      debugPrint('Auto-backup failed: $e');
    }
  }

  Future<Map<String, dynamic>> buildBackupJson() async => _buildBackupJson();

  Future<void> restoreFromJson(Map<String, dynamic> json) async =>
      _restoreFromJson(json);

  Future<Map<String, dynamic>> _buildBackupJson() async {
    return {
      'version': 1,
      'tabs': tabsBox.values
          .map(
            (t) => {
              'id': t.id,
              'name': t.name,
              'colorValue': t.colorValue,
              'isSystem': t.isSystem,
              'orderIndex': t.orderIndex,
            },
          )
          .toList(),
      'tasks': tasksBox.values
          .map(
            (t) => {
              'id': t.id,
              'title': t.title,
              'notes': t.notes,
              'createdAt': t.createdAt.toIso8601String(),
              'completedAt': t.completedAt?.toIso8601String(),
              'tabId': t.tabId,
            },
          )
          .toList(),
      'settings': {
        'autoBackup': (settingsBox.get('app') ?? AppSettings()).autoBackup,
        'lastBackupAt': (settingsBox.get('app')?.lastBackupAt)
            ?.toIso8601String(),
        'lastTabId': (settingsBox.get('app')?.lastTabId),
        'sortByDateDesc': (settingsBox.get('app')?.sortByDateDesc) ?? true,
      },
    };
  }

  Future<void> _restoreFromJson(Map<String, dynamic> json) async {
    await tabsBox.clear();
    await tasksBox.clear();

    final tabs = (json['tabs'] as List).cast<Map<String, dynamic>>();
    for (final t in tabs) {
      await tabsBox.put(
        t['id'] as String,
        PlannerTab(
          id: t['id'] as String,
          name: t['name'] as String,
          colorValue: t['colorValue'] as int,
          isSystem: t['isSystem'] as bool,
          orderIndex: t['orderIndex'] as int,
        ),
      );
    }

    final tasks = (json['tasks'] as List).cast<Map<String, dynamic>>();
    for (final t in tasks) {
      await tasksBox.put(
        t['id'] as String,
        Task(
          id: t['id'] as String,
          title: t['title'] as String,
          notes: t['notes'] as String?,
          createdAt: DateTime.parse(t['createdAt'] as String),
          completedAt: t['completedAt'] == null
              ? null
              : DateTime.parse(t['completedAt'] as String),
          tabId: t['tabId'] as String,
        ),
      );
    }

    final s = json['settings'] as Map<String, dynamic>?;
    if (s != null) {
      final settings = AppSettings(
        autoBackup: (s['autoBackup'] as String?) ?? 'none',
        lastBackupAt: (s['lastBackupAt'] as String?) == null
            ? null
            : DateTime.parse(s['lastBackupAt'] as String),
        lastTabId: s['lastTabId'] as String?,
        sortByDateDesc: (s['sortByDateDesc'] as bool?) ?? true,
      );
      await settingsBox.put('app', settings);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
