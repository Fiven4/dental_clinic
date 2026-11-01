import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
}

class EntityTable<T> extends StatelessWidget {
  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final String Function(T item) idOf;
  final Set<String> selected;
  final ValueChanged<String>? onToggleSelect;
  final ValueChanged<bool>? onToggleAll;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;
  final bool Function(T item)? isMuted;

  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.onToggleAll,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
    this.isMuted,
  });

  @override
  Widget build(BuildContext context) {
    final sortIndex = columns.indexWhere(
      (c) => c.sortField != null && c.sortField == sortField,
    );
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.5);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              sortColumnIndex: sortIndex < 0 ? null : sortIndex,
              sortAscending: sortAscending,
              columnSpacing: 14,
              horizontalMargin: 12,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 68,
              showCheckboxColumn: onToggleSelect != null,
              onSelectAll: onToggleAll == null
                  ? null
                  : (value) => onToggleAll!(value ?? false),
              columns: [
                for (final c in columns)
                  DataColumn(
                    label: Text(c.label),
                    numeric: c.numeric,
                    onSort: (c.sortField == null || onSort == null)
                        ? null
                        : (_, _) => onSort!(c.sortField!),
                  ),
                if (actions != null) const DataColumn(label: Text('')),
              ],
              rows: [
                for (final item in items)
                  DataRow(
                    key: ValueKey(idOf(item)),
                    selected: selected.contains(idOf(item)),
                    onSelectChanged: onToggleSelect == null
                        ? null
                        : (_) => onToggleSelect!(idOf(item)),
                    cells: [
                      for (final c in columns)
                        DataCell(
                          (isMuted?.call(item) ?? false)
                              ? DefaultTextStyle.merge(
                                  style: TextStyle(color: muted),
                                  child: c.build(item),
                                )
                              : c.build(item),
                        ),
                      if (actions != null)
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions!(item),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
