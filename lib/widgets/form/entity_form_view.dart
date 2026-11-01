import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/breakpoints.dart';
import '../../core/debouncer.dart';
import '../../state/entity_form_notifier.dart';
import '../../state/load_status.dart';
import '../state_views.dart';
import 'field_specs.dart';

class EntityFormView<T> extends StatefulWidget {
  final EntityFormNotifier<T> notifier;
  final String createTitle;
  final String Function(T item) editTitle;
  final String listPath;
  final List<FieldSpec> Function(bool isEditing) specs;
  final FormValues Function(T? item) initialValues;
  final T Function(FormValues values, T? existing) build;

  const EntityFormView({
    super.key,
    required this.notifier,
    required this.createTitle,
    required this.editTitle,
    required this.listPath,
    required this.specs,
    required this.initialValues,
    required this.build,
  });

  @override
  State<EntityFormView<T>> createState() => _EntityFormViewState<T>();
}

class _EntityFormViewState<T> extends State<EntityFormView<T>> {
  final _formKey = GlobalKey<FormState>();
  FormValues _values = {};
  FormValues _initial = {};
  bool _inited = false;
  bool _leaving = false;

  final Map<String, String> _errorValues = {};

  EntityFormNotifier<T> get _notifier => widget.notifier;

  static FormValues _copy(FormValues v) => {
    for (final e in v.entries)
      e.key: e.value is List ? List<Object?>.of(e.value as List) : e.value,
  };

  static bool _same(Object? a, Object? b) {
    if (a is List && b is List) {
      return a.length == b.length &&
          [
            for (var i = 0; i < a.length; i++) _same(a[i], b[i]),
          ].every((x) => x);
    }
    return a == b;
  }

  bool get _dirty {
    if (!_inited) return false;
    final keys = {..._values.keys, ..._initial.keys};
    return keys.any((k) => !_same(_values[k], _initial[k]));
  }

  void _set(String key, Object? value) {
    setState(() => _values[key] = value);
  }

  String _snapshot(Object? v) => '$v';

  String? _serverError(String key, Object? value) {
    final error = _notifier.fieldErrors[key];
    if (error != null && _errorValues[key] == _snapshot(value)) return error;
    return null;
  }

