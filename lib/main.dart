import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'data/hive_boxes.dart';
import 'models/app_settings.dart';
import 'models/planner_tab.dart';
import 'models/task.dart';
import 'providers/app_provider.dart';
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

  runApp(MyApp(appProvider: appProvider));
}

class MyApp extends StatelessWidget {
  final AppProvider appProvider;
  const MyApp({super.key, required this.appProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: appProvider)],
      child: MaterialApp(
        title: 'Planner',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
