import 'package:flutter/material.dart';

/// 带时间戳的滚动日志面板。
class LogPanel extends StatelessWidget {
  final List<String> logs;
  final VoidCallback? onClear;

  const LogPanel({super.key, required this.logs, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.terminal, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                '日志（${logs.length}）',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (onClear != null && logs.isNotEmpty)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('清空'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.grey.shade100,
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      '暂无日志',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade300),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Text(
                        logs[i],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
