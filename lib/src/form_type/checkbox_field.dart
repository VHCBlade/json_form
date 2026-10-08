import 'package:flutter/material.dart';

import '../field_spec.dart';
import 'form_field.dart';

class JsonFormCheckboxFieldInput extends JsonFormFieldInput {
  const JsonFormCheckboxFieldInput();

  @override
  String get type => 'checkbox';

  @override
  Object? normalizeInitialValue(Object? raw) => raw is bool ? raw : false;

  @override
  Widget build(
    BuildContext context,
    FieldSpec spec, {
    required Object? initialValue,
    required void Function(dynamic value) onChanged,
    required void Function(dynamic value) onSaved,
  }) {
    return FormField<bool>(
      initialValue: initialValue is bool ? initialValue : false,
      validator: (v) => spec.required && v != true ? 'Required' : null,
      onSaved: onSaved,
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: state.value ?? false,
              onChanged: (x) {
                state.didChange(x);
                onChanged(x);
              },
              title: Text(spec.label ?? spec.key),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (state.hasError)
              Text(
                state.errorText!,
                style: TextStyle(
                  color: Theme.of(state.context).colorScheme.error,
                ),
              ),
          ],
        );
      },
    );
  }
}
