import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/hive_boxes.dart';
import '../models/app_settings.dart';
import '../models/planner_tab.dart';
import '../models/task.dart';
import '../providers/theme_provider.dart';
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

  Future<void> _updateAuto(String v) async {
    final settingsBox = Hive.box<AppSettings>(HiveBoxes.settings);
    _settings.autoBackup = v;
    await settingsBox.put('app', _settings);
    setState(() {});
  }

  Widget _buildSettingsSection({
    required BuildContext context,
    required Widget leading,
    required String title,
    required String subtitle,
    required List<Widget> children,
    required ThemeProvider themeProvider,
  }) {
    final theme = Theme.of(context);
    final themeColor = themeProvider.themeColor;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          listTileTheme: theme.listTileTheme.copyWith(
            iconColor: themeColor,
          ),
        ),
        child: ExpansionTile(
          title: Text(title),
          subtitle: Text(subtitle),
          leading: leading,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(children: children),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Theme Color Section
          _buildSettingsSection(
            context: context,
            themeProvider: themeProvider,
            leading: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: themeProvider.themeColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
            ),
            title: 'App Theme',
            subtitle: 'Customize app appearance',
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose a color to customize the app\'s appearance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: SingleChildScrollView(
                        child: ColorPicker(
                          pickerColor: themeProvider.themeColor,
                          onColorChanged: (color) => themeProvider.updateThemeColor(color),
                          pickerAreaHeightPercent: 0.7,
                          enableAlpha: false,
                          displayThumbColor: true,
                          portraitOnly: true,
                          hexInputBar: true,
                          labelTypes: const [],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Backup Operations Section
          _buildSettingsSection(
            context: context,
            themeProvider: themeProvider,
            leading: const Icon(Icons.backup),
            title: 'Backup Operations',
            subtitle: 'Create or restore backups',
            children: [
              ListTile(
                title: const Text('Create backup'),
                subtitle: FutureBuilder<String>(
                  future: _backupService.backupPath,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Text('Loading...');
                    return Text('Will save to: ${snapshot.data}');
                  },
                ),
                leading: const Icon(Icons.save),
                onTap: () async {
                  try {
                    final file = await _backupService.exportToDocuments();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Backup saved: ${file.path}')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                },
              ),
              ListTile(
                title: const Text('Save to Downloads'),
                subtitle: const Text('Creates a backup in Downloads folder'),
                leading: const Icon(Icons.download),
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
                subtitle: const Text('Restore from the last created backup'),
                leading: const Icon(Icons.restore),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Restore failed: $e')),
                    );
                  }
                },
              ),
              ListTile(
                title: const Text('Restore from file'),
                subtitle: const Text('Select a backup file to restore from'),
                leading: const Icon(Icons.folder_open),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Import failed: $e')),
                    );
                  }
                },
              ),
            ],
          ),

          // Backup History Section
          _buildSettingsSection(
            context: context,
            themeProvider: themeProvider,
            leading: const Icon(Icons.history),
            title: 'Backup History',
            subtitle: 'View and manage existing backups',
            children: [
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
                              tooltip: 'Save to Downloads',
                              onPressed: () async {
                                try {
                                  final downloadDir = await getDownloadsDirectory();
                                  if (downloadDir == null) {
                                    throw Exception('Could not access Downloads directory');
                                  }
                                  final newFile = await file.copy(
                                    '${downloadDir.path}/${file.path.split(Platform.pathSeparator).last}',
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
                                  await _backupService.importFromFilePath(file.path);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Backup restored successfully')),
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
            ],
          ),

          // Auto Backup Settings Section
          _buildSettingsSection(
            context: context,
            themeProvider: themeProvider,
            leading: const Icon(Icons.schedule),
            title: 'Auto Backup Settings',
            subtitle: _settings.autoBackup == 'none'
                ? 'Auto backup: Off'
                : 'Auto backup: Every ${_settings.autoBackup}',
            children: [
              RadioListTile<String>(
                title: const Text('Off'),
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
        ],
      ),
    );
  }
}
