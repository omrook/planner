// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planner_tab.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlannerTabAdapter extends TypeAdapter<PlannerTab> {
  @override
  final int typeId = 1;

  @override
  PlannerTab read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlannerTab(
      id: fields[0] as String,
      name: fields[1] as String,
      colorValue: fields[2] as int,
      isSystem: fields[3] as bool,
      orderIndex: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PlannerTab obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.colorValue)
      ..writeByte(3)
      ..write(obj.isSystem)
      ..writeByte(4)
      ..write(obj.orderIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannerTabAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
