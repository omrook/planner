import 'package:hive/hive.dart';

part 'planner_tab.g.dart';

@HiveType(typeId: 1)
class PlannerTab {
  @HiveField(0)
  final String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  int colorValue;
  @HiveField(3)
  bool isSystem;
  @HiveField(4)
  int orderIndex;

  PlannerTab({
    required this.id,
    required this.name,
    required this.colorValue,
    this.isSystem = false,
    required this.orderIndex,
  });
}

