import 'package:flutter/foundation.dart';

import '../repositories/entity_repository.dart';
import 'load_status.dart';

class EntityDetailNotifier<T> extends ChangeNotifier {
  EntityDetailNotifier(this._store, this.id);

  final RecordStore<T> _store;

  final String? id;

  T? _item;
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  bool _disposed = false;

  T? get item => _item;
  LoadStatus get status => _status;
  String? get error => _error;
  bool get notFound => _status == LoadStatus.success && _item == null;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (id == null) {
      _item = null;
      _status = LoadStatus.success;
      _safeNotify();
      return;
    }
    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();
    try {
      _item = await _store.findById(id!);
      await onLoaded();
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить карточку: $e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  @protected
  Future<void> onLoaded() async {}

  Future<void> softDelete() async {
    await _store.softDelete(id!);
    await load();
  }

  Future<void> restore() async {
    await _store.restore(id!);
    await load();
  }

  Future<void> hardDelete() async {
    await _store.hardDelete(id!);
    _item = null;
    _safeNotify();
  }
}

class RelatedDetailNotifier<T, R> extends EntityDetailNotifier<T> {
  RelatedDetailNotifier(super.store, super.id, this._related);

  final Future<List<R>> Function(String id) _related;
  List<R> related = const [];

  @override
  Future<void> onLoaded() async {
    if (item == null) {
      related = const [];
      return;
    }
    try {
      related = await _related(id!);
    } on ApiException {
      related = const [];
    }
  }
}
