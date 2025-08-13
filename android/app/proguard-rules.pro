# Flutter/Android minimal keep rules
# Keep Flutter classes and Application
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.example.planner.planner.** { *; }

# Keep Hive generated adapters (by convention end with Adapter)
-keep class **Adapter { *; }

# Keep annotations
-keepattributes *Annotation*

# Don't warn about sun.misc
-dontwarn sun.misc.**

# Keep kotlin metadata
-keep class kotlin.Metadata { *; }
-keepclassmembers class **$Companion { *; }

