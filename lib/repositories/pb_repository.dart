import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/filter_query.dart';
import '../models/json_utils.dart';
import '../models/page_result.dart';
import 'entity_repository.dart';
import 'pb_filters.dart';

class PbRepository<T> extends ChangeNotifier
    implements EntityRepository<T, FilterQuery> {
  PbRepository({
    required this.dio,
    required this.collection,
    required this.fromJson,
    required this.toBody,
    required this.idOf,
    this.expand = '',
    this.searchFields = const [],
    this.sortMap = const {},
    this.rules = const {},
    this.listSort = '',
    this.softDeletable = true,
  });

  final Dio dio;
  final String collection;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T item) toBody;
  final String Function(T item) idOf;
  final String expand;
  final List<String> searchFields;
  final Map<String, String> sortMap;
  final Map<String, FilterRule> rules;
  final String listSort;
  final bool softDeletable;

  @override
  Listenable get changes => this;

  String get _base => '/api/collections/$collection/records';

  Map<String, dynamic> get _expandParams =>
      expand.isEmpty ? const {} : {'expand': expand};

  @visibleForTesting
  String buildFilter(FilterQuery q) {
    final parts = <String>[];
    if (softDeletable && !q.includeDeleted) parts.add('deletedAt = ""');
    final text = q.search.trim();
    if (text.isNotEmpty && searchFields.isNotEmpty) {
      parts.add(
        '(${searchFields.map((f) => '$f ~ ${pbQuote(text)}').join(' || ')})',
      );
    }
    q.filters.forEach((key, value) {
      final expression = rules[key]?.call(value);
      if (expression != null) parts.add(expression);
    });
    return parts.join(' && ');
  }

  @visibleForTesting
  String buildSort(FilterQuery q) {
    final mapped = sortMap[q.sortField] ?? q.sortField;
    final fields = [
      for (final f in mapped.split(','))
        if (f.trim().isNotEmpty) '${q.sortAscending ? '' : '-'}${f.trim()}',
    ];
    return [...fields, 'id'].join(',');
  }

  @override
  Future<PageResult<T>> find(FilterQuery query) async {
    final filter = buildFilter(query);
    final response = await guard(
      () => dio.get<dynamic>(
        _base,
        queryParameters: {
          'page': query.page,
          'perPage': query.size,
          'sort': buildSort(query),
          if (filter.isNotEmpty) 'filter': filter,
          ..._expandParams,
        },
      ),
    );
    final data = mapOf(response.data);
    return PageResult<T>(
      items: [for (final json in mapListOf(data['items'])) fromJson(json)],
      page: intOf(data['page'], query.page),
      size: intOf(data['perPage'], query.size),
      total: intOf(data['totalItems']),
    );
  }

  @override
  Future<List<T>> suggest(String text, {int limit = 20}) async {
    final parts = <String>[if (softDeletable) 'deletedAt = ""'];
    final value = text.trim();
    if (value.isNotEmpty && searchFields.isNotEmpty) {
      parts.add(
        '(${searchFields.map((f) => '$f ~ ${pbQuote(value)}').join(' || ')})',
      );
    }
    final response = await guard(
      () => dio.get<dynamic>(
        _base,
        queryParameters: {
          'page': 1,
          'perPage': limit,
          'sort': listSort.isEmpty ? 'id' : listSort,
          if (parts.isNotEmpty) 'filter': parts.join(' && '),
          ..._expandParams,
        },
      ),
    );
    return [
      for (final json in mapListOf(mapOf(response.data)['items']))
        fromJson(json),
    ];
  }

  @override
  Future<T?> findById(String id) async {
    try {
      final response = await guard(
        () => dio.get<dynamic>('$_base/$id', queryParameters: _expandParams),
      );
      return fromJson(mapOf(response.data));
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<List<T>> findAll() async {
    final result = <T>[];
    var page = 1;
    while (true) {
      final response = await guard(
        () => dio.get<dynamic>(
          _base,
          queryParameters: {
            'page': page,
            'perPage': 200,
            'sort': listSort.isEmpty ? 'id' : listSort,
            if (softDeletable) 'filter': 'deletedAt = ""',
            ..._expandParams,
          },
        ),
      );
      final data = mapOf(response.data);
      result.addAll([
        for (final json in mapListOf(data['items'])) fromJson(json),
      ]);
      if (page >= intOf(data['totalPages'], 1)) break;
      page++;
    }
    return result;
  }

  @override
  Future<T> create(T item) async {
    final response = await guard(
      () => dio.post<dynamic>(
        _base,
        data: toBody(item),
        queryParameters: _expandParams,
      ),
    );
    notifyListeners();
    return fromJson(mapOf(response.data));
  }

  @override
  Future<T> update(T item) async {
    final response = await guard(
      () => dio.patch<dynamic>(
        '$_base/${idOf(item)}',
        data: toBody(item),
        queryParameters: _expandParams,
      ),
    );
    notifyListeners();
    return fromJson(mapOf(response.data));
  }

  @protected
  Future<void> patch(String id, Map<String, dynamic> body) async {
    await guard(() => dio.patch<dynamic>('$_base/$id', data: body));
    notifyListeners();
  }

  @override
  Future<void> softDelete(String id) {
    if (!softDeletable) return hardDelete(id);
    return patch(id, {'deletedAt': pbDate(DateTime.now())});
  }

  @override
  Future<void> restore(String id) => patch(id, {'deletedAt': ''});

  @override
  Future<void> hardDelete(String id) async {
    await guard(() => dio.delete<dynamic>('$_base/$id'));
    notifyListeners();
  }

  @override
  Future<int> deleteMany(List<String> ids) async {
    var done = 0;
    ApiException? failure;
    for (final id in ids) {
      try {
        await softDelete(id);
        done++;
      } on ApiException catch (e) {
        failure ??= e;
      }
    }
    if (done == 0 && failure != null) throw failure;
    return done;
  }
}
