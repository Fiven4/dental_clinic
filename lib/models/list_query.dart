import 'package:flutter/foundation.dart';

const pageSizes = [10, 25, 50];

abstract class ListQuery<Q extends ListQuery<Q>> {
  const ListQuery();

  String get search;
  String get sortField;
  bool get sortAscending;
  int get page;
  int get size;
  bool get includeDeleted;

  Q withSearch(String value);
  Q withPage(int value);
  Q withSize(int value);
  Q withSort(String field, bool ascending);
  Q withIncludeDeleted(bool value);

  Map<String, String> toParams();

  @override
  bool operator ==(Object other) =>
      other is ListQuery &&
      other.runtimeType == runtimeType &&
      mapEquals(other.toParams(), toParams());

  @override
  int get hashCode => Object.hashAll(
    toParams().entries.map((e) => Object.hash(e.key, e.value)),
  );
}

({String field, bool ascending}) parseSort(
  String? raw,
  Set<String> allowed,
  String defaultField,
) {
  if (raw == null || raw.isEmpty) return (field: defaultField, ascending: true);
  final parts = raw.split(',');
  final field = allowed.contains(parts.first) ? parts.first : defaultField;
  final ascending = parts.length < 2 || parts[1].toLowerCase() != 'desc';
  return (field: field, ascending: ascending);
}

int parsePage(String? raw) {
  final value = int.tryParse(raw ?? '') ?? 1;
  return value < 1 ? 1 : value;
}

int parseSize(String? raw) {
  final value = int.tryParse(raw ?? '');
  return pageSizes.contains(value) ? value! : pageSizes.first;
}

String buildLocation(String path, Map<String, String> params) {
  if (params.isEmpty) return path;
  final query = params.entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}='
            '${Uri.encodeQueryComponent(e.value).replaceAll('%2C', ',')}',
      )
      .join('&');
  return '$path?$query';
}
