import 'package:flutter/material.dart';

import '../field_spec.dart';
import 'date_field.dart';
import 'form_field.dart';
import 'integer_field.dart';

/// Two fields of the same comparable kind that together span a range, such as
/// two dates or two numbers.
///
/// ```json
/// { "key": "stay", "type": "range", "of": "date", "label": "Stay",
///   "fromLabel": "Check in", "toLabel": "Check out", "required": true }
/// ```
///
/// `of` names the type of both ends. Every other property of the range, such
/// as `required`, `min` and `max`, is handed to both ends, so a range of
/// integers with `min: 0, max: 100` bounds each end to 0 to 100. `fromLabel`
/// and `toLabel` label the ends and default to "From" and "To".
///
/// The output is an object: `{"from": ..., "to": ...}`. If both ends are
/// filled in, the first must not come after the second; the check uses
/// [Comparable], which is why the values of the ends must be comparable and
/// of one type, as integers and ISO date strings are. A range that is not
/// `required` may leave either end empty, which gives an open-ended range.
///
/// A range can only span the types in [inputs], whatever the form itself has
/// registered. By default that is `integer` and `date`.
///
/// The range reads each end's live value, as reported by its `onChanged`, so
/// an input used inside a range must report changes.
class JsonFormRangeFieldInput extends JsonFormFieldInput {
  const JsonFormRangeFieldInput({
    this.inputs = const [JsonFormIntegerFieldInput(), JsonFormDateFieldInput()],
  });

  /// The inputs a range may span. If two share a type, the later one wins.
  final List<JsonFormFieldInput> inputs;

  @override
  String get type => 'range';

  /// Properties that belong to the range itself and are not passed to its
  /// ends.
  static const _rangeKeys = {
    'key',
    'type',
    'label',
    'of',
    'fromLabel',
    'toLabel',
    'visibleWhen',
  };

  @override
  Object? normalizeInitialValue(Object? raw) => raw is Map
      ? <String, dynamic>{'from': raw['from'], 'to': raw['to']}
      : <String, dynamic>{'from': null, 'to': null};

  FieldSpec _endSpec(
    FieldSpec spec,
    String of,
    String key,
    String labelKey,
    String defaultLabel,
  ) {
    final label = spec.raw[labelKey];
    if (label != null && label is! String) {
      throw FormatException(
        '"$labelKey" of "${spec.key}" must be a string: $label',
      );
    }
    return FieldSpec.fromJson({
      for (final e in spec.raw.entries)
        if (!_rangeKeys.contains(e.key)) e.key: e.value,
      'key': key,
      'type': of,
      'label': label ?? defaultLabel,
    });
  }

  ({JsonFormFieldInput input, FieldSpec from, FieldSpec to}) _ends(
    FieldSpec spec,
  ) {
    final of = spec.raw['of'];
    if (of is! String) {
      throw FormatException(
        'Range "${spec.key}" needs an "of" naming the type of its two ends',
      );
    }
    final matches = inputs.where((i) => i.type == of).toList();
    if (matches.isEmpty) {
      final types = {for (final i in inputs) i.type};
      throw FormatException(
        'Range "${spec.key}" cannot span "$of" fields; '
        'use one of: ${types.join(', ')}',
      );
    }
    return (
      input: matches.last,
      from: _endSpec(spec, of, 'from', 'fromLabel', 'From'),
      to: _endSpec(spec, of, 'to', 'toLabel', 'To'),
    );
  }

  @override
  void validate(FieldSpec spec) {
    final ends = _ends(spec);
    try {
      ends.input.validate(ends.from);
    } on FormatException catch (e) {
      throw FormatException('In range "${spec.key}": ${e.message}');
    }
  }

  @override
  Widget build(
    BuildContext context,
    FieldSpec spec, {
    required Object? initialValue,
    required void Function(dynamic value) onChanged,
    required void Function(dynamic value) onSaved,
  }) {
    final ends = _ends(spec);
    return _RangeField(
      spec: spec,
      input: ends.input,
      fromSpec: ends.from,
      toSpec: ends.to,
      initialValue: initialValue,
      onChanged: onChanged,
      onSaved: onSaved,
    );
  }
}

class _RangeField extends StatefulWidget {
  const _RangeField({
    required this.spec,
    required this.input,
    required this.fromSpec,
    required this.toSpec,
    required this.initialValue,
    required this.onChanged,
    required this.onSaved,
  });

  final FieldSpec spec;
  final JsonFormFieldInput input;
  final FieldSpec fromSpec;
  final FieldSpec toSpec;
  final Object? initialValue;
  final void Function(dynamic value) onChanged;
  final void Function(dynamic value) onSaved;

  @override
  State<_RangeField> createState() => _RangeFieldState();
}

class _RangeFieldState extends State<_RangeField> {
  final _orderKey = GlobalKey<FormFieldState<Object?>>();
  late Object? _from;
  late Object? _to;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    final map = initial is Map ? initial : const {};
    _from = widget.input.normalizeInitialValue(map['from']);
    _to = widget.input.normalizeInitialValue(map['to']);
  }

  Map<String, dynamic> _value() => {'from': _from, 'to': _to};

  /// How [a] compares with [b], or null if they cannot be compared.
  static int? _compare(Object a, Object b) {
    if (a is Comparable && b is Comparable && a.runtimeType == b.runtimeType) {
      return Comparable.compare(a, b);
    }
    return null;
  }

  String? _orderError() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return null;
    final order = _compare(from, to);
    if (order == null || order <= 0) return null;
    return '${widget.fromSpec.label} must not come after '
        '${widget.toSpec.label}';
  }

  void _reported() {
    widget.onChanged(_value());
    // Once the order error is showing, keep it in step with what is typed.
    final order = _orderKey.currentState;
    if (order != null && order.hasError) order.validate();
  }

  void _fromChanged(dynamic value) {
    _from = value;
    _reported();
  }

  void _toChanged(dynamic value) {
    _to = value;
    _reported();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            widget.spec.label ?? widget.spec.key,
            style: theme.textTheme.titleSmall,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: widget.input.build(
                context,
                widget.fromSpec,
                initialValue: _from,
                onChanged: _fromChanged,
                onSaved: (_) {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: widget.input.build(
                context,
                widget.toSpec,
                initialValue: _to,
                onChanged: _toChanged,
                onSaved: (_) {},
              ),
            ),
          ],
        ),
        // Built after both ends so its error sits underneath them.
        FormField<Object?>(
          key: _orderKey,
          validator: (_) => _orderError(),
          onSaved: (_) => widget.onSaved(_value()),
          builder: (state) => state.hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    state.errorText!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
