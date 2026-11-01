import 'package:flutter/material.dart';

import '../models/list_query.dart';

class PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final int size;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;

  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.size,
    required this.onPage,
    required this.onSize,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrevious = page > 1;
    final hasNext = page < totalPages;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('На странице:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              key: const ValueKey('page-size'),
              value: size,
              underline: const SizedBox.shrink(),
              items: [
                for (final s in pageSizes)
                  DropdownMenuItem(value: s, child: Text('$s')),
              ],
              onChanged: (value) {
                if (value != null) onSize(value);
              },
            ),
          ],
        ),
        Text(
          'Страница $page из $totalPages · всего записей: $total',
          key: const ValueKey('page-label'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Первая страница',
              icon: const Icon(Icons.first_page),
              onPressed: hasPrevious ? () => onPage(1) : null,
            ),
            IconButton(
              tooltip: 'Предыдущая страница',
              icon: const Icon(Icons.chevron_left),
              onPressed: hasPrevious ? () => onPage(page - 1) : null,
            ),
            IconButton(
              tooltip: 'Следующая страница',
              icon: const Icon(Icons.chevron_right),
              onPressed: hasNext ? () => onPage(page + 1) : null,
            ),
            IconButton(
              tooltip: 'Последняя страница',
              icon: const Icon(Icons.last_page),
              onPressed: hasNext ? () => onPage(totalPages) : null,
            ),
          ],
        ),
      ],
    );
  }
}
