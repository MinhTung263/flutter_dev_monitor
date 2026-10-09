import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/monitor_theme.dart';
import 'monitor_text.dart';
import 'monitor_theme_scope.dart';

/// A sleek, modern confirmation dialog for DevMonitor actions with rich aesthetics.
class MonitorConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;
  final bool isDestructive;
  final String? badgeLabel;

  const MonitorConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.icon,
    this.isDestructive = true,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return MonitorThemeScope(
      child: Builder(
        builder: (context) {
          final isDark = MonitorColors.isDark;
          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth > 600;
          final horizontalPad = isTablet
              ? ((screenWidth - 380) / 2).clamp(32.0, double.infinity)
              : 24.0;

          final effectiveIcon = icon ??
              (isDestructive
                  ? Icons.delete_sweep_rounded
                  : Icons.restart_alt_rounded);

          final accentColor = isDestructive
              ? const Color(0xFFEF4444)
              : const Color(0xFF6366F1);

          final gradientColors = isDestructive
              ? [const Color(0xFFFF6464), const Color(0xFFDC2626)]
              : [const Color(0xFF818CF8), const Color(0xFF4F46E5)];

          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPad),
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C212B) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF38404B)
                            : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.14),
                          blurRadius: 36,
                          spreadRadius: 0,
                          offset: const Offset(0, 18),
                        ),
                        BoxShadow(
                          color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
                          blurRadius: 48,
                          spreadRadius: -4,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Subtle top accent glow bar
                        Positioned(
                          top: 0,
                          left: 28,
                          right: 28,
                          height: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentColor.withValues(alpha: 0.0),
                                  accentColor.withValues(alpha: 0.8),
                                  accentColor.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Close button on top-right
                        Positioned(
                          top: 14,
                          right: 14,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(false),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.04),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: MonitorColors.secondaryText,
                              ),
                            ),
                          ),
                        ),

                        // Main Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Header (Icon + Badge + Title) ─────────────
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Glowing icon badge
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: gradientColors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentColor.withValues(alpha: 0.35),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      effectiveIcon,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Category / Action Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6.5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: accentColor.withValues(alpha: 0.25),
                                              width: 0.6,
                                            ),
                                          ),
                                          child: MonoText(
                                            badgeLabel ??
                                                (isDestructive
                                                    ? 'RESET ACTION'
                                                    : 'CONFIRMATION'),
                                            7.5,
                                            color: accentColor,
                                            weight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          title,
                                          style: TextStyle(
                                            color: MonitorColors.primaryText,
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 20), // Spacer for X button
                                ],
                              ),

                              const SizedBox(height: 18),

                              // ── Message Box (Styled Callout) ──────────────
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF141820)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF28303E)
                                        : const Color(0xFFE2E8F0),
                                    width: 0.9,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1.5),
                                      child: Icon(
                                        Icons.info_outline_rounded,
                                        size: 15,
                                        color: accentColor.withValues(alpha: 0.85),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        message,
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFFB0BAC5)
                                              : const Color(0xFF475569),
                                          fontSize: 12.8,
                                          height: 1.55,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 22),

                              // ── Actions (Ghost Cancel + Gradient Confirm) ──
                              Row(
                                children: [
                                  // Cancel button
                                  Expanded(
                                    child: SizedBox(
                                      height: 42,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          side: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF38404B)
                                                : const Color(0xFFCBD5E1),
                                            width: 1,
                                          ),
                                          backgroundColor: isDark
                                              ? Colors.white.withValues(alpha: 0.04)
                                              : const Color(0xFFF1F5F9),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(11),
                                          ),
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.close_rounded,
                                              size: 14,
                                              color: MonitorColors.secondaryText,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              cancelLabel,
                                              style: TextStyle(
                                                color: MonitorColors.secondaryText,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Confirm button
                                  Expanded(
                                    child: SizedBox(
                                      height: 42,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: gradientColors,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(11),
                                          boxShadow: [
                                            BoxShadow(
                                              color: accentColor
                                                  .withValues(alpha: 0.32),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                            ),
                                          ),
                                          onPressed: () {
                                            HapticFeedback.mediumImpact();
                                            Navigator.of(context).pop(true);
                                          },
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                effectiveIcon,
                                                size: 14.5,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                confirmLabel,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
