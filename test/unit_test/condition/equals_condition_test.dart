import 'package:flutter_test/flutter_test.dart';
import 'package:json_form/json_form.dart';

void main() {
  group('JsonFormEqualsCondition', () {
    test('fields contains only the watched key', () {
      const condition =
          JsonFormEqualsCondition(field: 'hasPet', expected: true);

      expect(condition.fields, {'hasPet'});
    });

    test('ignores keys other than the watched one', () {
      const condition = JsonFormEqualsCondition(field: 'k', expected: true);

      expect(condition.isMet({'other': true}), isFalse);
    });

    group('expecting true', () {
      const condition = JsonFormEqualsCondition(field: 'k', expected: true);

      test('is met by true', () {
        expect(condition.isMet({'k': true}), isTrue);
      });

      test('is not met by false', () {
        expect(condition.isMet({'k': false}), isFalse);
      });

      test('is not met by null', () {
        expect(condition.isMet({'k': null}), isFalse);
      });

      test('is not met by an absent key', () {
        expect(condition.isMet({}), isFalse);
      });

      test('is not met by the string "true"', () {
        expect(condition.isMet({'k': 'true'}), isFalse);
      });

      test('is not met by 1', () {
        expect(condition.isMet({'k': 1}), isFalse);
      });
    });

    group('expecting false', () {
      const condition = JsonFormEqualsCondition(field: 'k', expected: false);

      test('is met by false', () {
        expect(condition.isMet({'k': false}), isTrue);
      });

      test('is not met by true', () {
        expect(condition.isMet({'k': true}), isFalse);
      });

      test('is not met by null', () {
        expect(condition.isMet({'k': null}), isFalse);
      });

      // JsonForm relies on this: a hidden field is absent from the values
      // conditions see, so "equals: false" must not match it, or hiding a
      // parent would reveal the fields that wait for it to be unchecked.
      test('is not met by an absent key', () {
        expect(condition.isMet({}), isFalse);
      });

      test('is not met by the string "false"', () {
        expect(condition.isMet({'k': 'false'}), isFalse);
      });

      test('is not met by 0', () {
        expect(condition.isMet({'k': 0}), isFalse);
      });
    });

    group('other expected values', () {
      test('matches an equal string', () {
        const condition =
            JsonFormEqualsCondition(field: 'plan', expected: 'Team');

        expect(condition.isMet({'plan': 'Team'}), isTrue);
        expect(condition.isMet({'plan': 'team'}), isFalse);
      });

      test('a string does not match a number', () {
        const condition = JsonFormEqualsCondition(field: 'k', expected: 1);

        expect(condition.isMet({'k': '1'}), isFalse);
      });

      // Dart's == treats 1 and 1.0 as equal, so a number that went through
      // a JSON round trip still matches.
      test('an int matches the equal double', () {
        const condition = JsonFormEqualsCondition(field: 'k', expected: 1);

        expect(condition.isMet({'k': 1.0}), isTrue);
      });

      test('expecting null is met by null and by an absent key', () {
        const condition = JsonFormEqualsCondition(field: 'k', expected: null);

        expect(condition.isMet({'k': null}), isTrue);
        expect(condition.isMet({}), isTrue);
        expect(condition.isMet({'k': ''}), isFalse);
      });

      // Equality is Dart's ==, which compares collections by identity, so an
      // expected list or map can never match a separately built one.
      test('collections are not compared by content', () {
        final condition = JsonFormEqualsCondition(field: 'k', expected: [1]);

        expect(
            condition.isMet({
              'k': [1]
            }),
            isFalse);
      });
    });
  });
}
