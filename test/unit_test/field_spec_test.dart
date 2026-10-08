import 'package:flutter_test/flutter_test.dart';
import 'package:json_form/json_form.dart';

/// A minimal valid field, with [extra] merged over it.
Map<String, dynamic> _field([Map<String, dynamic> extra = const {}]) => {
      'key': 'name',
      'type': 'text',
      ...extra,
    };

void main() {
  group('FieldSpec constructor', () {
    test('applies defaults for optional arguments', () {
      const spec = FieldSpec(key: 'name', type: 'text');

      expect(spec.label, isNull);
      expect(spec.required, isFalse);
      expect(spec.raw, isEmpty);
      expect(spec.visibleWhen, isNull);
      expect(spec.children, isEmpty);
    });
  });

  group('FieldSpec.fromJson', () {
    test('parses a minimal field', () {
      final spec = FieldSpec.fromJson(_field());

      expect(spec.key, 'name');
      expect(spec.type, 'text');
      expect(spec.label, isNull);
      expect(spec.required, isFalse);
      expect(spec.visibleWhen, isNull);
      expect(spec.children, isEmpty);
    });

    test('parses label and required', () {
      final spec = FieldSpec.fromJson(
        _field({'label': 'Full name', 'required': true}),
      );

      expect(spec.label, 'Full name');
      expect(spec.required, isTrue);
    });

    test('required defaults to false when absent', () {
      expect(FieldSpec.fromJson(_field()).required, isFalse);
    });

    test('keeps the original JSON in raw, including unknown keys', () {
      final json = _field({
        'options': ['a', 'b'],
        'somethingCustom': 42,
      });

      final spec = FieldSpec.fromJson(json);

      expect(spec.raw, same(json));
      expect(spec.raw['options'], ['a', 'b']);
      expect(spec.raw['somethingCustom'], 42);
    });

    test('throws a FormatException when key is missing', () {
      final json = _field()..remove('key');

      expect(() => FieldSpec.fromJson(json), throwsFormatException);
    });

    test('throws a FormatException when type is missing', () {
      final json = _field()..remove('type');

      expect(() => FieldSpec.fromJson(json), throwsFormatException);
    });

    test('throws a FormatException when key is not a string', () {
      expect(
        () => FieldSpec.fromJson(_field({'key': 7})),
        throwsFormatException,
      );
    });
  });

  group('FieldSpec visibleWhen', () {
    test('is null when the schema has no condition', () {
      expect(FieldSpec.fromJson(_field()).visibleWhen, isNull);
    });

    for (final expected in <Object?>[true, false, 'yes', 3]) {
      test('parses an equals condition expecting $expected', () {
        final spec = FieldSpec.fromJson(
          _field({
            'visibleWhen': {'field': 'hasPet', 'equals': expected},
          }),
        );

        expect(
          spec.visibleWhen,
          isA<JsonFormEqualsCondition>()
              .having((c) => c.field, 'field', 'hasPet')
              .having((c) => c.expected, 'expected', expected),
        );
      });
    }

    test('throws a FormatException for an unsupported condition', () {
      expect(
        () => FieldSpec.fromJson(
          _field({
            'visibleWhen': {'field': 'hasPet', 'greaterThan': 1},
          }),
        ),
        throwsFormatException,
      );
    });

    test('throws a FormatException when equals has no field', () {
      expect(
        () => FieldSpec.fromJson(
          _field({
            'visibleWhen': {'equals': true},
          }),
        ),
        throwsFormatException,
      );
    });
  });

  group('FieldSpec groups', () {
    test('groupType is "group"', () {
      expect(FieldSpec.groupType, 'group');
    });

    test('isGroup is true only for the group type', () {
      expect(FieldSpec.fromJson(_field({'type': 'group'})).isGroup, isTrue);
      expect(FieldSpec.fromJson(_field()).isGroup, isFalse);
      expect(
        FieldSpec.fromJson(_field({'type': 'checkbox'})).isGroup,
        isFalse,
      );
    });

    test('parses children in declaration order', () {
      final spec = FieldSpec.fromJson({
        'key': 'pet',
        'type': 'group',
        'fields': [
          {'key': 'petName', 'type': 'text'},
          {'key': 'petAge', 'type': 'text'},
          {'key': 'petInsured', 'type': 'checkbox'},
        ],
      });

      expect(spec.isGroup, isTrue);
      expect(
        spec.children.map((c) => c.key),
        ['petName', 'petAge', 'petInsured'],
      );
      expect(
        spec.children.map((c) => c.type),
        ['text', 'text', 'checkbox'],
      );
    });

    test('parses nested groups', () {
      final spec = FieldSpec.fromJson({
        'key': 'outer',
        'type': 'group',
        'fields': [
          {
            'key': 'inner',
            'type': 'group',
            'fields': [
              {'key': 'leaf', 'type': 'text'},
            ],
          },
        ],
      });

      final inner = spec.children.single;
      expect(inner.key, 'inner');
      expect(inner.isGroup, isTrue);
      expect(inner.children.single.key, 'leaf');
      expect(inner.children.single.isGroup, isFalse);
    });

    test('children keep their own conditions', () {
      final spec = FieldSpec.fromJson({
        'key': 'pet',
        'type': 'group',
        'fields': [
          {
            'key': 'insurer',
            'type': 'text',
            'visibleWhen': {'field': 'petInsured', 'equals': true},
          },
        ],
      });

      expect(
        spec.children.single.visibleWhen,
        isA<JsonFormEqualsCondition>()
            .having((c) => c.field, 'field', 'petInsured'),
      );
    });

    test('a group can carry its own condition', () {
      final spec = FieldSpec.fromJson({
        'key': 'pet',
        'type': 'group',
        'visibleWhen': {'field': 'hasPet', 'equals': true},
        'fields': [
          {'key': 'petName', 'type': 'text'},
        ],
      });

      expect(spec.visibleWhen, isA<JsonFormEqualsCondition>());
    });

    test('a field without "fields" has no children', () {
      expect(FieldSpec.fromJson(_field()).children, isEmpty);
    });

    test('parsing an empty group is lenient; JsonForm rejects it', () {
      final spec = FieldSpec.fromJson({'key': 'pet', 'type': 'group'});

      expect(spec.isGroup, isTrue);
      expect(spec.children, isEmpty);
    });

    test('a child missing its key fails the whole parse', () {
      expect(
        () => FieldSpec.fromJson({
          'key': 'pet',
          'type': 'group',
          'fields': [
            {'type': 'text'},
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
