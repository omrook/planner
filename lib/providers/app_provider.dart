import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/planner_tab.dart';
import '../models/task.dart';

class AppProvider extends ChangeNotifier {
  final Uuid _uuid = const Uuid();

  late final Box<PlannerTab> _tabsBox;
  late final Box<Task> _tasksBox;

  List<PlannerTab> get tabs =>
      _tabsBox.values.toList()
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  List<Task> tasksForTab(String tabId) {
    if (tabId == 'ALL') {
      return _tasksBox.values.toList();
    }
    return _tasksBox.values.where((t) => t.tabId == tabId).toList();
  }

  Future<void> init({
    required Box<PlannerTab> tabsBox,
    required Box<Task> tasksBox,
  }) async {
    _tabsBox = tabsBox;
    _tasksBox = tasksBox;
    if (_tabsBox.isEmpty) {
      await _seedDefaultTabs();
    } else {
      await _ensureDefaultTabsPresent();
    }
  }

  Future<void> _seedDefaultTabs() async {
    final defaults = [
      PlannerTab(
        id: 'ALL',
        name: 'All',
        colorValue: Colors.grey.toARGB32(),
        isSystem: true,
        orderIndex: 0,
      ),
      PlannerTab(
        id: _uuid.v4(),
        name: 'Today',
        colorValue: Colors.blue.toARGB32(),
        orderIndex: 1,
      ),
      PlannerTab(
        id: _uuid.v4(),
        name: 'Week',
        colorValue: Colors.green.toARGB32(),
        orderIndex: 2,
      ),
      PlannerTab(
        id: _uuid.v4(),
        name: 'Monthly',
        colorValue: Colors.orange.toARGB32(),
        orderIndex: 3,
      ),
    ];
    for (final t in defaults) {
      await _tabsBox.put(t.id, t);
    }
  }

  Future<void> _ensureDefaultTabsPresent() async {
    // Ensure the 'ALL' system tab is present and at index 0
    final all = _tabsBox.get('ALL');
    if (all == null) {
      await _tabsBox.put(
        'ALL',
        PlannerTab(
          id: 'ALL',
          name: 'All',
          colorValue: Colors.grey.toARGB32(),
          isSystem: true,
          orderIndex: 0,
        ),
      );
    }

    // If only ALL exists (fresh or previously broken state), add the default non-system tabs
    final current = _tabsBox.values.toList();
    if (current.length == 1 && current.first.id == 'ALL') {
      final nextIndex = 1;
      final defaults = [
        PlannerTab(
          id: _uuid.v4(),
          name: 'Today',
          colorValue: Colors.blue.toARGB32(),
          orderIndex: nextIndex,
        ),
        PlannerTab(
          id: _uuid.v4(),
          name: 'Week',
          colorValue: Colors.green.toARGB32(),
          orderIndex: nextIndex + 1,
        ),
        PlannerTab(
          id: _uuid.v4(),
          name: 'Monthly',
          colorValue: Colors.orange.toARGB32(),
          orderIndex: nextIndex + 2,
        ),
      ];
      for (final t in defaults) {
        await _tabsBox.put(t.id, t);
      }
    }

    // Ensure orderIndex continuity
    final sorted = tabs;
    for (int i = 0; i < sorted.length; i++) {
      final t = sorted[i];
      if (t.orderIndex != i) {
        await _tabsBox.put(
          t.id,
          PlannerTab(
            id: t.id,
            name: t.name,
            colorValue: t.colorValue,
            isSystem: t.isSystem,
            orderIndex: i,
          ),
        );
      }
    }
  }

  Future<void> addTask({
    required String title,
    String? notes,
    required String tabId,
  }) async {
    final task = Task(
      id: _uuid.v4(),
      title: title,
      notes: notes,
      createdAt: DateTime.now(),
      tabId: tabId,
    );
    await _tasksBox.put(task.id, task);
    notifyListeners();
  }

  Future<void> toggleComplete(Task task) async {
    final updated = Task(
      id: task.id,
      title: task.title,
      notes: task.notes,
      createdAt: task.createdAt,
      completedAt: task.isCompleted ? null : DateTime.now(),
      tabId: task.tabId,
    );
    await _tasksBox.put(task.id, updated);
    notifyListeners();
  }

  Future<void> deleteTask(Task task) async {
    await _tasksBox.delete(task.id);
    notifyListeners();
  }

  Future<void> updateTask(Task updated) async {
    await _tasksBox.put(updated.id, updated);
    notifyListeners();
  }

  Future<void> moveTask(Task task, String newTabId) async {
    final updated = Task(
      id: task.id,
      title: task.title,
      notes: task.notes,
      createdAt: task.createdAt,
      completedAt: task.completedAt,
      tabId: newTabId,
    );
    await _tasksBox.put(task.id, updated);
    notifyListeners();
  }

  Future<void> addTab(String name, Color color) async {
    final id = _uuid.v4();
    final index = _tabsBox.length;
    final tab = PlannerTab(
      id: id,
      name: name,
      colorValue: color.toARGB32(),
      orderIndex: index,
    );
    await _tabsBox.put(id, tab);
    notifyListeners();
  }

  Future<void> renameTab(String id, String newName) async {
    final tab = _tabsBox.get(id);
    if (tab == null || tab.isSystem) return;
    final updated = PlannerTab(
      id: tab.id,
      name: newName,
      colorValue: tab.colorValue,
      isSystem: tab.isSystem,
      orderIndex: tab.orderIndex,
    );
    await _tabsBox.put(id, updated);
    notifyListeners();
  }

  Future<void> deleteTab(String id) async {
    final tab = _tabsBox.get(id);
    if (tab == null || tab.isSystem) return;
    // Move tasks to ALL on delete
    final toMove = _tasksBox.values.where((t) => t.tabId == id);
    for (final t in toMove) {
      await moveTask(t, 'ALL');
    }
    await _tabsBox.delete(id);
    notifyListeners();
  }

  Future<void> reorderTabs(List<String> orderedIds) async {
    for (int i = 0; i < orderedIds.length; i++) {
      final id = orderedIds[i];
      final tab = _tabsBox.get(id);
      if (tab == null) continue;
      final updated = PlannerTab(
        id: tab.id,
        name: tab.name,
        colorValue: tab.colorValue,
        isSystem: tab.isSystem,
        orderIndex: i,
      );
      await _tabsBox.put(id, updated);
    }
    notifyListeners();
  }

  Future<void> setTabColor(String id, Color color) async {
    final tab = _tabsBox.get(id);
    if (tab == null) return;
    final updated = PlannerTab(
      id: tab.id,
      name: tab.name,
      colorValue: color.toARGB32(),
      isSystem: tab.isSystem,
      orderIndex: tab.orderIndex,
    );
    await _tabsBox.put(id, updated);
    notifyListeners();
  }
}
