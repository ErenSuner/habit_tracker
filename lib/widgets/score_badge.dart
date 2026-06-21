import 'package:flutter/material.dart';

import '../config/app_colors.dart';

// Verim puanina gore renk (koyu zeminde canli tonlar).
Color scoreColor(BuildContext context, double score) {
  if (score >= 70) return AppColors.success; // yesil
  if (score >= 40) return AppColors.warning; // amber
  return AppColors.danger; // kirmizi
}

// "% verim" rozeti (kucuk renkli etiket).
class ScoreBadge extends StatelessWidget {
  final double score;
  final bool large;

  const ScoreBadge({super.key, required this.score, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(context, score);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 10,
        vertical: large ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '%${score.round()}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: large ? 22 : 14,
        ),
      ),
    );
  }
}
