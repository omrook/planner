import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import '../models/planner_tab.dart';
import '../models/task.dart';
import '../providers/app_provider.dart';
import '../data/hive_boxes.dart';
import '../models/app_settings.dart';
import 'settings_screen.dart';
import 'tabs_editor_screen.dart';
import 'widgets/scrollable_bottom_tabs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  bool _restoring = true;
  bool _sortByDateDesc = true; // newest first by default

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Restore last tab id from settings box if present
      try {
        final settingsBox = Hive.box<AppSettings>(HiveBoxes.settings);
        final saved = settingsBox.get('app');
        final app = context.read<AppProvider>();
        final tabs = app.tabs;
        if (saved != null) {
          // Restore sort preference
          _sortByDateDesc = saved.sortByDateDesc;
          // Restore last tab
          if (saved.lastTabId != null) {
            final idx = tabs.indexWhere((t) => t.id == saved.lastTabId);
            if (idx >= 0) {
              setState(() {
                _currentIndex = idx;
                _restoring = false;
              });
              if (_pageController.hasClients) {
                _pageController.jumpToPage(idx);
              }
              return;
            }
          }
        }
      } catch (_) {}
      if (mounted) setState(() => _restoring = false);
    });
  }

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final tabs = app.tabs;
    if (tabs.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final int safeIndex = _currentIndex.clamp(0, tabs.length - 1).toInt();

    // Ensure controller/index stay in sync when tabs are added/removed
    if (_currentIndex != safeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _currentIndex = safeIndex);
        if (_pageController.hasClients) {
          _pageController.jumpToPage(safeIndex);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        elevation: 2,
        centerTitle: true,
        title: const Text('Planner'),
        leading: IconButton(
          icon: Icon(
            _sortByDateDesc ? Icons.arrow_downward : Icons.arrow_upward,
          ),
          tooltip: _sortByDateDesc
              ? 'Sort: Newest first'
              : 'Sort: Oldest first',
          onPressed: () async {
            setState(() => _sortByDateDesc = !_sortByDateDesc);
            // persist sort preference
            final settingsBox = Hive.box<AppSettings>(HiveBoxes.settings);
            final current = settingsBox.get('app') ?? AppSettings();
            current.sortByDateDesc = _sortByDateDesc;
            await settingsBox.put('app', current);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Edit tabs',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TabsEditorScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: tabs.length,
        onPageChanged: (i) async {
          setState(() => _currentIndex = i);
          // persist last tab id
          final settingsBox = Hive.box<AppSettings>(HiveBoxes.settings);
          final current = settingsBox.get('app') ?? AppSettings();
          current.lastTabId = tabs[i].id;
          await settingsBox.put('app', current);
        },
        itemBuilder: (context, index) {
          final tab = tabs[index];
          return _TabTasksView(tab: tab);
        },
      ),
      bottomNavigationBar: ScrollableBottomTabs(
        tabs: tabs,
        selectedIndex: safeIndex,
        onSelected: (i) async {
          setState(() => _currentIndex = i);
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
          // persist last tab id
          final settingsBox = Hive.box<AppSettings>(HiveBoxes.settings);
          final current = settingsBox.get('app') ?? AppSettings();
          current.lastTabId = tabs[i].id;
          await settingsBox.put('app', current);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskSheet(context, tabs[safeIndex].id),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddTaskSheet(
    BuildContext context,
    String currentTabId,
  ) async {
    final app = context.read<AppProvider>();
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String targetTabId =
        currentTabId; // Keep 'ALL' when on All tab; do not auto-assign

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.of(sheetCtx).viewInsets.bottom +
                    16 +
                    MediaQuery.of(sheetCtx).padding.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Task title'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) return;
                            await app.addTask(
                              title: title,
                              notes: notesCtrl.text.trim().isEmpty
                                  ? null
                                  : notesCtrl.text.trim(),
                              tabId: targetTabId,
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.task_alt),
                          label: const Text(
                            'Add task',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabTasksView extends StatelessWidget {
  final PlannerTab tab;
  const _TabTasksView({required this.tab});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final tasks = app.tasksForTab(tab.id);

    // Get sort preference from settings
    final settingsBox = Hive.box<AppSettings>(HiveBoxes.settings);
    final settings = settingsBox.get('app') ?? AppSettings();
    final sortDesc = settings.sortByDateDesc;

    final active = tasks.where((t) => !t.isCompleted).toList()
      ..sort(
        (a, b) => sortDesc
            ? b.createdAt.compareTo(a.createdAt)
            : a.createdAt.compareTo(b.createdAt),
      );
    final completed = tasks.where((t) => t.isCompleted).toList()
      ..sort(
        (a, b) => sortDesc
            ? (b.completedAt ?? b.createdAt).compareTo(
                a.completedAt ?? a.createdAt,
              )
            : (a.completedAt ?? a.createdAt).compareTo(
                b.completedAt ?? b.createdAt,
              ),
      );

    if (active.isEmpty && completed.isEmpty) {
      return Container(
        color: Color(tab.colorValue).withValues(alpha: 0.06),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'No tasks in ${tab.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Tap + to add a task',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Color(tab.colorValue).withValues(alpha: 0.06),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final task in active) _TaskTile(task: task, tab: tab),
          if (completed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ExpansionTile(
                title: Text('Completed (${completed.length})'),
                initiallyExpanded: false,
                children: [
                  for (final task in completed) _TaskTile(task: task, tab: tab),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final PlannerTab tab;
  const _TaskTile({required this.task, required this.tab});

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
      child: Slidable(
        key: ValueKey(task.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            CustomSlidableAction(
              onPressed: (_) => app.toggleComplete(task),
              backgroundColor: Colors.green,
              child: Icon(
                task.isCompleted ? Icons.undo : Icons.check,
                color: Colors.white,
                size: 26,
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) => _showMoveDialog(context, app),
              backgroundColor: Colors.blue,
              child: Icon(Icons.drive_file_move, color: Colors.white, size: 26),
            ),
            CustomSlidableAction(
              onPressed: (_) => app.deleteTask(task),
              backgroundColor: Colors.red,
              child: Icon(Icons.delete, color: Colors.white, size: 26),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(shape: border),
          child: ListTile(
            leading: Checkbox(
              value: task.isCompleted,
              onChanged: (_) => app.toggleComplete(task),
            ),
            tileColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            subtitle: task.notes == null || task.notes!.isEmpty
                ? null
                : Text(task.notes!),
            onLongPress: () => _showEditDialog(context, app, task),
          ),
        ),
      ),
    );
  }

  Future<void> _showMoveDialog(BuildContext context, AppProvider app) async {
    final tabs = app.tabs
        .where((t) => t.id != 'ALL' && t.id != task.tabId)
        .toList();
    if (tabs.isEmpty) return;
    final selected = await showModalBottomSheet<PlannerTab>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetCtx) {
        final textStyle =
            Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ) ??
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (ctx, controller) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [Text('Move task to', style: textStyle)],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (ctx, i) {
                      final t = tabs[i];
                      return ListTile(
                        title: Text(
                          t.name,
                          style: const TextStyle(fontSize: 18),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.adaptivePlatformDensity,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(sheetCtx, t),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: tabs.length,
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected != null) {
      await app.moveTask(task, selected.id);
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    AppProvider app,
    Task task,
  ) async {
    final titleCtrl = TextEditingController(text: task.title);
    final notesCtrl = TextEditingController(text: task.notes ?? '');
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Edit Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final newTitle = titleCtrl.text.trim();
                if (newTitle.isEmpty) return;
                final updated = Task(
                  id: task.id,
                  title: newTitle,
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                  createdAt: task.createdAt,
                  completedAt: task.completedAt,
                  tabId: task.tabId,
                );
                await app.updateTask(updated);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
