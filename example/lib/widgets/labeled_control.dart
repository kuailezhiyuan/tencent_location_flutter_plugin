import 'package:flutter/material.dart';

/// 通用 "label + 控件" 行。统一 demo 里的 form 风格。
class LabeledControl extends StatelessWidget {
  final String label;
  final String? description;
  final Widget child;

  const LabeledControl({
    super.key,
    required this.label,
    required this.child,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (description != null)
                  Text(
                    description!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 分组 Section 标题。
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
