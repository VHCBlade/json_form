import 'package:flutter_test/flutter_test.dart';
import 'package:json_form/json_form.dart';

void main() {
  group('parseCondition', () {
    for (final expected in <Object?>[true, false, 'yes', 3]) {
      test('parses an equals condition expecting $expected', () {
        final condition = parseCondition({
          'field': 'hasPet',
          'equals': expected,
        });

        expect(
          condition,
          isA<JsonFormEqualsCondition>()
              .having((c) => c.field, 'field', 'hasPet')
              .having((c) => c.expected, 'expected', expected),
        );
      });
    }

    test('ignores extra keys', () {
      final condition = parseCondition({
        'field': 'hasPet',
        'equals': true,
        'comment': 'shown only for pet owners',
      });

      expect(condition, isA<JsonFormEqualsCondition>());
    });

    test('throws a FormatException for an empty condition', () {
      expect(() => parseCondition({}), throwsFormatException);
    });

    test('throws a FormatException for an unsupported shape', () {
      expect(
        () => parseCondition({'field': 'hasPet', 'greaterThan': 1}),
        throwsFormatException,
      );
    });

    test('throws a FormatException when field is missing', () {
      expect(() => parseCondition({'equals': true}), throwsFormatException);
    });

    test('throws a FormatException when equals is missing', () {
      expect(
        () => parseCondition({'field': 'hasPet'}),
        throwsFormatException,
      );
    });

    test(
      'throws a FormatException when field is not a string',
      () {
        expect(
          () => parseCondition({'field': 3, 'equals': true}),
          throwsFormatException,
        );
      },
    );
  });
}
