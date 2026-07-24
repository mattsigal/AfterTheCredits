import 'package:flutter/material.dart';

class StingerBadgeOverlay extends StatelessWidget {
  final bool? duringCredits;
  final bool? afterCredits;

  const StingerBadgeOverlay({
    super.key,
    this.duringCredits,
    this.afterCredits,
  });

  @override
  Widget build(BuildContext context) {
    if (duringCredits != true && afterCredits != true) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (duringCredits == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              color: Colors.amber.shade800,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 4),
              ],
            ),
            child: const Text(
              'MID',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (afterCredits == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 4),
              ],
            ),
            child: const Text(
              'AFTER',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class StingerPosterBorder extends StatelessWidget {
  final bool? duringCredits;
  final bool? afterCredits;
  final Widget child;
  final double borderRadius;

  const StingerPosterBorder({
    super.key,
    this.duringCredits,
    this.afterCredits,
    required this.child,
    this.borderRadius = 12.0,
  });

  Color get borderColor {
    if (duringCredits == true || afterCredits == true) {
      return const Color(0xFFFF3B5C); // Red for stinger content
    } else if (duringCredits == false && afterCredits == false) {
      return const Color(0xFF00E676); // Green for NO stinger content
    }
    return Colors.black; // Black for unknown/loading
  }

  @override
  Widget build(BuildContext context) {
    final color = borderColor;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: color, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 2),
        child: child,
      ),
    );
  }
}
