import 'package:flutter/material.dart';

import '../field_spec.dart';
import 'form_field.dart';

DateTime _systemClock() => DateTime.now();

/// A calendar date, chosen from a date picker.
///
/// The value is an ISO 8601 date string such as `2026-10-10`, in the output,
/// in conditions and in `initialValues`. When reading one, a time after the
/// date is ignored.
///
/// `min` and `max` in the schema bound the picker, and a prefilled date
/// outside them is clamped. Each is a date written the same way, or one of
/// these words, which follow the current date:
///
/// | word        | as `min`            | as `max`           |
/// | ----------- | ------------------- | ------------------ |
/// | `today`     | today               | today              |
/// | `thisMonth` | first of this month | last of this month |
/// | `thisYear`  | 1 January           | 31 December        |
///
/// A word may be followed by offsets, each a sign, a whole number and a unit:
/// `d` days, `w` weeks, `m` months, `y` years. So `today+30d` is thirty days
/// from now and `today-18y` is eighteen years ago, and several can be chained,
/// as in `today+1y-1d`. Spaces are ignored.
///
/// Offsets are calendar offsets, applied left to right. A month or year offset
/// that would land after the end of the month keeps to its last day, so
/// 31 January plus a month is the last day of February. The words stand for
/// the whole month or year when shifted by whole months or years: as a `max`,
/// `thisMonth+1m` is the last day of next month, not a month after the last
/// day of this one. Days, weeks, and months on `thisYear`, are applied to the
/// resulting date.
///
/// So `"min": "thisYear", "max": "thisYear"` allows any day of the current
/// year. Bounds are resolved when they are used, against [clock], which
/// defaults to the device's time.
class JsonFormDateFieldInput extends JsonFormFieldInput {
  const JsonFormDateFieldInput({this.clock = _systemClock});

  /// Supplies "now". Replace it to control what `today` means, in tests for
  /// instance.
  final DateTime Function() clock;

  @override
  String get type => 'date';

  static const _words = ['today', 'thisMonth', 'thisYear'];

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

  DateTime _today() {
    final now = clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// [date] moved by [months], keeping to the last day of a shorter month.
  static DateTime _addMonths(DateTime date, int months) {
    final index = date.year * 12 + (date.month - 1) + months;
    final year = (index - index % 12) ~/ 12;
    final month = index % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, date.day < lastDay ? date.day : lastDay);
  }

  /// [raw] resolved as a word with optional offsets, or null if it is not
  /// written that way. [isMax] decides which end of a month or year a word
  /// stands for.
  DateTime? _relative(String raw, {required bool isMax}) {
    final text = raw.split('').where((c) => c.trim().isNotEmpty).join();
    String? word;
    for (final candidate in _words) {
      if (text.startsWith(candidate)) word = candidate;
    }
    if (word == null) return null;

    final terms = <({int amount, String unit})>[];
    var i = word.length;
    while (i < text.length) {
      final sign = text[i++];
      if (sign != '+' && sign != '-') return null;
      final start = i;
      while (i < text.length && _isDigit(text.codeUnitAt(i))) {
        i++;
      }
      final digits = text.substring(start, i);
      // Five digits is far beyond any calendar use, and keeps the arithmetic
      // inside what DateTime can hold.
      if (digits.isEmpty || digits.length > 5 || i >= text.length) return null;
      final unit = text[i++];
      if (!'dwmy'.contains(unit)) return null;
      terms.add((
        amount: (sign == '-' ? -1 : 1) * int.parse(digits),
        unit: unit,
      ));
    }

    final today = _today();
    var date = switch (word) {
      'thisMonth' => DateTime(today.year, today.month, 1),
      'thisYear' => DateTime(today.year, 1, 1),
      _ => today,
    };
    // While a month or year is being shifted whole, `date` is its first day
    // and the real end is only chosen once nothing shifts it whole any more.
    String? period = word == 'today' ? null : word;

    void settle() {
      if (isMax && period == 'thisMonth') {
        date = DateTime(date.year, date.month + 1, 0);
      } else if (isMax && period == 'thisYear') {
        date = DateTime(date.year, 12, 31);
      }
      period = null;
    }

    for (final term in terms) {
      switch (term.unit) {
        case 'd':
          settle();
          date = DateTime(date.year, date.month, date.day + term.amount);
        case 'w':
          settle();
          date = DateTime(date.year, date.month, date.day + 7 * term.amount);
        case 'm':
          if (period == 'thisYear') settle();
          date = _addMonths(date, term.amount);
        case 'y':
          date = _addMonths(date, 12 * term.amount);
      }
    }
    settle();
    return DateTime(date.year, date.month, date.day);
  }

  /// The bound called [name] in [spec], or null if there is none.
  DateTime? _bound(FieldSpec spec, String name, {required bool isMax}) {
    final raw = spec.raw[name];
    if (raw == null) return null;
    if (raw is String) {
      final relative = _relative(raw, isMax: isMax);
      if (relative != null) return relative;
    }
    final date = _parseDate(raw);
    if (date == null) {
      throw FormatException(
        '"$name" of "${spec.key}" must be a date like 2026-10-10, or one of '
        '${_words.join(', ')} optionally followed by an offset such as +30d, '
        '-1y, +2w or +3m: $raw',
      );
    }
    return date;
  }

  ({DateTime? min, DateTime? max}) _range(FieldSpec spec) {
    final min = _bound(spec, 'min', isMax: false);
    final max = _bound(spec, 'max', isMax: true);
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
    // Fail now, at build, if the bounds are not usable.
    _range(spec);
    return _DateField(
      spec: spec,
      today: _today,
      // Resolved each time it is needed, so `today` stays current in a form
      // that is left open.
      bounds: () => _range(spec),
      initialValue: initialValue,
      onChanged: onChanged,
      onSaved: onSaved,
    );
  }
}

class _DateField extends StatefulWidget {
  const _DateField({
    required this.spec,
    required this.today,
    required this.bounds,
    required this.initialValue,
    required this.onChanged,
    required this.onSaved,
  });

  final FieldSpec spec;
  final DateTime Function() today;
  final ({DateTime? min, DateTime? max}) Function() bounds;
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
    final bounds = widget.bounds();
    final min = bounds.min;
    final max = bounds.max;
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
    final bounds = widget.bounds();
    final min = bounds.min;
    final max = bounds.max;
    // A picker needs both ends, and they must not be reversed.
    final first =
        min ?? DateTime(max != null && max.year < 1900 ? max.year : 1900);
    final last = max ??
        DateTime(min != null && min.year > 2100 ? min.year : 2100, 12, 31);
    var start = _value ?? widget.today();
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
    final bounds = widget.bounds();
    final min = bounds.min;
    final max = bounds.max;
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
