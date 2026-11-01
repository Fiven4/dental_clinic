import 'package:flutter/material.dart';

import 'entity_table.dart';

class EntityCardList<T> extends StatelessWidget {
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final String Function(T item) idOf;
  final Set<String> selected;
  final ValueChanged<String>? onToggleSelect;
  final List<Widget> Function(T item)? actions;
  final bool Function(T item)? isMuted;

  const EntityCardList({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.actions,
    this.isMuted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final id = idOf(item);
        final muted = isMuted?.call(item) ?? false;
        final isSelected = selected.contains(id);

        return Card(
          key: ValueKey('card-$id'),
          margin: EdgeInsets.zero,
          color: isSelected ? theme.colorScheme.secondaryContainer : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: muted
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (onToggleSelect != null)
                        Checkbox(
                          value: isSelected,
                          onChanged: (_) => onToggleSelect!(id),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, right: 8),
                          child: DefaultTextStyle.merge(
                            style: theme.textTheme.titleMedium,
                            child: columns.first.build(item),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      onToggleSelect != null ? 48 : 8,
                      4,
                      8,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final c in columns.skip(1))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${c.label}: ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Flexible(child: c.build(item)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (actions != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(children: actions!(item)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
