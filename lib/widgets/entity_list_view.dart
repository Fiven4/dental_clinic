import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/breakpoints.dart';
import '../core/debouncer.dart';
import '../models/list_query.dart';
import '../core/api_exceptions.dart';
import '../state/entity_list_notifier.dart';
import '../state/load_status.dart';
import 'entity_card_list.dart';
import 'entity_table.dart';
import 'pagination_bar.dart';
import 'list_permissions.dart';
import 'state_views.dart';

class FilterScope<Q> {
  final Q query;
  final void Function(Q Function(Q current) change) apply;
  final void Function(Q Function(Q current) change) applyDebounced;

  const FilterScope({
    required this.query,
    required this.apply,
    required this.applyDebounced,
  });
}

class EntityListView<T, Q extends ListQuery<Q>> extends StatefulWidget {
  final String title;
  final String basePath;
  final EntityListNotifier<T, Q> notifier;
  final Q query;
  final String searchHint;
  final String emptyMessage;
  final List<TableColumnSpec<T>> columns;
  final String Function(T item) idOf;
  final String Function(T item) itemPath;
  final String createPath;
  final String Function(T item) editPath;
  final String Function(T item) itemTitle;
  final bool Function(T item) isDeleted;
  final List<Widget> Function(FilterScope<Q> scope)? filters;
  final ListPermissions permissions;
  final List<Widget> Function(T item)? extraActions;

  const EntityListView({
    super.key,
    required this.title,
    required this.basePath,
    required this.notifier,
    required this.query,
    required this.searchHint,
    required this.emptyMessage,
    required this.columns,
    required this.idOf,
    required this.itemPath,
    required this.createPath,
    required this.editPath,
    required this.itemTitle,
    required this.isDeleted,
    this.filters,
    this.permissions = ListPermissions.readOnly,
    this.extraActions,
  });

  @override
  State<EntityListView<T, Q>> createState() => _EntityListViewState<T, Q>();
}

