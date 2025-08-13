import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/planner_tab.dart';
import '../providers/app_provider.dart';

class TabsEditorScreen extends StatefulWidget {
  const TabsEditorScreen({super.key});

  @override
  State<TabsEditorScreen> createState() => _TabsEditorScreenState();
}

class _TabsEditorScreenState extends State<TabsEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final tabs = app.tabs;
    final nonSystem = tabs.where((t) => !t.isSystem).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final system = tabs.where((t) => t.isSystem).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Tabs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTabDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Tab'),
      ),
      body: ListView(
        children: [
          ...system.map(
            (t) => ListTile(
              leading: const Icon(Icons.lock),
              title: Text(t.name),
              subtitle: const Text('Default tab (cannot delete)'),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Text(
              'Reorder, rename, delete, or recolor tabs',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > nonSystem.length) newIndex = nonSystem.length;
              if (oldIndex < newIndex) newIndex -= 1;
              final item = nonSystem.removeAt(oldIndex);
              nonSystem.insert(newIndex, item);
              // Build ordered ids keeping system at their order indices first
              final orderedIds = [
                ...system.map((e) => e.id),
                ...nonSystem.map((e) => e.id),
              ];
              await context.read<AppProvider>().reorderTabs(orderedIds);
              setState(() {});
            },
            itemCount: nonSystem.length,
            itemBuilder: (context, index) {
              final t = nonSystem[index];
              return ListTile(
                key: ValueKey(t.id),
                leading: const Icon(Icons.drag_handle),
                title: Text(t.name),
                subtitle: Row(
                  children: [
                    const Text('Color: '),
                    Container(
                      width: 16,
                      height: 16,
                      color: Color(t.colorValue),
                    ),
                  ],
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.palette),
                      tooltip: 'Change color',
                      onPressed: () => _pickColor(context, t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Rename',
                      onPressed: () => _renameDialog(context, t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Delete',
                      onPressed: () =>
                          context.read<AppProvider>().deleteTab(t.id),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _addTabDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    Color selected = Colors.indigo;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Tab'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Tab name'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Color: '),
                GestureDetector(
                  onTap: () async {
                    final c = await _colorPickerDialog(context, selected);
                    if (c != null) {
                      selected = c;
                      // ignore: use_build_context_synchronously
                      (context as Element).markNeedsBuild();
                    }
                  },
                  child: Container(width: 20, height: 20, color: selected),
                ),
              ],
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
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await context.read<AppProvider>().addTab(name, selected);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameDialog(BuildContext context, PlannerTab tab) async {
    final ctrl = TextEditingController(text: tab.name);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Tab'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await context.read<AppProvider>().renameTab(tab.id, name);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor(BuildContext context, PlannerTab tab) async {
    final c = await _colorPickerDialog(context, Color(tab.colorValue));
    if (!context.mounted) return;
    if (c != null) {
      await context.read<AppProvider>().setTabColor(tab.id, c);
    }
  }

  Future<Color?> _colorPickerDialog(BuildContext context, Color initial) async {
    final palette = <Color>[
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.blueGrey,
      Colors.grey,
    ];
    return showDialog<Color>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick a color'),
        content: SizedBox(
          width: 300,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in palette)
                GestureDetector(
                  onTap: () => Navigator.pop(context, c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
