import 'package:flutter/foundation.dart';

import '../models/list_query.dart';
import '../models/page_result.dart';
import '../repositories/entity_repository.dart';
import 'load_status.dart';

class EntityListNotifier<T, Q extends ListQuery<Q>> extends ChangeNotifier {
  EntityListNotifier(this._repository, this._query, this._idOf);

  final EntityRepository<T, Q> _repository;
  final String Function(T item) _idOf;

  Q _query;
  PageResult<T> _result = PageResult<T>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<String> _selected = {};
  int _loadCounter = 0;
  bool _disposed = false;

  Q get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  bool get isEmptyResult =>
      _status == LoadStatus.success && _result.items.isEmpty;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final ticket = ++_loadCounter;
    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();
    try {
      final result = await _repository.find(_query);
      if (ticket != _loadCounter) return;
      _result = result;
      _status = LoadStatus.success;
    } catch (e) {
      if (ticket != _loadCounter) return;
      _error = 'Не удалось загрузить список: $e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> applyQuery(Q next, {bool force = false}) {
    if (!force && next == _query && _status == LoadStatus.success) {
      return Future.value();
    }
    _query = next;
    _selected.clear();
    return load();
  }

  void toggleSelection(String id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    _safeNotify();
  }

  void setPageSelection(bool selected) {
    for (final item in _result.items) {
      selected ? _selected.add(_idOf(item)) : _selected.remove(_idOf(item));
    }
    _safeNotify();
  }

  void clearSelection() {
    _selected.clear();
    _safeNotify();
  }

  Future<int> deleteSelected() async {
    final count = await _repository.deleteMany(_selected.toList());
    _selected.clear();
    await load();
    return count;
  }

  Future<void> softDelete(String id) async {
    await _repository.softDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> hardDelete(String id) async {
    await _repository.hardDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> restore(String id) async {
    await _repository.restore(id);
    await load();
  }
}
