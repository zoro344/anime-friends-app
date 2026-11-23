import 'package:flutter/material.dart';
import '../../app/app_colors.dart';

class AFAvatar extends StatelessWidget {
  const AFAvatar({
    super.key,
    this.imageUrl,
    this.radius = 22,
    this.label,
  });

  final String? imageUrl;
  final double radius;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceElevated,
      foregroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: hasImage
          ? null
          : Text(
              (label?.isNotEmpty == true ? label![0] : 'A').toUpperCase(),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: radius * 0.85,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
