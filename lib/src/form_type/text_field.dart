import 'package:flutter/material.dart';

import '../field_spec.dart';
import 'form_field.dart';

class JsonFormTextFieldInput extends JsonFormFieldInput {
  const JsonFormTextFieldInput();

  @override
  String get type => 'text';

  @override
  Object? normalizeInitialValue(Object? raw) => raw?.toString();

  @override
  Widget build(
    BuildContext context,
    FieldSpec spec, {
    required Object? initialValue,
    required void Function(dynamic value) onChanged,
    required void Function(dynamic value) onSaved,
  }) {
    return TextFormField(
      initialValue: initialValue?.toString(),
      decoration: InputDecoration(labelText: spec.label ?? spec.key),
      validator: (v) =>
          spec.required && (v == null || v.trim().isEmpty) ? 'Required' : null,
      onSaved: onSaved,
      onChanged: onChanged,
    );
  }
}
