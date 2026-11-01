import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RelatedItem {
  final String title;
  final String? subtitle;
  final String? path;
  final Widget? trailing;

  const RelatedItem({
    required this.title,
    this.subtitle,
    this.path,
    this.trailing,
  });
}

class RelatedCard extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<RelatedItem> items;

  const RelatedCard({
    super.key,
    required this.title,
    required this.items,
    this.emptyText = 'Нет связанных записей.',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(emptyText)
            else
              for (final item in items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.title),
                  subtitle: item.subtitle == null ? null : Text(item.subtitle!),
                  trailing:
                      item.trailing ??
                      (item.path == null
                          ? null
                          : const Icon(Icons.chevron_right)),
                  onTap: item.path == null
                      ? null
                      : () => context.push(item.path!),
                ),
          ],
        ),
      ),
    );
  }
}