class _EntityListViewState<T, Q extends ListQuery<Q>>
    extends State<EntityListView<T, Q>> {
  final _search = TextEditingController();
  final _debouncer = Debouncer();
  bool _filtersOpen = false;

  EntityListNotifier<T, Q> get _notifier => widget.notifier;

  @override
  void initState() {
    super.initState();
    _search.text = widget.query.search;
    _notifier.addListener(_correctPage);
    _applyQueryAfterBuild(force: true);
  }

  @override
  void didUpdateWidget(EntityListView<T, Q> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _applyQueryAfterBuild();
      if (oldWidget.query.search != widget.query.search &&
          !_debouncer.isPending &&
          _search.text != widget.query.search) {
        _search.text = widget.query.search;
      }
    }
  }

  @override
  void dispose() {
    _notifier.removeListener(_correctPage);
    _debouncer.cancel();
    _search.dispose();
    super.dispose();
  }

  void _applyQueryAfterBuild({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.applyQuery(widget.query, force: force);
    });
  }

  void _correctPage() {
    final result = _notifier.result;
    if (_notifier.status == LoadStatus.success &&
        result.items.isEmpty &&
        result.total > 0 &&
        widget.query.page > result.totalPages) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _go(widget.query.withPage(result.totalPages));
      });
    }
  }

  void _go(Q next) {
    context.go(buildLocation(widget.basePath, next.toParams()));
  }

  void _reset() {
    _debouncer.cancel();
    _search.clear();
    context.go(widget.basePath);
  }

  Future<bool> _confirm({
    required String title,
    required String text,
    required String confirmLabel,
  }) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _report(Object error) async {
    if (error is ConflictException) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('conflict-dialog'),
          icon: const Icon(Icons.block),
          title: const Text('Удаление невозможно'),
          content: Text(error.message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
    } else {
      _toast('Не удалось выполнить операцию: $error');
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) _toast(done);
    } catch (e) {
      if (mounted) await _report(e);
    }
  }

  Future<void> _open(T item) async {
    await context.push(widget.itemPath(item));
    if (mounted) _notifier.load();
  }

  Future<void> _create() async {
    await context.push(widget.createPath);
    if (mounted) _notifier.load();
  }

  Future<void> _edit(T item) async {
    await context.push(widget.editPath(item));
    if (mounted) _notifier.load();
  }

  Future<void> _softDelete(T item) async {
    final ok = await _confirm(
      title: 'Удалить запись?',
      text:
          '${widget.itemTitle(item)} будет помечена удалённой. '
          'Её можно восстановить через показ удалённых записей.',
      confirmLabel: 'Удалить',
    );
    if (ok) {
      await _run(
        () => _notifier.softDelete(widget.idOf(item)),
        'Запись удалена',
      );
    }
  }

  Future<void> _hardDelete(T item) async {
    final ok = await _confirm(
      title: 'Удалить навсегда?',
      text:
          '${widget.itemTitle(item)} будет стёрта безвозвратно. '
          'Восстановить её не получится.',
      confirmLabel: 'Удалить навсегда',
    );
    if (ok) {
      await _run(
        () => _notifier.hardDelete(widget.idOf(item)),
        'Запись удалена навсегда',
      );
    }
  }

  Future<void> _deleteSelected() async {
    final count = _notifier.selected.length;
    final ok = await _confirm(
      title: 'Удалить выбранные записи?',
      text:
          'Будет помечено удалёнными записей: $count. '
          'Их можно восстановить через показ удалённых записей.',
      confirmLabel: 'Удалить ($count)',
    );
    if (!ok) return;
    try {
      final deleted = await _notifier.deleteSelected();
      final skipped = count - deleted;
      if (mounted) {
        _toast(
          skipped > 0
              ? 'Удалено записей: $deleted. Не удалено: $skipped '
                    '(на них ссылаются другие записи или они уже удалены)'
              : 'Удалено записей: $deleted',
        );
      }
    } catch (e) {
      if (mounted) await _report(e);
    }
  }

  List<TableColumnSpec<T>> get _columns {
    final first = widget.columns.first;
    return [
      TableColumnSpec<T>(
        label: first.label,
        sortField: first.sortField,
        numeric: first.numeric,
        build: (item) => InkWell(
          onTap: () => _open(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: first.build(item),
          ),
        ),
      ),
      ...widget.columns.skip(1),
    ];
  }

  List<Widget> _actions(T item) {
    final id = widget.idOf(item);
    final deleted = widget.isDeleted(item);
    final canEdit = widget.permissions.edit;
    final canDelete = widget.permissions.delete;
    final canRestore = widget.permissions.restore;
    final canHardDelete = widget.permissions.hardDelete;

    return [
      ...?widget.extraActions?.call(item),
      PopupMenuButton<String>(
        key: ValueKey('row-menu-$id'),
        tooltip: 'Действия',
        onSelected: (action) {
          switch (action) {
            case 'open':
              _open(item);
            case 'edit':
              _edit(item);
            case 'delete':
              _softDelete(item);
            case 'restore':
              _run(() => _notifier.restore(id), 'Запись восстановлена');
            case 'hard':
              _hardDelete(item);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'open', child: Text('Открыть карточку')),
          if (canEdit)
            const PopupMenuItem(value: 'edit', child: Text('Изменить')),
          if (!deleted && canDelete)
            const PopupMenuItem(value: 'delete', child: Text('Удалить'))
          else if (deleted && canRestore)
            const PopupMenuItem(value: 'restore', child: Text('Восстановить')),
          if (canHardDelete)
            const PopupMenuItem(value: 'hard', child: Text('Удалить навсегда')),
        ],
      ),
    ];
  }

  void _sortBy(String field) {
    final q = widget.query;
    _go(q.withSort(field, field == q.sortField ? !q.sortAscending : true));
  }

  @override
  Widget build(BuildContext context) {
    final compact = screenSizeOf(context) == ScreenSize.compact;
    final query = widget.query;
    final sortable = widget.columns.where((c) => c.sortField != null).toList();

    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (widget.permissions.create)
                    FilledButton.icon(
                      key: const ValueKey('create-button'),
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildToolbar(compact, query, sortable),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: _notifier,
                builder: (context, _) => _notifier.hasSelection
                    ? _SelectionBar(
                        count: _notifier.selected.length,
                        onClear: _notifier.clearSelection,
                        onDelete: _deleteSelected,
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: _notifier,
                  builder: (context, _) => _buildContent(compact),
                ),
              ),
              ListenableBuilder(
                listenable: _notifier,
                builder: (context, _) {
                  final n = _notifier;
                  if (n.status == LoadStatus.error || n.result.total == 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: PaginationBar(
                      page: n.result.page,
                      totalPages: n.result.totalPages,
                      total: n.result.total,
                      size: n.result.size,
                      onPage: (p) => _go(widget.query.withPage(p)),
                      onSize: (s) => _go(widget.query.withSize(s)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _activeFilters(Q query) => query
      .toParams()
      .keys
      .where((k) => !const {'search', 'sort', 'page', 'size'}.contains(k))
      .length;

  Widget _buildToolbar(
    bool compact,
    Q query,
    List<TableColumnSpec<T>> sortable,
  ) {
    final searchField = TextField(
      key: const ValueKey('search-field'),
      controller: _search,
      decoration: InputDecoration(
        hintText: widget.searchHint,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (text) =>
          _debouncer.run(() => _go(widget.query.withSearch(text))),
    );

    final filterWidgets = <Widget>[
      if (widget.filters != null)
        ...widget.filters!(
          FilterScope<Q>(
            query: query,
            apply: (change) => _go(change(widget.query)),
            applyDebounced: (change) =>
                _debouncer.run(() => _go(change(widget.query))),
          ),
        ),
      if (widget.permissions.delete)
        FilterChip(
        key: const ValueKey('show-deleted'),
        label: const Text('Показать удалённые'),
        selected: query.includeDeleted,
        onSelected: (value) => _go(query.withIncludeDeleted(value)),
      ),
      if (query.toParams().isNotEmpty)
        TextButton.icon(
          key: const ValueKey('reset-filters'),
          onPressed: _reset,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Сбросить'),
        ),
    ];

    final sortMenu = PopupMenuButton<String>(
      key: const ValueKey('sort-menu'),
      tooltip: 'Сортировка',
      icon: const Icon(Icons.sort),
      onSelected: _sortBy,
      itemBuilder: (_) => [
        for (final c in sortable)
          PopupMenuItem(
            value: c.sortField,
            child: Row(
              children: [
                Text(c.label),
                if (c.sortField == query.sortField) ...[
                  const SizedBox(width: 8),
                  Icon(
                    query.sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
      ],
    );

    if (!compact) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 320, child: searchField),
          ...filterWidgets,
        ],
      );
    }

    final active = _activeFilters(query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey('filters-toggle'),
              tooltip: 'Фильтры',
              onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
              icon: Badge(
                isLabelVisible: active > 0,
                label: Text('$active'),
                child: Icon(
                  _filtersOpen ? Icons.filter_list_off : Icons.filter_list,
                ),
              ),
            ),
            if (sortable.isNotEmpty) sortMenu,
          ],
        ),
        if (_filtersOpen)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: filterWidgets,
            ),
          ),
      ],
    );
  }

  Widget _buildContent(bool compact) {
    final n = _notifier;

    if (n.status == LoadStatus.error) {
      return ErrorView(message: n.error ?? 'Ошибка', onRetry: n.load);
    }
    if (n.result.items.isEmpty) {
      if (n.status != LoadStatus.success) return const LoadingView();
      final filtered = widget.query.toParams().isNotEmpty;
      return EmptyView(
        message: filtered
            ? widget.emptyMessage
            : 'Список пуст. Записей пока нет.',
        onReset: filtered ? _reset : null,
      );
    }

    final loading = n.status == LoadStatus.loading;
    final data = compact
        ? EntityCardList<T>(
            columns: _columns,
            items: n.result.items,
            idOf: widget.idOf,
            selected: n.selected,
            onToggleSelect: widget.permissions.delete ? n.toggleSelection : null,
            actions: _actions,
            isMuted: widget.isDeleted,
          )
        : EntityTable<T>(
            columns: _columns,
            items: n.result.items,
            idOf: widget.idOf,
            selected: n.selected,
            onToggleSelect: widget.permissions.delete ? n.toggleSelection : null,
            onToggleAll: n.setPageSelection,
            sortField: widget.query.sortField,
            sortAscending: widget.query.sortAscending,
            onSort: _sortBy,
            actions: _actions,
            isMuted: widget.isDeleted,
          );

    return Stack(
      children: [
        Positioned.fill(
          child: Opacity(opacity: loading ? 0.5 : 1, child: data),
        ),
        if (loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

class _SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  const _SelectionBar({
    required this.count,
    required this.onClear,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('selection-bar'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            'Выбрано: $count',
            key: const ValueKey('selection-count'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          TextButton(onPressed: onClear, child: const Text('Снять выделение')),
          FilledButton.icon(
            key: const ValueKey('delete-selected'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Удалить выбранные'),
          ),
        ],
      ),
    );
  }
}
