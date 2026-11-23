import 'package:flutter/material.dart';

class AFButton extends StatelessWidget {
  const AFButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = outlined
        ? OutlinedButton(
            onPressed: onPressed,
            child: _content(),
          )
        : ElevatedButton(
            onPressed: onPressed,
            child: _content(),
          );

    if (!expanded) return button;

    return SizedBox(
      width: double.infinity,
      child: button,
    );
  }

  Widget _content() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );
  }
}
