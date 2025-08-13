import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:path/path.dart' as p;
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

import '../data/hive_boxes.dart';
import '../models/app_settings.dart';
import '../models/planner_tab.dart';
import '../models/task.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late BackupService _backupService;
  AppSettings _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    final tabsBox = Hive.box<PlannerTab>(HiveBoxes.tabs);
    final tasksBox = Hive.box<Task>(HiveBoxes.tasks);
    final settingsBox = Hive.box<AppSettings>(HiveBoxes.settings);
    _backupService = BackupService(
      tabsBox: tabsBox,
      tasksBox: tasksBox,
      settingsBox: settingsBox,
    );
    _settings = settingsBox.get('app') ?? AppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(title: Text('Backup')),
          ListTile(
            title: const Text('Create backup'),
            subtitle: FutureBuilder<String>(
              future: _backupService.backupPath,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Text('Loading...');
                return Text('Will save to: ${snapshot.data}');
              },
            ),
            trailing: const Icon(Icons.backup),
            onTap: () async {
              try {
                final file = await _backupService.exportToDocuments();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Backup saved: ${file.path}')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
              }
            },
          ),

          ListTile(
            title: const Text('Save backup to Downloads'),
            subtitle: const Text(
              'Creates a backup file in your Downloads folder',
            ),
            trailing: const Icon(Icons.download),
            onTap: () async {
              try {
                final file = await _backupService.exportToDownloads();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Backup saved to Downloads: ${file.path}'),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export to Downloads failed: $e')),
                );
              }
            },
          ),

          ListTile(
            title: const Text('Restore latest backup'),
            subtitle: const Text('Restore from the last created backup file'),
            trailing: const Icon(Icons.restore),
            onTap: () async {
              try {
                final file = await _backupService.getLatestBackup();
                if (file == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No backup file found')),
                  );
                  return;
                }
                await _backupService.importFromFilePath(file.path);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Restored from latest backup successfully'),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
              }
            },
          ),

          ListTile(
            title: const Text('Restore from file'),
            subtitle: const Text('Select a backup file to restore from'),
            trailing: const Icon(Icons.drive_folder_upload),
            onTap: () async {
              final file = await openFile(
                acceptedTypeGroups: [
                  const XTypeGroup(label: 'JSON', extensions: ['json']),
                ],
              );
              if (file == null) return;
              try {
                await _backupService.importFromFilePath(file.path);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Imported backup successfully')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
              }
            },
          ),
          const Divider(),
          const ListTile(title: Text('Available Backups')),
          FutureBuilder<List<FileSystemEntity>>(
            future: _backupService.listBackups(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(
                  leading: CircularProgressIndicator(),
                  title: Text('Loading backups...'),
                );
              }

              if (snapshot.hasError) {
                return ListTile(
                  leading: const Icon(Icons.error),
                  title: const Text('Error loading backups'),
                  subtitle: Text(snapshot.error.toString()),
                );
              }

              final backups = snapshot.data ?? [];
              if (backups.isEmpty) {
                return const ListTile(
                  leading: Icon(Icons.info),
                  title: Text('No backups found'),
                );
              }

              return Column(
                children: backups.map((backup) {
                  final file = backup as File;
                  final fileName = file.path.split(Platform.pathSeparator).last;
                  final modified = file.statSync().modified;
                  return ListTile(
                    leading: const Icon(Icons.description),
                    title: Text(fileName),
                    subtitle: Text('Last modified: ${modified.toString()}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.download),
                          tooltip: 'Download to Downloads folder',
                          onPressed: () async {
                            try {
                              final downloadDir = await getDownloadsDirectory();
                              if (downloadDir == null) {
                                throw Exception(
                                  'Could not access Downloads directory',
                                );
                              }
                              final newFile = await file.copy(
                                '${downloadDir.path}/$fileName',
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Backup downloaded to: ${newFile.path}',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Download failed: $e')),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.restore),
                          tooltip: 'Restore this backup',
                          onPressed: () async {
                            try {
                              await _backupService.importFromFilePath(
                                file.path,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Backup restored successfully'),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Restore failed: $e')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          const ListTile(title: Text('Automatic backup')),
          RadioListTile<String>(
            title: const Text('None'),
            value: 'none',
            groupValue: _settings.autoBackup,
            onChanged: (v) => _updateAuto(v ?? 'none'),
          ),
          RadioListTile<String>(
            title: const Text('Daily'),
            value: 'daily',
            groupValue: _settings.autoBackup,
            onChanged: (v) => _updateAuto(v ?? 'daily'),
          ),
          RadioListTile<String>(
            title: const Text('Weekly'),
            value: 'weekly',
            groupValue: _settings.autoBackup,
            onChanged: (v) => _updateAuto(v ?? 'weekly'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAuto(String v) async {
    final settingsBox = Hive.box<AppSettings>(HiveBoxes.settings);
    _settings.autoBackup = v;
    await settingsBox.put('app', _settings);
    setState(() {});
  }
}
