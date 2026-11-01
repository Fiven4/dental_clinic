import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DropdownFilter<V> extends StatelessWidget {
  final String label;
  final V? value;
  final List<(V, String)> options;
  final ValueChanged<V?> onChanged;
  final double width;

  const DropdownFilter({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.width = 200,
  });

  @override
  Widget build(BuildContext context) {
    final known = options.any((o) => o.$1 == value);
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<V?>(
        key: ValueKey('$label-$value'),
        initialValue: known ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          DropdownMenuItem<V?>(value: null, child: const Text('Все')),
          for (final o in options)
            DropdownMenuItem<V?>(
              value: o.$1,
              child: Text(o.$2, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class NumberFilterField extends StatefulWidget {
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final double width;

  const NumberFilterField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.width = 110,
  });

  @override
  State<NumberFilterField> createState() => _NumberFilterFieldState();
}

class _NumberFilterFieldState extends State<NumberFilterField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void didUpdateWidget(NumberFilterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        int.tryParse(_controller.text) != widget.value) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (text) => widget.onChanged(int.tryParse(text)),
      ),
    );
  }
}

class DateFilterField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final double width;

  const DateFilterField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.width = 170,
  });

  static String _format(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(BuildContext context) async {
    final current = DateTime.tryParse(value ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onChanged(_format(picked));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => _pick(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: value == null
                ? const Icon(Icons.calendar_today_outlined, size: 18)
                : IconButton(
                    tooltip: 'Очистить',
                    iconSize: 18,
                    icon: const Icon(Icons.close),
                    onPressed: () => onChanged(null),
                  ),
          ),
          child: Text(value ?? ''),
        ),
      ),
    );
  }
}
