import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/breakpoints.dart';
import '../core/api_exceptions.dart';
import '../state/entity_detail_notifier.dart';
import '../state/load_status.dart';
import 'list_permissions.dart';
import 'state_views.dart';

class DetailView<T> extends StatelessWidget {
  final EntityDetailNotifier<T> notifier;
  final String listPath;
  final String editPath;
  final String Function(T item) titleOf;
  final bool Function(T item) isDeleted;
  final List<(String, Widget)> Function(T item) fields;
  final Widget Function(T item)? extra;
  final ListPermissions permissions;
  final List<Widget> Function(T item)? extraButtons;

  const DetailView({
    super.key,
    required this.notifier,
    required this.listPath,
    required this.editPath,
    required this.titleOf,
    required this.isDeleted,
    required this.fields,
    this.extra,
    this.permissions = ListPermissions.readOnly,
    this.extraButtons,
  });

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(listPath);
    }
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String text,
    String action,
  ) async {
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
            child: Text(action),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  Future<void> _guard(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on ConflictException catch (e) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('conflict-dialog'),
          icon: const Icon(Icons.block),
          title: const Text('Удаление невозможно'),
          content: Text(e.message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось выполнить операцию: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = screenSizeOf(context) == ScreenSize.compact;
    return Padding(
      padding: EdgeInsets.all(compact ? 12 : 24),
      child: ListenableBuilder(
        listenable: notifier,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('back-button'),
                onPressed: () => _back(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('К списку'),
              ),
            ),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (notifier.status == LoadStatus.error) {
      return ErrorView(
        message: notifier.error ?? 'Ошибка',
        onRetry: notifier.load,
      );
    }
    if (notifier.status != LoadStatus.success) return const LoadingView();
    final item = notifier.item;
    if (item == null) {
      return const EmptyView(
        message: 'Запись не найдена или удалена навсегда.',
      );
    }

    final deleted = isDeleted(item);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(titleOf(item), style: theme.textTheme.headlineSmall),
                  if (deleted)
                    Chip(
                      label: const Text('удалена'),
                      backgroundColor: theme.colorScheme.errorContainer,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final (label, value) in fields(item))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (screenSizeOf(context) == ScreenSize.compact)
                                Expanded(
                                  child: Wrap(
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        '$label: ',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      value,
                                    ],
                                  ),
                                )
                              else ...[
                                SizedBox(
                                  width: 140,
                                  child: Text(
                                    label,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Expanded(child: value),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (extra != null) ...[const SizedBox(height: 16), extra!(item)],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ...?extraButtons?.call(item),
                  if (permissions.edit)
                  FilledButton.tonalIcon(
                    key: const ValueKey('detail-edit'),
                    onPressed: () async {
                      await context.push(editPath);
                      if (context.mounted) notifier.load();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Изменить'),
                  ),
                  if (!deleted && permissions.delete)
                    OutlinedButton.icon(
                      key: const ValueKey('detail-delete'),
                      onPressed: () async {
                        final ok = await _confirm(
                          context,
                          'Удалить запись?',
                          'Запись будет помечена удалённой. Её можно восстановить.',
                          'Удалить',
                        );
                        if (ok && context.mounted) {
                          await _guard(context, notifier.softDelete);
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Удалить'),
                    )
                  else if (deleted && permissions.restore)
                    FilledButton.icon(
                      key: const ValueKey('detail-restore'),
                      onPressed: () => _guard(context, notifier.restore),
                      icon: const Icon(Icons.restore),
                      label: const Text('Восстановить'),
                    ),
                  if (permissions.hardDelete)
                  TextButton.icon(
                    key: const ValueKey('detail-hard-delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () async {
                      final ok = await _confirm(
                        context,
                        'Удалить навсегда?',
                        'Запись будет стёрта безвозвратно.',
                        'Удалить навсегда',
                      );
                      if (ok && context.mounted) {
                        await _guard(context, notifier.hardDelete);
                      }
                    },
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Удалить навсегда'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
