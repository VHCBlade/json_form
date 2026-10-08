import 'package:flutter_test/flutter_test.dart';

// Replace with your package's actual name.
import 'package:json_form/json_form.dart';

void main() {
  group('JsonFormOption.fromJson', () {
    test('a string is both value and label', () {
      final option = JsonFormOption.fromJson('Small');

      expect(option.value, 'Small');
      expect(option.label, 'Small');
    });

    test('a number is the value and its string form is the label', () {
      final option = JsonFormOption.fromJson(3);

      expect(option.value, 3);
      expect(option.label, '3');
    });

    test('a map supplies value and label separately', () {
      final option = JsonFormOption.fromJson(
        <String, dynamic>{'value': 'usr', 'label': 'User'},
      );

      expect(option.value, 'usr');
      expect(option.label, 'User');
    });

    test('a map without a label uses the value as the label', () {
      final option = JsonFormOption.fromJson(
        <String, dynamic>{'value': 'usr'},
      );

      expect(option.value, 'usr');
      expect(option.label, 'usr');
    });

    test('a map with a numeric value keeps it as a number', () {
      final option = JsonFormOption.fromJson(
        <String, dynamic>{'value': 5, 'label': 'Five'},
      );

      expect(option.value, 5);
      expect(option.value, isA<int>());
      expect(option.label, 'Five');
    });

    test('a map without a label and a numeric value labels it as text', () {
      final option = JsonFormOption.fromJson(<String, dynamic>{'value': 5});

      expect(option.label, '5');
    });

    test(
      'a map without a value throws a FormatException',
      () {
        expect(
          () => JsonFormOption.fromJson(<String, dynamic>{'label': 'User'}),
          throwsFormatException,
        );
      },
    );
  });
}
