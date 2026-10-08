import 'package:flutter/widgets.dart';
import 'package:json_form/src/field_spec.dart';

abstract class JsonFormFieldInput {
  const JsonFormFieldInput();

  /// The schema `type` value this input handles.
  String get type;

  /// Builds the widget. Call [onSaved] with the field's value when the
  /// form is saved.
  Widget build(
    BuildContext context,
    FieldSpec spec, {
    required Object? initialValue,
    required void Function(dynamic value) onSaved,
    required void Function(dynamic value) onChanged,
  });

  /// Turns a raw initial value (from the JSON) into the value this input
  /// actually starts with.
  Object? normalizeInitialValue(Object? raw) => raw;
}
