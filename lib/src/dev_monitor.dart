import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'data/monitor_interceptor.dart';
import 'presentation/navigation/monitor_navigator_observer.dart';
import 'presentation/ui/widgets/fps_overlay.dart';

abstract final class DevMonitor {
  static final MonitorNavigatorObserver observer = MonitorNavigatorObserver();
  static final MonitorInterceptor interceptor = MonitorInterceptor();

  static final ValueNotifier<bool> _overlayEnabled = ValueNotifier(true);
  static bool? _configuredShowOverlay;

  /// Show the FpsOverlay.
  static void showOverlay() => _overlayEnabled.value = true;

  /// Hide the FpsOverlay.
  static void hideOverlay() => _overlayEnabled.value = false;

  /// Toggle the FpsOverlay on/off.
  static void toggleOverlay() => _overlayEnabled.value = !_overlayEnabled.value;

  /// Whether the overlay is currently visible.
  static bool get isOverlayVisible => _overlayEnabled.value;

  /// Returns a [TransitionBuilder] for [MaterialApp.builder].
  ///
  /// [showOverlay] sets the initial visibility (default: `true`).
  /// The overlay can still be toggled at runtime via [showOverlay]/[hideOverlay].
  ///
  /// ```dart
  /// // Always visible (default):
  /// builder: DevMonitor.builder(),
  ///
  /// // Hidden until manually shown (e.g. production build):
  /// builder: DevMonitor.builder(showOverlay: false),
  /// ```
  static TransitionBuilder builder({
    bool showOverlay = true,
    bool expandedByDefault = true,
  }) {
    if (_configuredShowOverlay != showOverlay) {
      _configuredShowOverlay = showOverlay;
      _overlayEnabled.value = showOverlay;
    }
    return (context, child) => ValueListenableBuilder<bool>(
          valueListenable: _overlayEnabled,
          builder: (_, enabled, __) => FpsOverlay(
            isShowing: enabled,
            expandedByDefault: expandedByDefault,
            onHide: hideOverlay,
            child: child ?? const SizedBox.shrink(),
          ),
        );
  }

  /// Pass to [MaterialApp.builder]. Wraps the app with [FpsOverlay].
  /// Use [builder()] instead if you need to configure initial visibility.
  static Widget appBuilder(BuildContext context, Widget? child) =>
      ValueListenableBuilder<bool>(
        valueListenable: _overlayEnabled,
        builder: (_, enabled, __) => FpsOverlay(
          isShowing: enabled,
          onHide: hideOverlay,
          child: child ?? const SizedBox.shrink(),
        ),
      );

  /// Wraps [child] with an invisible [tapCount]-tap trigger that toggles
  /// the overlay. Place on any widget (app logo, version label, etc.).
  ///
  /// Consecutive taps must occur within 1.5 s of each other; the counter
  /// resets on timeout so accidental taps don't accumulate.
  /// [clipboardKey]: nếu truyền vào, sẽ copy chuỗi này vào clipboard
  /// mỗi lần trigger — dùng làm passphrase xác nhận cho tester.
  static Widget tapToToggle({
    required Widget child,
    int tapCount = 7,
    String? clipboardKey,
  }) =>
      _SecretTapTrigger(
          tapCount: tapCount, clipboardKey: clipboardKey, child: child);
}

class _SecretTapTrigger extends StatefulWidget {
  final Widget child;
  final int tapCount;
  final String? clipboardKey;

  const _SecretTapTrigger({
    required this.child,
    required this.tapCount,
    this.clipboardKey,
  });

  @override
  State<_SecretTapTrigger> createState() => _SecretTapTriggerState();
}

class _SecretTapTriggerState extends State<_SecretTapTrigger> {
  int _count = 0;
  Timer? _resetTimer;

  void _onTap() {
    _count++;
    _resetTimer?.cancel();
    if (_count >= widget.tapCount) {
      _count = 0;
      DevMonitor.toggleOverlay();
      if (widget.clipboardKey != null) {
        Clipboard.setData(ClipboardData(text: widget.clipboardKey!));
      }
    } else {
      _resetTimer = Timer(const Duration(milliseconds: 1500), () => _count = 0);
    }
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.translucent,
        child: widget.child,
      );
}
