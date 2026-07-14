// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void main() {
  final jsonFile = File('lib/src/core/translations.json');
  if (!jsonFile.existsSync()) {
    print('Error: translations.json not found!');
    exit(1);
  }

  final Map<String, dynamic> data = jsonDecode(jsonFile.readAsStringSync());

  // Generate monitor_strings.dart
  final stringsBuffer = StringBuffer();
  stringsBuffer.writeln("// GENERATED CODE - DO NOT MODIFY BY HAND");
  stringsBuffer.writeln();
  stringsBuffer.writeln("import 'dart:ui' as ui;");
  stringsBuffer.writeln("import 'monitor_strings_en.dart';");
  stringsBuffer.writeln("import 'monitor_strings_vi.dart';");
  stringsBuffer.writeln();
  stringsBuffer.writeln("/// Represents a localization key that can be translated.");
  stringsBuffer.writeln("class MonitorLocaleKey {");
  stringsBuffer.writeln("  final String key;");
  stringsBuffer.writeln("  const MonitorLocaleKey(this.key);");
  stringsBuffer.writeln();
  stringsBuffer.writeln("  /// Translates the key to the current system locale.");
  stringsBuffer.writeln("  String get tr => MonitorStrings.get(key);");
  stringsBuffer.writeln();
  stringsBuffer.writeln("  /// Translates the key and replaces parameter placeholders.");
  stringsBuffer.writeln("  String trWith(Map<String, dynamic> params) {");
  stringsBuffer.writeln("    String val = tr;");
  stringsBuffer.writeln("    if (key == 'errorsCount' && params['count'] == 1) {");
  stringsBuffer.writeln("      final oneVal = MonitorStrings.get('errorsCountOne');");
  stringsBuffer.writeln("      if (oneVal.isNotEmpty) return oneVal;");
  stringsBuffer.writeln("    }");
  stringsBuffer.writeln("    params.forEach((placeholder, value) {");
  stringsBuffer.writeln("      val = val.replaceAll('{\$placeholder}', '\$value');");
  stringsBuffer.writeln("    });");
  stringsBuffer.writeln("    return val;");
  stringsBuffer.writeln("  }");
  stringsBuffer.writeln("}");
  stringsBuffer.writeln();
  stringsBuffer.writeln("/// Dispatches localized strings based on system locale using key-value Maps.");
  stringsBuffer.writeln("class MonitorStrings {");
  stringsBuffer.writeln("  /// The active translation dictionary resolved once at class load.");
  stringsBuffer.writeln("  static final Map<String, String> _currentMap = _resolveTranslations();");
  stringsBuffer.writeln();
  stringsBuffer.writeln("  static Map<String, String> _resolveTranslations() {");
  stringsBuffer.writeln("    try {");
  stringsBuffer.writeln("      final String lang = ui.PlatformDispatcher.instance.locale.languageCode;");
  stringsBuffer.writeln("      if (lang == 'vi') {");
  stringsBuffer.writeln("        return viTranslations;");
  stringsBuffer.writeln("      }");
  stringsBuffer.writeln("    } catch (_) {}");
  stringsBuffer.writeln("    return enTranslations;");
  stringsBuffer.writeln("  }");
  stringsBuffer.writeln();
  stringsBuffer.writeln("  /// Helper to fetch a key safely.");
  stringsBuffer.writeln("  static String get(String key) => _currentMap[key] ?? '';");
  stringsBuffer.writeln("}");
  stringsBuffer.writeln();
  stringsBuffer.writeln("/// Constants representing localized keys for easy type-safe access.");
  stringsBuffer.writeln("class LocaleKeys {");

  // Generate LocaleKeys
  for (final key in data.keys) {
    stringsBuffer.writeln("  static const $key = MonitorLocaleKey('$key');");
  }
  stringsBuffer.writeln("}");

  File('lib/src/core/monitor_strings.dart').writeAsStringSync(stringsBuffer.toString());
  print('Generated lib/src/core/monitor_strings.dart');

  // Generate monitor_strings_en.dart
  final enBuffer = StringBuffer();
  enBuffer.writeln("// GENERATED CODE - DO NOT MODIFY BY HAND");
  enBuffer.writeln();
  enBuffer.writeln("/// English translation map for the monitor dashboard.");
  enBuffer.writeln("const Map<String, String> enTranslations = {");
  for (final entry in data.entries) {
    final key = entry.key;
    final val = entry.value as Map<String, dynamic>;
    final enText = val['en'].toString().replaceAll("'", "\\'");
    enBuffer.writeln("  '$key': '$enText',");
    if (val['hasOne'] == true) {
      final enOneText = val['enOne'].toString().replaceAll("'", "\\'");
      enBuffer.writeln("  '${key}One': '$enOneText',");
    }
  }
  enBuffer.writeln("};");
  File('lib/src/core/monitor_strings_en.dart').writeAsStringSync(enBuffer.toString());
  print('Generated lib/src/core/monitor_strings_en.dart');

  // Generate monitor_strings_vi.dart
  final viBuffer = StringBuffer();
  viBuffer.writeln("// GENERATED CODE - DO NOT MODIFY BY HAND");
  viBuffer.writeln();
  viBuffer.writeln("/// Vietnamese translation map for the monitor dashboard.");
  viBuffer.writeln("const Map<String, String> viTranslations = {");
  for (final entry in data.entries) {
    final key = entry.key;
    final val = entry.value as Map<String, dynamic>;
    final viText = val['vi'].toString().replaceAll("'", "\\'");
    viBuffer.writeln("  '$key': '$viText',");
    if (val['hasOne'] == true) {
      final viOneText = val['viOne'].toString().replaceAll("'", "\\'");
      viBuffer.writeln("  '${key}One': '$viOneText',");
    }
  }
  viBuffer.writeln("};");
  File('lib/src/core/monitor_strings_vi.dart').writeAsStringSync(viBuffer.toString());
  print('Generated lib/src/core/monitor_strings_vi.dart');

  print('Localization files generated successfully!');
}
