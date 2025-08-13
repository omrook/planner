import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'data/hive_boxes.dart';
import 'models/app_settings.dart';
import 'models/planner_tab.dart';
import 'models/task.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'ui/home_screen.dart';
import 'services/backup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive
    ..registerAdapter(PlannerTabAdapter())
    ..registerAdapter(TaskAdapter())
    ..registerAdapter(AppSettingsAdapter());

  final tabsBox = await Hive.openBox<PlannerTab>(HiveBoxes.tabs);
  final tasksBox = await Hive.openBox<Task>(HiveBoxes.tasks);
  final settingsBox = await Hive.openBox<AppSettings>(HiveBoxes.settings);

  final appProvider = AppProvider();
  await appProvider.init(tabsBox: tabsBox, tasksBox: tasksBox);

  // Auto-backup on startup according to settings
  await BackupService(
    tabsBox: tabsBox,
    tasksBox: tasksBox,
    settingsBox: settingsBox,
  ).maybeAutoBackup();

  // Initialize theme provider
  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(MyApp(appProvider: appProvider, themeProvider: themeProvider));
}

class MyApp extends StatelessWidget {
  final AppProvider appProvider;
  final ThemeProvider themeProvider;
  
  const MyApp({
    super.key, 
    required this.appProvider,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Planner',
          theme: theme.getTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
