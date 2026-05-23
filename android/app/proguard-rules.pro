# Flutter 核心
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# shared_preferences
-keep class androidx.lifecycle.** { *; }
-keep class android.content.SharedPreferences { *; }

# JSON 序列化
-keep class com.taskplanner.task_planner.** { *; }
-keepclassmembers class * {
    *** fromJson(***);
    *** toJson();
}

# table_calendar
-dontwarn com.simple.**

# uuid
-dontwarn com.fasterxml.**

# intl
-dontwarn intl.**
