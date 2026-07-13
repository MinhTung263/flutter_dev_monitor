import 'package:flutter/material.dart';
import '../theme/monitor_theme.dart';

/// A wrapper widget that displays its content as a centered card layout
/// on large screens (e.g. tablet, desktop) and full-screen on mobile.
class MonitorResponsiveDialogWrapper extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;

  const MonitorResponsiveDialogWrapper({
    super.key,
    required this.child,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 640;

    if (isLargeScreen) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: MonitorColors.isDark
            ? Colors.black.withValues(alpha: 0.65)
            : Colors.black.withValues(alpha: 0.45),
        body: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent tap inside card from dismissing
              child: Container(
                width: 640,
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: BoxDecoration(
                  color: MonitorColors.pageBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MonitorColors.border,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Scaffold(
                        resizeToAvoidBottomInset: false,
                        backgroundColor: MonitorColors.pageBackground,
                        appBar: appBar,
                        body: child,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: MonitorColors.dropdownBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: MonitorColors.primaryText,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: MonitorColors.pageBackground,
        appBar: appBar,
        body: child,
      ),
    );
  }
}

/// A custom page route that uses opaque: false to keep the previous route
/// visible under the newly pushed route.
class MonitorResponsiveRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  MonitorResponsiveRoute({
    required this.builder,
    super.settings,
  }) : super(
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          pageBuilder: (context, _, __) => builder(context),
        );
}
