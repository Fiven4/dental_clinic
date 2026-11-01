typedef FieldResolver = List<Object?> Function(
  Map<String, dynamic> record,
  String path,
);

typedef RecordPredicate = bool Function(Map<String, dynamic> record);

class FilterSyntaxException implements Exception {
  final String message;

  const FilterSyntaxException(this.message);

  @override
  String toString() => message;
}

enum _Kind { open, close, and, or, op, string, number, ident, end }

class _Token {
  final _Kind kind;
  final String text;

  const _Token(this.kind, this.text);
}

const _operators = [
  '?!=',
  '?!~',
  '?>=',
  '?<=',
  '?=',
  '?~',
  '?>',
  '?<',
  '!=',
  '!~',
  '>=',
  '<=',
  '=',
  '~',
  '>',
  '<',
];

List<_Token> _tokenize(String source) {
  final tokens = <_Token>[];
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    if (ch.trim().isEmpty) {
      i++;
      continue;
    }
    if (ch == '(') {
      tokens.add(const _Token(_Kind.open, '('));
      i++;
      continue;
    }
    if (ch == ')') {
      tokens.add(const _Token(_Kind.close, ')'));
      i++;
      continue;
    }
    if (source.startsWith('&&', i)) {
      tokens.add(const _Token(_Kind.and, '&&'));
      i += 2;
      continue;
    }
    if (source.startsWith('||', i)) {
      tokens.add(const _Token(_Kind.or, '||'));
      i += 2;
      continue;
    }
    if (ch == '"' || ch == "'") {
      final buffer = StringBuffer();
      i++;
      var closed = false;
      while (i < source.length) {
        final c = source[i];
        if (c == r'\' && i + 1 < source.length) {
          buffer.write(source[i + 1]);
          i += 2;
          continue;
        }
        if (c == ch) {
          closed = true;
          i++;
          break;
        }
        buffer.write(c);
        i++;
      }
      if (!closed) throw const FilterSyntaxException('Незакрытая строка');
      tokens.add(_Token(_Kind.string, buffer.toString()));
      continue;
    }
    String? matched;
    for (final op in _operators) {
      if (source.startsWith(op, i)) {
        matched = op;
        break;
      }
    }
    if (matched != null) {
      tokens.add(_Token(_Kind.op, matched));
      i += matched.length;
      continue;
    }
    final number = RegExp(r'-?\d+(\.\d+)?').matchAsPrefix(source, i);
    if (number != null) {
      tokens.add(_Token(_Kind.number, number.group(0)!));
      i = number.end;
      continue;
    }
    final ident = RegExp(r'[A-Za-z_@][A-Za-z0-9_.@:]*').matchAsPrefix(source, i);
    if (ident != null) {
      tokens.add(_Token(_Kind.ident, ident.group(0)!));
      i = ident.end;
      continue;
    }
    throw FilterSyntaxException('Неожиданный символ «$ch»');
  }
  tokens.add(const _Token(_Kind.end, ''));
  return tokens;
}

class _Parser {
  _Parser(this._tokens, this._resolve);

  final List<_Token> _tokens;
  final FieldResolver _resolve;
  int _pos = 0;

  _Token get _current => _tokens[_pos];

  RecordPredicate parse() {
    final node = _or();
    if (_current.kind != _Kind.end) {
      throw FilterSyntaxException('Лишний фрагмент «${_current.text}»');
    }
    return node;
  }

  RecordPredicate _or() {
    final parts = [_and()];
    while (_current.kind == _Kind.or) {
      _pos++;
      parts.add(_and());
    }
    return parts.length == 1 ? parts.first : (r) => parts.any((p) => p(r));
  }

  RecordPredicate _and() {
    final parts = [_atom()];
    while (_current.kind == _Kind.and) {
      _pos++;
      parts.add(_atom());
    }
    return parts.length == 1 ? parts.first : (r) => parts.every((p) => p(r));
  }

  RecordPredicate _atom() {
    if (_current.kind == _Kind.open) {
      _pos++;
      final inner = _or();
      if (_current.kind != _Kind.close) {
        throw const FilterSyntaxException('Ожидалась закрывающая скобка');
      }
      _pos++;
      return inner;
    }
    final left = _operand();
    if (_current.kind != _Kind.op) {
      throw const FilterSyntaxException('Ожидался оператор сравнения');
    }
    final op = _current.text;
    _pos++;
    final right = _operand();
    final any = op.startsWith('?');
    final base = any ? op.substring(1) : op;
    return (record) {
      final l = left(record);
      final r = right(record);
      bool test(Object? a, Object? b) => _compare(base, a, b);
      if (any) {
        return l.any((a) => r.any((b) => test(a, b)));
      }
      return l.every((a) => r.every((b) => test(a, b)));
    };
  }

  List<Object?> Function(Map<String, dynamic>) _operand() {
    final token = _current;
    _pos++;
    switch (token.kind) {
      case _Kind.string:
        return (_) => [token.text];
      case _Kind.number:
        final value = num.parse(token.text);
        return (_) => [value];
      case _Kind.ident:
        switch (token.text) {
          case 'true':
            return (_) => [true];
          case 'false':
            return (_) => [false];
          case 'null':
            return (_) => [''];
        }
        return (record) => _resolve(record, token.text);
      default:
        throw FilterSyntaxException('Неожиданный фрагмент «${token.text}»');
    }
  }
}

num? _asNum(Object? v) {
  if (v is num) return v;
  if (v is String && v.isNotEmpty) return num.tryParse(v);
  return null;
}

bool _compare(String op, Object? a, Object? b) {
  final x = a ?? '';
  final y = b ?? '';
  switch (op) {
    case '~':
      return '$x'.toLowerCase().contains('$y'.toLowerCase());
    case '!~':
      return !'$x'.toLowerCase().contains('$y'.toLowerCase());
  }
  final nx = x is num || y is num ? _asNum(x) : null;
  final ny = x is num || y is num ? _asNum(y) : null;
  final int order;
  if (nx != null && ny != null) {
    order = nx.compareTo(ny);
  } else {
    order = '$x'.compareTo('$y');
  }
  return switch (op) {
    '=' => order == 0,
    '!=' => order != 0,
    '>' => order > 0,
    '>=' => order >= 0,
    '<' => order < 0,
    '<=' => order <= 0,
    _ => false,
  };
}

RecordPredicate compileFilter(String filter, FieldResolver resolve) {
  if (filter.trim().isEmpty) return (_) => true;
  return _Parser(_tokenize(filter), resolve).parse();
}
