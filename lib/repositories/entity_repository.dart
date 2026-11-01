import 'package:flutter/foundation.dart';

import '../models/page_result.dart';

export '../core/api_exceptions.dart';

abstract interface class RecordStore<T> {
  Future<T?> findById(String id);

  Future<List<T>> findAll();

  Future<T> create(T item);

  Future<T> update(T item);

  Future<void> softDelete(String id);

  Future<void> hardDelete(String id);

  Future<void> restore(String id);

  Future<int> deleteMany(List<String> ids);
}

abstract interface class EntityRepository<T, Q> implements RecordStore<T> {
  Future<PageResult<T>> find(Q query);

  Future<List<T>> suggest(String text, {int limit});

  Listenable get changes;
}
