import 'package:flutter/material.dart';

import '../field_spec.dart';
import 'form_field.dart';

/// A text field.
///
/// `minLines` and `maxLines` in the schema work like TextField's:
///
///  * neither: a single line
///  * `maxLines: n`: starts one line tall, grows to n lines, then scrolls
///  * `minLines: m` and `maxLines: n`: starts m lines tall, grows to n lines
///  * `minLines: m` alone: starts m lines tall and grows without limit
///
/// The last case is the one place the schema is more forgiving than
/// TextField, which would reject it against its default `maxLines` of 1.
///
/// A field that can grow past one line is a text area: Enter inserts a
/// newline. Both values must be positive whole numbers.
class JsonFormTextFieldInput extends JsonFormFieldInput {
  const JsonFormTextFieldInput();

  @override
  String get type => 'text';

  @override
  Object? normalizeInitialValue(Object? raw) => raw?.toString();

  /// [name] from the schema as a positive whole number, or null if absent.
  static int? _positiveInt(FieldSpec spec, String name) {
    final raw = spec.raw[name];
    if (raw == null) return null;
    final int? value;
    if (raw is int) {
      value = raw;
    } else if (raw is double && raw.isFinite && raw == raw.truncateToDouble()) {
      value = raw.toInt();
    } else {
      value = null;
    }
    if (value == null || value < 1) {
      throw FormatException(
        '"$name" of "${spec.key}" must be a positive whole number: $raw',
      );
    }
    return value;
  }

  /// The `minLines` and `maxLines` to give the TextField for [spec].
  static ({int? min, int? max}) _lines(FieldSpec spec) {
    final min = _positiveInt(spec, 'minLines');
    final max = _positiveInt(spec, 'maxLines');
    if (min != null && max != null && min > max) {
      throw FormatException(
        '"${spec.key}" has minLines $min greater than maxLines $max',
      );
    }
    return (min: min, max: max ?? (min == null ? 1 : null));
  }

  @override
  void validate(FieldSpec spec) => _lines(spec);

  @override
  Widget build(
    BuildContext context,
    FieldSpec spec, {
    required Object? initialValue,
    required void Function(dynamic value) onChanged,
    required void Function(dynamic value) onSaved,
  }) {
    final lines = _lines(spec);
    final multiline = lines.max != 1;
    return TextFormField(
      initialValue: initialValue as String?,
      decoration: InputDecoration(
        labelText: spec.label ?? spec.key,
        alignLabelWithHint: multiline,
      ),
      keyboardType: multiline ? TextInputType.multiline : null,
      minLines: lines.min,
      maxLines: lines.max,
      validator: (v) =>
          spec.required && (v == null || v.trim().isEmpty) ? 'Required' : null,
      onChanged: onChanged,
      onSaved: onSaved,
    );
  }
}
