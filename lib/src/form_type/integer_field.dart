import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../field_spec.dart';
import 'form_field.dart';

/// A whole-number field. Optional `min` and `max` in the schema clamp the
/// value: anything outside the range becomes the nearest bound.
///
/// Clamping happens when the field loses focus, not while typing, because
/// clamping each keystroke would make it impossible to type 25 when the
/// minimum is 18 (the "2" would jump to 18 first). The value the form
/// reports and saves is always clamped, whether or not the text has been
/// tidied yet.
class JsonFormIntegerFieldInput extends JsonFormFieldInput {
  const JsonFormIntegerFieldInput();

  @override
  String get type => 'integer';

  @override
  Object? normalizeInitialValue(Object? raw) {
    if (raw is int) return raw;
    if (raw is double && raw.isFinite && raw == raw.truncateToDouble()) {
      return raw.toInt();
    }
    return null;
  }

  static int? _bound(FieldSpec spec, String name) {
    final raw = spec.raw[name];
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is double && raw.isFinite && raw == raw.truncateToDouble()) {
      return raw.toInt();
    }
    throw FormatException(
      '"$name" of "${spec.key}" must be a whole number: $raw',
    );
  }

  static ({int? min, int? max}) _range(FieldSpec spec) {
    final min = _bound(spec, 'min');
    final max = _bound(spec, 'max');
    if (min != null && max != null && min > max) {
      throw FormatException('"${spec.key}" has min $min greater than max $max');
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
    final min = _bound(spec, 'min');
    final max = _bound(spec, 'max');
    if (min != null && max != null && min > max) {
      throw FormatException('"${spec.key}" has min $min greater than max $max');
    }
    return _IntegerField(
      spec: spec,
      min: min,
      max: max,
      initialValue: initialValue is int ? initialValue : null,
      onChanged: onChanged,
      onSaved: onSaved,
    );
  }
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

class _IntegerField extends StatefulWidget {
  const _IntegerField({
    required this.spec,
    required this.min,
    required this.max,
    required this.initialValue,
    required this.onChanged,
    required this.onSaved,
  });

  final FieldSpec spec;
  final int? min;
  final int? max;
  final int? initialValue;
  final void Function(dynamic value) onChanged;
  final void Function(dynamic value) onSaved;

  @override
  State<_IntegerField> createState() => _IntegerFieldState();
}

class _IntegerFieldState extends State<_IntegerField> {
  late final TextEditingController _controller;
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);

  bool get _allowNegative => widget.min == null || widget.min! < 0;

  /// Whether [text] is, so far, a valid whole number: an optional leading
  /// minus (only if negatives are allowed) followed by any number of digits.
  /// Empty text and a lone minus pass, so the user can keep typing.
  bool _hasWholeNumberShape(String text) {
    final digits =
        _allowNegative && text.startsWith('-') ? text.substring(1) : text;
    return digits.codeUnits.every(_isDigit);
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    final clamped = initial == null ? null : _clamp(initial);
    _controller = TextEditingController(text: clamped?.toString() ?? '');
    if (clamped != initial) {
      // The field now shows the clamped value, so tell the form, or a
      // condition reading this field would see the unclamped one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(clamped);
      });
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  int _clamp(int value) {
    final min = widget.min;
    final max = widget.max;
    if (min != null && value < min) return min;
    if (max != null && value > max) return max;
    return value;
  }

  /// The number in [text], or null if it is empty or not a whole number.
  int? _parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed);
    if (value != null) return value;
    // On native platforms, digits too long for an int fail to parse. They
    // are far outside any range, so they count as the nearest bound; with
    // no such bound they stay invalid.
    final negative = trimmed.startsWith('-');
    final digits = negative ? trimmed.substring(1) : trimmed;
    if (digits.isNotEmpty && digits.codeUnits.every(_isDigit)) {
      return negative ? widget.min : widget.max;
    }
    return null;
  }

  /// The clamped number in [text], or null.
  int? _value(String? text) {
    final parsed = _parse(text ?? '');
    return parsed == null ? null : _clamp(parsed);
  }

  void _onFocusChange() {
    if (_focus.hasFocus) return;
    final value = _value(_controller.text);
    // Empty or invalid text is left as typed; the validator reports it.
    if (value == null) return;
    final text = value.toString();
    if (_controller.text != text) _controller.text = text;
  }

  String? _validate(String? text) {
    final trimmed = (text ?? '').trim();
    if (trimmed.isEmpty) return widget.spec.required ? 'Required' : null;
    return _parse(trimmed) == null ? 'Enter a whole number' : null;
  }

  String? get _rangeHint {
    final min = widget.min;
    final max = widget.max;
    if (min != null && max != null) return '$min to $max';
    if (min != null) return 'Minimum $min';
    if (max != null) return 'Maximum $max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focus,
      decoration: InputDecoration(
        labelText: widget.spec.label ?? widget.spec.key,
        helperText: _rangeHint,
      ),
      keyboardType: TextInputType.numberWithOptions(signed: _allowNegative),
      inputFormatters: [
        TextInputFormatter.withFunction(
          (oldValue, newValue) =>
              _hasWholeNumberShape(newValue.text) ? newValue : oldValue,
        ),
      ],
      validator: _validate,
      onChanged: (text) => widget.onChanged(_value(text)),
      onSaved: (text) => widget.onSaved(_value(text)),
    );
  }
}
