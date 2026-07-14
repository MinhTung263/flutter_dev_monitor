// GENERATED CODE - DO NOT MODIFY BY HAND

import 'dart:ui' as ui;
import 'monitor_strings_en.dart';
import 'monitor_strings_vi.dart';

/// Represents a localization key that can be translated.
class MonitorLocaleKey {
  final String key;
  const MonitorLocaleKey(this.key);

  /// Translates the key to the current system locale.
  String get tr => MonitorStrings.get(key);

  /// Translates the key and replaces parameter placeholders.
  String trWith(Map<String, dynamic> params) {
    String val = tr;
    if (key == 'errorsCount' && params['count'] == 1) {
      final oneVal = MonitorStrings.get('errorsCountOne');
      if (oneVal.isNotEmpty) return oneVal;
    }
    params.forEach((placeholder, value) {
      val = val.replaceAll('{$placeholder}', '$value');
    });
    return val;
  }
}

/// Dispatches localized strings based on system locale using key-value Maps.
class MonitorStrings {
  /// The active translation dictionary resolved once at class load.
  static final Map<String, String> _currentMap = _resolveTranslations();

  static Map<String, String> _resolveTranslations() {
    try {
      final String lang = ui.PlatformDispatcher.instance.locale.languageCode;
      if (lang == 'vi') {
        return viTranslations;
      }
    } catch (_) {}
    return enTranslations;
  }

  /// Helper to fetch a key safely.
  static String get(String key) => _currentMap[key] ?? '';
}

/// Constants representing localized keys for easy type-safe access.
class LocaleKeys {
  static const tabTimeline = MonitorLocaleKey('tabTimeline');
  static const tabRequest = MonitorLocaleKey('tabRequest');
  static const tabResponse = MonitorLocaleKey('tabResponse');
  static const tabHeaders = MonitorLocaleKey('tabHeaders');
  static const initLabel = MonitorLocaleKey('initLabel');
  static const actionLabel = MonitorLocaleKey('actionLabel');
  static const screensTitle = MonitorLocaleKey('screensTitle');
  static const allScreens = MonitorLocaleKey('allScreens');
  static const unknownScreen = MonitorLocaleKey('unknownScreen');
  static const samples = MonitorLocaleKey('samples');
  static const fpsHistory = MonitorLocaleKey('fpsHistory');
  static const ramHistory = MonitorLocaleKey('ramHistory');
  static const noApiCalls = MonitorLocaleKey('noApiCalls');
  static const onThisScreen = MonitorLocaleKey('onThisScreen');
  static const noErrors = MonitorLocaleKey('noErrors');
  static const caughtYet = MonitorLocaleKey('caughtYet');
  static const filterAll = MonitorLocaleKey('filterAll');
  static const filterSlow = MonitorLocaleKey('filterSlow');
  static const filterError = MonitorLocaleKey('filterError');
  static const searchPlaceholder = MonitorLocaleKey('searchPlaceholder');
  static const searchResponsePlaceholder = MonitorLocaleKey('searchResponsePlaceholder');
  static const previousMatch = MonitorLocaleKey('previousMatch');
  static const nextMatch = MonitorLocaleKey('nextMatch');
  static const found = MonitorLocaleKey('found');
  static const errorCopied = MonitorLocaleKey('errorCopied');
  static const goBack = MonitorLocaleKey('goBack');
  static const noRouteEvents = MonitorLocaleKey('noRouteEvents');
  static const navigateAround = MonitorLocaleKey('navigateAround');
  static const liveNavigationStack = MonitorLocaleKey('liveNavigationStack');
  static const current = MonitorLocaleKey('current');
  static const step = MonitorLocaleKey('step');
  static const errorsCount = MonitorLocaleKey('errorsCount');
  static const overlayHoldToOpen = MonitorLocaleKey('overlayHoldToOpen');
  static const overlayCollapse = MonitorLocaleKey('overlayCollapse');
  static const overlayGrid = MonitorLocaleKey('overlayGrid');
  static const overlayDash = MonitorLocaleKey('overlayDash');
  static const overlayReset = MonitorLocaleKey('overlayReset');
  static const overlayHide = MonitorLocaleKey('overlayHide');
  static const overlayFpsLabel = MonitorLocaleKey('overlayFpsLabel');
  static const overlayApiLabel = MonitorLocaleKey('overlayApiLabel');
  static const overlayMemLabel = MonitorLocaleKey('overlayMemLabel');
  static const overlayNetLabel = MonitorLocaleKey('overlayNetLabel');
  static const logsForScreen = MonitorLocaleKey('logsForScreen');
}
