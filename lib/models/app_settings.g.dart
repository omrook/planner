// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 3;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      autoBackup: fields[0] as String,
      lastBackupAt: fields[1] as DateTime?,
      lastTabId: fields[2] as String?,
      sortByDateDesc: fields[3] as bool,
      themeColor: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.autoBackup)
      ..writeByte(1)
      ..write(obj.lastBackupAt)
      ..writeByte(2)
      ..write(obj.lastTabId)
      ..writeByte(3)
      ..write(obj.sortByDateDesc)
      ..writeByte(4)
      ..write(obj.themeColor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
