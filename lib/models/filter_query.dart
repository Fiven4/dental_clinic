import 'list_query.dart';

class QuerySpec {
  final Set<String> sortFields;
  final String defaultSort;
  final bool defaultAscending;
  final Set<String> filterKeys;

  const QuerySpec({
    required this.sortFields,
    required this.defaultSort,
    this.defaultAscending = true,
    this.filterKeys = const {},
  });
}

class FilterQuery extends ListQuery<FilterQuery> {
  final QuerySpec spec;
  @override
  final String search;
  final Map<String, String> filters;
  @override
  final String sortField;
  @override
  final bool sortAscending;
  @override
  final int page;
  @override
  final int size;
  @override
  final bool includeDeleted;

  FilterQuery({
    required this.spec,
    this.search = '',
    this.filters = const {},
    String? sortField,
    bool? sortAscending,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  }) : sortField = sortField ?? spec.defaultSort,
       sortAscending = sortAscending ?? spec.defaultAscending;

  factory FilterQuery.fromParams(QuerySpec spec, Map<String, String> p) {
    final sort = p['sort'];
    final parsed = parseSort(sort, spec.sortFields, spec.defaultSort);
    final hasSort = sort != null && sort.isNotEmpty;
    return FilterQuery(
      spec: spec,
      search: p['search']?.trim() ?? '',
      filters: {
        for (final key in spec.filterKeys)
          if ((p[key] ?? '').trim().isNotEmpty) key: p[key]!.trim(),
      },
      sortField: parsed.field,
      sortAscending: hasSort ? parsed.ascending : spec.defaultAscending,
      page: parsePage(p['page']),
      size: parseSize(p['size']),
      includeDeleted: p['includeDeleted'] == 'true',
    );
  }

  String? filter(String key) => filters[key];

  FilterQuery withFilter(String key, String? value) {
    final next = {...filters};
    if (value == null || value.trim().isEmpty) {
      next.remove(key);
    } else {
      next[key] = value.trim();
    }
    return _copy(filters: next, page: 1);
  }

  FilterQuery _copy({
    String? search,
    Map<String, String>? filters,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return FilterQuery(
      spec: spec,
      search: search ?? this.search,
      filters: filters ?? this.filters,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? this.page,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  FilterQuery withSearch(String value) => _copy(search: value, page: 1);
  @override
  FilterQuery withPage(int value) => _copy(page: value);
  @override
  FilterQuery withSize(int value) => _copy(size: value, page: 1);
  @override
  FilterQuery withSort(String field, bool ascending) =>
      _copy(sortField: field, sortAscending: ascending, page: 1);
  @override
  FilterQuery withIncludeDeleted(bool value) =>
      _copy(includeDeleted: value, page: 1);

  @override
  Map<String, String> toParams() => {
    if (search.trim().isNotEmpty) 'search': search.trim(),
    ...filters,
    if (sortField != spec.defaultSort || sortAscending != spec.defaultAscending)
      'sort': '$sortField,${sortAscending ? 'asc' : 'desc'}',
    if (page > 1) 'page': '$page',
    if (size != pageSizes.first) 'size': '$size',
    if (includeDeleted) 'includeDeleted': 'true',
  };
}
