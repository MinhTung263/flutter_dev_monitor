import 'package:flutter/material.dart';

import '../theme/monitor_theme.dart';

/// Monospace text — values, timestamps, route names, JSON.
/// [color] defaults to [MonitorColors.secondaryText].
class MonoText extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final FontWeight? weight;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final double? height;

  const MonoText(
    this.text,
    this.size, {
    super.key,
    this.color,
    this.weight,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.height,
  });

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: MonitorTextStyle.mono(size,
            color: color, weight: weight, height: height),
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
}

/// Uppercase bold label — section headers, event badges, chip labels.
/// Default size 8, letterSpacing 0.4.
class LabelText extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  final double spacing;
  final int? maxLines;
  final TextOverflow? overflow;

  const LabelText(
    this.text,
    this.color, {
    super.key,
    this.size = 8,
    this.spacing = 0.4,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: MonitorTextStyle.label(color, size: size, spacing: spacing),
        maxLines: maxLines,
        overflow: overflow,
      );
}

/// Regular (non-monospace) body text.
/// [color] defaults to [MonitorColors.primaryText].
class BodyText extends StatelessWidget {
  final String text;
  final double size;
  final Color? color;
  final FontWeight weight;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const BodyText(
    this.text,
    this.size, {
    super.key,
    this.color,
    this.weight = FontWeight.normal,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) => Text(
        text,
        style:
            MonitorTextStyle.body(size, color: color, weight: weight),
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
}
