import 'package:hive/hive.dart';

part 'task.g.dart';

@HiveType(typeId: 2)
class Task {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String title;
  @HiveField(2)
  String? notes;
  @HiveField(3)
  DateTime createdAt;
  @HiveField(4)
  DateTime? completedAt;
  @HiveField(5)
  String tabId;

  Task({
    required this.id,
    required this.title,
    this.notes,
    required this.createdAt,
    this.completedAt,
    required this.tabId,
  });

  bool get isCompleted => completedAt != null;
}

