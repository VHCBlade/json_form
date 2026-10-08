import 'package:flutter_test/flutter_test.dart';

import 'package:json_form/json_form.dart';

void main() {
  group('type', () {
    test('each built-in input handles its own schema type', () {
      expect(const JsonFormTextFieldInput().type, 'text');
      expect(const JsonFormDropdownFieldInput().type, 'dropdown');
      expect(const JsonFormCheckboxFieldInput().type, 'checkbox');
    });

    test('the default inputs have distinct types', () {
      final types = JsonForm.defaultInputs.map((i) => i.type).toList();

      expect(types.toSet().length, types.length);
    });
  });

  group('JsonFormTextFieldInput.normalizeInitialValue', () {
    const input = JsonFormTextFieldInput();

    test('passes null through', () {
      expect(input.normalizeInitialValue(null), isNull);
    });

    test('keeps a string unchanged', () {
      expect(input.normalizeInitialValue('Ada'), 'Ada');
      expect(input.normalizeInitialValue(''), '');
    });

    test('stringifies other values', () {
      expect(input.normalizeInitialValue(5), '5');
      expect(input.normalizeInitialValue(true), 'true');
    });
  });

  group('JsonFormCheckboxFieldInput.normalizeInitialValue', () {
    const input = JsonFormCheckboxFieldInput();

    test('keeps true and false', () {
      expect(input.normalizeInitialValue(true), isTrue);
      expect(input.normalizeInitialValue(false), isFalse);
    });

    test('an absent value becomes false', () {
      expect(input.normalizeInitialValue(null), isFalse);
    });

    test('non-boolean values become false rather than being coerced', () {
      expect(input.normalizeInitialValue('true'), isFalse);
      expect(input.normalizeInitialValue(1), isFalse);
    });
  });

  group('JsonFormDropdownFieldInput.normalizeInitialValue', () {
    const input = JsonFormDropdownFieldInput();

    test('passes the raw value through unchanged', () {
      expect(input.normalizeInitialValue('Medium'), 'Medium');
      expect(input.normalizeInitialValue(3), 3);
      expect(input.normalizeInitialValue(null), isNull);
    });
  });
}
