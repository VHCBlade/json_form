import 'package:flutter/material.dart';

import '../field_spec.dart';
import 'form_field.dart';

/// A calendar date, chosen from a date picker.
///
/// The value is an ISO 8601 date string such as `2026-10-10`, in the output,
/// in conditions and in `initialValues`. When reading one, a time after the
/// date is ignored.
///
/// `min` and `max` in the schema, written the same way, bound the picker. A
/// prefilled date outside them is clamped to the nearest bound.
class JsonFormDateFieldInput extends JsonFormFieldInput {
  const JsonFormDateFieldInput();

  @override
  String get type => 'date';

  @override
  Object? normalizeInitialValue(Object? raw) {
    final date = _parseDate(raw);
    return date == null ? null : _format(date);
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

  /// [raw] as a date with no time, or null if it is not a real date written
  /// as `yyyy-MM-dd`, optionally followed by `T` or a space and a time.
  static DateTime? _parseDate(Object? raw) {
    if (raw is DateTime) return DateTime(raw.year, raw.month, raw.day);
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.length < 10 || text[4] != '-' || text[7] != '-') return null;
    if (text.length > 10 && text[10] != 'T' && text[10] != ' ') return null;
    final year = text.substring(0, 4);
    final month = text.substring(5, 7);
    final day = text.substring(8, 10);
    for (final part in [year, month, day]) {
      if (!part.codeUnits.every(_isDigit)) return null;
    }
    final y = int.parse(year);
    final m = int.parse(month);
    final d = int.parse(day);
    final date = DateTime(y, m, d);
    // DateTime rolls 30 February over into March, which would silently
    // change the date, so only accept a date that survived unchanged.
    return date.year == y && date.month == m && date.day == d ? date : null;
  }

  static String _format(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime? _bound(FieldSpec spec, String name) {
    final raw = spec.raw[name];
    if (raw == null) return null;
    final date = _parseDate(raw);
    if (date == null) {
      throw FormatException(
        '"$name" of "${spec.key}" must be a date like 2026-10-10: $raw',
      );
    }
    return date;
  }

  static ({DateTime? min, DateTime? max}) _range(FieldSpec spec) {
    final min = _bound(spec, 'min');
    final max = _bound(spec, 'max');
    if (min != null && max != null && min.isAfter(max)) {
      throw FormatException(
        '"${spec.key}" has min ${_format(min)} later than max ${_format(max)}',
      );
    }
    return (min: min, max: max);
  }

  @override
  void validate(FieldSpec spec) => _range(spec);

  @override
  Widget build(
    BuildContext context,
    FieldSpec spec, {
    required Object? initialValue,
    required void Function(dynamic value) onChanged,
    required void Function(dynamic value) onSaved,
  }) {
    final range = _range(spec);
    return _DateField(
      spec: spec,
      min: range.min,
      max: range.max,
      initialValue: initialValue,
      onChanged: onChanged,
      onSaved: onSaved,
    );
  }
}

class _DateField extends StatefulWidget {
  const _DateField({
    required this.spec,
    required this.min,
    required this.max,
    required this.initialValue,
    required this.onChanged,
    required this.onSaved,
  });

  final FieldSpec spec;
  final DateTime? min;
  final DateTime? max;
  final Object? initialValue;
  final void Function(dynamic value) onChanged;
  final void Function(dynamic value) onSaved;

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final TextEditingController _controller;
  DateTime? _value;

  @override
  void initState() {
    super.initState();
    final initial = JsonFormDateFieldInput._parseDate(widget.initialValue);
    _value = initial == null ? null : _clamp(initial);
    _controller = TextEditingController(
      text: _value == null ? '' : JsonFormDateFieldInput._format(_value!),
    );
    if (initial != null && _value != initial) {
      // The field now shows the clamped date, so tell the form, or a
      // condition reading this field would see the unclamped one.
      final iso = JsonFormDateFieldInput._format(_value!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(iso);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime _clamp(DateTime date) {
    final min = widget.min;
    final max = widget.max;
    if (min != null && date.isBefore(min)) return min;
    if (max != null && date.isAfter(max)) return max;
    return date;
  }

  void _set(DateTime? date) {
    setState(() {
      _value = date;
      _controller.text =
          date == null ? '' : JsonFormDateFieldInput._format(date);
    });
    widget.onChanged(
      date == null ? null : JsonFormDateFieldInput._format(date),
    );
  }

  Future<void> _pick() async {
    final min = widget.min;
    final max = widget.max;
    // A picker needs both ends, and they must not be reversed.
    final first =
        min ?? DateTime(max != null && max.year < 1900 ? max.year : 1900);
    final last = max ??
        DateTime(min != null && min.year > 2100 ? min.year : 2100, 12, 31);
    final now = DateTime.now();
    var start = _value ?? DateTime(now.year, now.month, now.day);
    if (start.isBefore(first)) start = first;
    if (start.isAfter(last)) start = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    _set(DateTime(picked.year, picked.month, picked.day));
  }

  String? get _rangeHint {
    final min = widget.min;
    final max = widget.max;
    String f(DateTime d) => JsonFormDateFieldInput._format(d);
    if (min != null && max != null) return '${f(min)} to ${f(max)}';
    if (min != null) return 'From ${f(min)}';
    if (max != null) return 'Until ${f(max)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      readOnly: true,
      showCursor: false,
      enableInteractiveSelection: false,
      onTap: _pick,
      decoration: InputDecoration(
        labelText: widget.spec.label ?? widget.spec.key,
        helperText: _rangeHint,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_value != null)
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.clear),
                onPressed: () => _set(null),
              ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.calendar_today, size: 20),
            ),
          ],
        ),
      ),
      validator: (text) =>
          widget.spec.required && (text == null || text.isEmpty)
              ? 'Required'
              : null,
      onSaved: (_) => widget.onSaved(
        _value == null ? null : JsonFormDateFieldInput._format(_value!),
      ),
    );
  }
}
