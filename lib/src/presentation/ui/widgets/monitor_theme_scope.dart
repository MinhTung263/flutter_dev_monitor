import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/monitor_theme.dart';

/// Wraps DevMonitor UI subtrees to completely isolate them from the host app's
/// custom fonts, text scalers (e.g. accessibility large fonts), and theme overrides.
class MonitorThemeScope extends StatelessWidget {
  final Widget child;

  const MonitorThemeScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MonitorColors.isDarkNotifier,
      builder: (context, isDark, _) {
        final mediaQueryData =
            MediaQuery.maybeOf(context) ?? const MediaQueryData();

        // 1. Force 1.0x text scaling and disable bold text forcing
        final cleanMediaQuery = mediaQueryData.copyWith(
          textScaler: TextScaler.noScaling,
          boldText: false,
        );

        // 2. Build isolated clean theme
        final baseTheme = isDark ? ThemeData.dark() : ThemeData.light();
        final isolatedTheme = baseTheme.copyWith(
          scaffoldBackgroundColor: MonitorColors.pageBackground,
          iconTheme: const IconThemeData(applyTextScaling: false),
          primaryIconTheme: const IconThemeData(applyTextScaling: false),
          colorScheme: baseTheme.colorScheme.copyWith(
            surface: MonitorColors.surface,
            onSurface: MonitorColors.primaryText,
          ),
          textTheme: Typography.material2021(platform: defaultTargetPlatform)
              .englishLike
              .apply(
                fontFamily: null,
                bodyColor: MonitorColors.primaryText,
                displayColor: MonitorColors.primaryText,
              ),
        );

        // 3. Reset DefaultTextStyle with inherit: false to sever inheritance
        // from host app's DefaultTextStyle.merge (e.g. custom fontFamily, bold weight).
        final cleanDefaultTextStyle = TextStyle(
          inherit: false,
          color: MonitorColors.primaryText,
          fontSize: 13,
          fontWeight: FontWeight.normal,
          fontFamilyFallback: MonitorTextStyle.standardFontFallback,
          decoration: TextDecoration.none,
        );

        return MediaQuery(
          data: cleanMediaQuery,
          child: Theme(
            data: isolatedTheme,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: DefaultTextStyle(
                style: cleanDefaultTextStyle,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
