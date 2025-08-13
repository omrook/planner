import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 3)
class AppSettings {
  @HiveField(0)
  String autoBackup; // 'none' | 'daily' | 'weekly'
  @HiveField(1)
  DateTime? lastBackupAt;
  @HiveField(2)
  String? lastTabId; // persist last selected tab id
  @HiveField(3)
  bool sortByDateDesc; // true = newest first, false = oldest first
  @HiveField(4)
  int themeColor; // store theme color as int value

  AppSettings({
    this.autoBackup = 'none',
    this.lastBackupAt,
    this.lastTabId,
    this.sortByDateDesc = true,
    this.themeColor = 0xFF2196F3, // default blue color
  });
}
