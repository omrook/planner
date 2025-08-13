import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../data/hive_boxes.dart';
import '../models/app_settings.dart';

class ThemeProvider extends ChangeNotifier {
  late final Box<AppSettings> _settingsBox;
  late AppSettings _settings;
  
  Color get themeColor => Color(_settings.themeColor);
  
  Future<void> init() async {
    _settingsBox = Hive.box<AppSettings>(HiveBoxes.settings);
    _settings = _settingsBox.get('app') ?? AppSettings();
  }
  
  Future<void> updateThemeColor(Color color) async {
    _settings.themeColor = color.value;
    await _settingsBox.put('app', _settings);
    notifyListeners();
  }
  
  ThemeData getTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: themeColor),
    );
  }
}
