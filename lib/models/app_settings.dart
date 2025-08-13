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

  AppSettings({
    this.autoBackup = 'none',
    this.lastBackupAt,
    this.lastTabId,
    this.sortByDateDesc = true,
  });
}
