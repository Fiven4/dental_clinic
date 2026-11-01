import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../../core/validators.dart';

typedef FormValues = Map<String, Object?>;

typedef Option = (String id, String label);

typedef TextValidator = String? Function(String? value, FormValues values);

sealed class FieldSpec {
  const FieldSpec();
}

TextValidator plain(Validator v) =>
    (value, _) => v(value);

class TextSpec extends FieldSpec {
  final String key;
  final String label;
  final bool required;
  final TextValidator? validator;
  final TextInputType? keyboard;
  final int maxLines;
  final String? hint;
  final bool digitsOnly;

  const TextSpec({
    required this.key,
    required this.label,
    this.required = false,
    this.validator,
    this.keyboard,
    this.maxLines = 1,
    this.hint,
    this.digitsOnly = false,
  });

  List<TextInputFormatter>? get formatters =>
      digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null;
}

class DateSpec extends FieldSpec {
  final String key;
  final String label;
  final bool required;
  final TextValidator? validator;

  const DateSpec({
    required this.key,
    required this.label,
    this.required = false,
    this.validator,
  });
}

class DateTimeSpec extends FieldSpec {
  final String key;
  final String label;
  final bool required;
  final TextValidator? validator;

  const DateTimeSpec({
    required this.key,
    required this.label,
    this.required = false,
    this.validator,
  });
}

class LookupSpec extends FieldSpec {
  final String key;
  final String label;
  final bool required;
  final String? requiredMessage;
  final Future<List<Option>> Function(String text) search;

  const LookupSpec({
    required this.key,
    required this.label,
    required this.search,
    this.required = false,
    this.requiredMessage,
  });

  String get labelKey => '${key}Label';
}

class CustomSpec extends FieldSpec {
  final Widget Function(BuildContext context, FormValues values) builder;

  const CustomSpec(this.builder);
}

class DropdownSpec extends FieldSpec {
  final String key;
  final String label;
  final bool required;
  final String? requiredMessage;
  final List<Option> Function(FormValues values) options;

  const DropdownSpec({
    required this.key,
    required this.label,
    required this.options,
    this.required = false,
    this.requiredMessage,
  });
}

class MultiSpec extends FieldSpec {
  final String key;
  final String label;
  final bool required;
  final String? requiredMessage;
  final String? helper;
  final List<Option> Function(FormValues values) options;

  const MultiSpec({
    required this.key,
    required this.label,
    required this.options,
    this.required = false,
    this.requiredMessage,
    this.helper,
  });
}

class SwitchSpec extends FieldSpec {
  final String key;
  final String label;

  const SwitchSpec({required this.key, required this.label});
}

class GroupSpec extends FieldSpec {
  final String title;
  final List<FieldSpec> fields;

  const GroupSpec({required this.title, required this.fields});
}

Iterable<String> keysOf(List<FieldSpec> specs) sync* {
  for (final s in specs) {
    switch (s) {
      case TextSpec(:final key) ||
          DateSpec(:final key) ||
          DateTimeSpec(:final key) ||
          LookupSpec(:final key) ||
          DropdownSpec(:final key) ||
          MultiSpec(:final key) ||
          SwitchSpec(:final key):
        yield key;
      case GroupSpec(:final fields):
        yield* keysOf(fields);
      case CustomSpec():
        break;
    }
  }
}