  void _pop() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.listPath);
    }
  }

  Future<void> _askLeave() async {
    if (!_dirty) {
      _pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text(
          'Введённые данные будут потеряны. Уйти без сохранения?',
        ),
        actions: [
          TextButton(
            key: const ValueKey('stay'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            key: const ValueKey('leave'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Уйти'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pop();
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final form = _formKey.currentState!;
    if (!form.validate()) {
      _toast('Исправьте ошибки в форме');
      return;
    }
    final saved = await _notifier.submit(widget.build(_values, _notifier.item));
    if (!mounted) return;
    if (saved == null) {
      for (final key in _notifier.fieldErrors.keys) {
        _errorValues[key] = _snapshot(_values[key]);
      }
      form.validate();
      return;
    }
    _toast(_notifier.isEditing ? 'Изменения сохранены' : 'Запись создана');
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = screenSizeOf(context) == ScreenSize.compact;
    return PopScope(
      canPop: _leaving || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askLeave();
      },
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 24),
        child: ListenableBuilder(
          listenable: _notifier,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('back-button'),
                  onPressed: _askLeave,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('К списку'),
                ),
              ),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_notifier.status == LoadStatus.error) {
      return ErrorView(
        message: _notifier.error ?? 'Ошибка',
        onRetry: _notifier.load,
      );
    }
    if (_notifier.status != LoadStatus.success) return const LoadingView();
    if (_notifier.notFound) {
      return const EmptyView(
        message: 'Запись не найдена или удалена навсегда.',
      );
    }

    if (!_inited) {
      _values = _copy(widget.initialValues(_notifier.item));
      _initial = _copy(_values);
      _inited = true;
    }

    final theme = Theme.of(context);
    final editing = _notifier.isEditing;
    final specs = widget.specs(editing);
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  editing
                      ? widget.editTitle(_notifier.item as T)
                      : widget.createTitle,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                if (_notifier.error != null)
                  Container(
                    key: const ValueKey('form-error'),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _notifier.error!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                for (final spec in specs) ..._field(spec),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('submit-button'),
                      onPressed: _notifier.saving ? null : _submit,
                      icon: _notifier.saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(editing ? 'Сохранить' : 'Создать'),
                    ),
                    OutlinedButton(
                      key: const ValueKey('cancel-button'),
                      onPressed: _askLeave,
                      child: const Text('Отмена'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _field(FieldSpec spec) {
    const gap = SizedBox(height: 16);
    return switch (spec) {
      TextSpec() => [_TextInput(spec: spec, state: this), gap],
      DateSpec() => [_DateInput(spec: spec, state: this), gap],
      DateTimeSpec() => [_DateTimeInput(spec: spec, state: this), gap],
      LookupSpec() => [_buildLookup(spec), gap],
      CustomSpec() => [spec.builder(context, _values), gap],
      DropdownSpec() => [_buildDropdown(spec), gap],
      MultiSpec() => [_buildMulti(spec), gap],
      SwitchSpec() => [
        SwitchListTile(
          key: ValueKey('switch-${spec.key}'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(spec.label),
          value: _values[spec.key] as bool? ?? false,
          onChanged: (v) => _set(spec.key, v),
        ),
      ],
      GroupSpec() => [_group(spec), gap],
    };
  }

  Widget _group(GroupSpec spec) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(spec.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final f in spec.fields) ..._field(f),
        ],
      ),
    );
  }

  Widget _buildDropdown(DropdownSpec spec) {
    final options = spec.options(_values);
    var value = _values[spec.key] as String?;
    if (value != null && !options.any((o) => o.$1 == value)) {
      value = null;
      _values[spec.key] = null;
    }
    return DropdownButtonFormField<String>(
      key: ValueKey(
        'dd-${spec.key}-$value-${options.map((o) => o.$1).join(',')}',
      ),
      initialValue: value,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: spec.required ? '${spec.label} *' : spec.label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final o in options)
          DropdownMenuItem(
            value: o.$1,
            child: Text(o.$2, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        _notifier.clearFieldError(spec.key);
        _set(spec.key, v);
      },
      validator: (v) {
        if (spec.required && v == null) {
          return spec.requiredMessage ?? 'Выберите значение';
        }
        return _serverError(spec.key, v);
      },
    );
  }

  Widget _buildLookup(LookupSpec spec) {
    final id = _values[spec.key] as String?;
    final label = _values[spec.labelKey] as String? ?? '';
    return FormField<String>(
      key: ValueKey('lookup-${spec.key}-$id'),
      initialValue: id,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        if (spec.required && (value == null || value.isEmpty)) {
          return spec.requiredMessage ?? 'Выберите значение';
        }
        return _serverError(spec.key, value);
      },
      builder: (field) => InkWell(
        key: ValueKey('lookup-field-${spec.key}'),
        borderRadius: BorderRadius.circular(4),
        onTap: () async {
          final picked = await showDialog<Option>(
            context: context,
            builder: (context) => _LookupDialog(spec: spec),
          );
          if (picked == null) return;
          _notifier.clearFieldError(spec.key);
          setState(() {
            _values[spec.key] = picked.$1;
            _values[spec.labelKey] = picked.$2;
          });
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: spec.required ? '${spec.label} *' : spec.label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.search),
            errorText: field.errorText,
          ),
          child: Text(
            label.isEmpty ? 'Нажмите, чтобы выбрать' : label,
            style: label.isEmpty
                ? TextStyle(color: Theme.of(context).hintColor)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildMulti(MultiSpec spec) {
    final options = spec.options(_values);
    final current = List<String>.of(
      (_values[spec.key] as List?)?.cast<String>() ?? const [],
    );
    return FormField<List<String>>(
      key: ValueKey('multi-${spec.key}-${options.map((o) => o.$1).join(',')}'),
      initialValue: current,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) {
        if (spec.required && (value == null || value.isEmpty)) {
          return spec.requiredMessage ?? 'Выберите хотя бы одно значение';
        }
        return _serverError(spec.key, value);
      },
      builder: (field) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: spec.required ? '${spec.label} *' : spec.label,
            border: const OutlineInputBorder(),
            helperText: spec.helper,
            helperMaxLines: 2,
            errorText: field.errorText,
          ),
          child: options.isEmpty
              ? const Text('Нет доступных значений')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final o in options)
                      FilterChip(
                        key: ValueKey('chip-${spec.key}-${o.$1}'),
                        label: Text(o.$2),
                        selected: field.value!.contains(o.$1),
                        onSelected: (_) {
                          final next = [...field.value!];
                          next.contains(o.$1)
                              ? next.remove(o.$1)
                              : next.add(o.$1);
                          field.didChange(next);
                          _notifier.clearFieldError(spec.key);
                          _set(spec.key, next);
                        },
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _TextInput extends StatefulWidget {
  final TextSpec spec;
  final _EntityFormViewState state;

  const _TextInput({required this.spec, required this.state});

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.state._values[widget.spec.key] as String? ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final form = widget.state;
    return TextFormField(
      key: ValueKey('field-${spec.key}'),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: _controller,
      keyboardType: spec.keyboard,
      inputFormatters: spec.formatters,
      maxLines: spec.maxLines,
      decoration: InputDecoration(
        labelText: spec.required ? '${spec.label} *' : spec.label,
        hintText: spec.hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: spec.maxLines > 1,
      ),
      validator: (value) {
        final text = value ?? '';
        final local = spec.validator?.call(text, form._values);
        return local ?? form._serverError(spec.key, text);
      },
      onChanged: (value) {
        form._notifier.clearFieldError(spec.key);
        form._set(spec.key, value);
      },
    );
  }
}

class _DateInput extends StatefulWidget {
  final DateSpec spec;
  final _EntityFormViewState state;

  const _DateInput({required this.spec, required this.state});

  @override
  State<_DateInput> createState() => _DateInputState();
}

class _DateInputState extends State<_DateInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.state._values[widget.spec.key] as String? ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final current = DateTime.tryParse(_controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _controller.text = text;
      widget.state._set(widget.spec.key, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final form = widget.state;
    return TextFormField(
      key: ValueKey('field-${spec.key}'),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: _controller,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: spec.required ? '${spec.label} *' : spec.label,
        hintText: 'ГГГГ-ММ-ДД',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: 'Выбрать дату',
          icon: const Icon(Icons.calendar_today_outlined),
          onPressed: _pick,
        ),
      ),
      validator: (value) {
        final text = value ?? '';
        final local = spec.validator?.call(text, form._values);
        return local ?? form._serverError(spec.key, text);
      },
      onChanged: (value) {
        form._notifier.clearFieldError(spec.key);
        form._set(spec.key, value);
      },
    );
  }
}

class _LookupDialog extends StatefulWidget {
  final LookupSpec spec;

  const _LookupDialog({required this.spec});

  @override
  State<_LookupDialog> createState() => _LookupDialogState();
}

class _LookupDialogState extends State<_LookupDialog> {
  final _controller = TextEditingController();
  final _debouncer = Debouncer();
  List<Option> _options = const [];
  bool _loading = true;
  String? _error;
  int _ticket = 0;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debouncer.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load(String text) async {
    final ticket = ++_ticket;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await widget.spec.search(text);
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.spec.label),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          children: [
            TextField(
              key: const ValueKey('lookup-search'),
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Начните вводить для поиска',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (text) =>
                  _debouncer.run(() => _load(text.trim())),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _options.isEmpty
                  ? const Center(child: Text('Ничего не найдено'))
                  : ListView.builder(
                      itemCount: _options.length,
                      itemBuilder: (context, i) => ListTile(
                        key: ValueKey('lookup-option-${_options[i].$1}'),
                        dense: true,
                        title: Text(_options[i].$2),
                        onTap: () => Navigator.pop(context, _options[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _DateTimeInput extends StatefulWidget {
  final DateTimeSpec spec;
  final _EntityFormViewState state;

  const _DateTimeInput({required this.spec, required this.state});

  @override
  State<_DateTimeInput> createState() => _DateTimeInputState();
}

class _DateTimeInputState extends State<_DateTimeInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.state._values[widget.spec.key] as String? ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  Future<void> _pick() async {
    final parsed = DateTime.tryParse(_controller.text.replaceFirst(' ', 'T'));
    final current = parsed ?? DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null) return;
    final text =
        '${day.year.toString().padLeft(4, '0')}-${_two(day.month)}-${_two(day.day)} '
        '${_two(time.hour)}:${_two(time.minute)}';
    _controller.text = text;
    widget.state._set(widget.spec.key, text);
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final form = widget.state;
    return TextFormField(
      key: ValueKey('field-${spec.key}'),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: _controller,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: spec.required ? '${spec.label} *' : spec.label,
        hintText: 'ГГГГ-ММ-ДД ЧЧ:ММ',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: 'Выбрать дату и время',
          icon: const Icon(Icons.event_outlined),
          onPressed: _pick,
        ),
      ),
      validator: (value) {
        final text = value ?? '';
        final local = spec.validator?.call(text, form._values);
        return local ?? form._serverError(spec.key, text);
      },
      onChanged: (value) {
        form._notifier.clearFieldError(spec.key);
        form._set(spec.key, value);
      },
    );
  }
}
