import 'package:flutter/material.dart';

import '../../models/planner_tab.dart';

class ScrollableBottomTabs extends StatelessWidget {
  final List<PlannerTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double maxVisible; // number of visible tabs before scroll

  const ScrollableBottomTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.maxVisible = 4,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: true,
      child: Material(
        elevation: 3,
        color: colorScheme.surface,
        child: SizedBox(
          height: 64,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            itemBuilder: (context, index) {
              final t = tabs[index];
              final selected = index == selectedIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ChoiceChip(
                  label: Text(
                    t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: selected,
                  onSelected: (_) => onSelected(index),
                  selectedColor: colorScheme.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: selected ? colorScheme.primary : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
