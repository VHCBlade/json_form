import 'package:flutter_test/flutter_test.dart';

import 'package:json_form/json_form.dart';

import '../helpers/form_test_helpers.dart';

/// A group with one child, with [extra] merged over it.
FieldSpec _group([Map<String, dynamic> extra = const {}]) =>
    FieldSpec.fromJson({
      'key': 'g',
      'type': 'group',
      'fields': [
        {'key': 'a', 'type': 'text'},
      ],
      ...extra,
    });

FieldSpec _list([Map<String, dynamic> extra = const {}]) =>
    _group({'output': 'list', ...extra});

void main() {
  group('FieldSpec output', () {
    test('defaults to flat', () {
      expect(_group().output, GroupOutput.flat);
    });

    for (final output in GroupOutput.values) {
      test('parses "${output.name}"', () {
        expect(_group({'output': output.name}).output, output);
      });
    }

    test('a null output counts as absent', () {
      expect(_group({'output': null}).output, GroupOutput.flat);
    });

    test('an unknown value is a FormatException', () {
      expect(
        () => _group({'output': 'tree'}),
        throwsA(formatExceptionWith(
          '"output" of group "g" must be "flat", "object" or "list": tree',
        )),
      );
    });

    test('a value that is not a string is a FormatException', () {
      expect(
        () => _group({'output': 3}),
        throwsA(formatExceptionWith('must be "flat", "object" or "list": 3')),
      );
    });

    test('the names are case sensitive', () {
      expect(() => _group({'output': 'List'}), throwsFormatException);
    });

    test('is flat, and never checked, on a field that is not a group', () {
      final spec = FieldSpec.fromJson(
        {'key': 'a', 'type': 'text', 'output': 'tree'},
      );

      expect(spec.output, GroupOutput.flat);
    });
  });

  group('FieldSpec list options', () {
    test('default to no bounds and no label', () {
      final spec = _list();

      expect(spec.minItems, 0);
      expect(spec.maxItems, isNull);
      expect(spec.addLabel, isNull);
    });

    test('are parsed', () {
      final spec = _list(
        {'minItems': 1, 'maxItems': 5, 'addLabel': 'Add a pet'},
      );

      expect(spec.minItems, 1);
      expect(spec.maxItems, 5);
      expect(spec.addLabel, 'Add a pet');
    });

    test('accept whole-valued doubles', () {
      final spec = _list({'minItems': 1.0, 'maxItems': 3.0});

      expect(spec.minItems, 1);
      expect(spec.maxItems, 3);
      expect(spec.minItems, isA<int>());
    });

    test('explicit nulls count as absent', () {
      final spec =
          _list({'minItems': null, 'maxItems': null, 'addLabel': null});

      expect(spec.minItems, 0);
      expect(spec.maxItems, isNull);
      expect(spec.addLabel, isNull);
    });

    test('allow equal bounds', () {
      final spec = _list({'minItems': 2, 'maxItems': 2});

      expect(spec.minItems, 2);
      expect(spec.maxItems, 2);
    });

    test('allow a minimum of zero and a maximum of one', () {
      final spec = _list({'minItems': 0, 'maxItems': 1});

      expect(spec.minItems, 0);
      expect(spec.maxItems, 1);
    });

    test('reject a negative minimum', () {
      expect(
        () => _list({'minItems': -1}),
        throwsA(formatExceptionWith(
          '"minItems" of group "g" must be a whole number of at least 0: -1',
        )),
      );
    });

    test('reject a maximum of zero', () {
      expect(
        () => _list({'maxItems': 0}),
        throwsA(formatExceptionWith(
          '"maxItems" of group "g" must be a whole number of at least 1: 0',
        )),
      );
    });

    test('reject fractional values', () {
      expect(() => _list({'minItems': 1.5}), throwsFormatException);
      expect(() => _list({'maxItems': 2.5}), throwsFormatException);
    });

    test('reject values that are not numbers', () {
      expect(() => _list({'minItems': '1'}), throwsFormatException);
      expect(() => _list({'maxItems': true}), throwsFormatException);
    });

    test('reject a minimum above the maximum', () {
      expect(
        () => _list({'minItems': 5, 'maxItems': 2}),
        throwsA(formatExceptionWith(
          'Group "g" has minItems 5 greater than maxItems 2',
        )),
      );
    });

    test('reject an add label that is not a string', () {
      expect(
        () => _list({'addLabel': 5}),
        throwsA(formatExceptionWith(
          '"addLabel" of group "g" must be a string: 5',
        )),
      );
    });

    for (final output in ['object', 'flat']) {
      test('are ignored, even when invalid, on a $output group', () {
        final spec = _group({
          'output': output,
          'minItems': -5,
          'maxItems': 0,
          'addLabel': 5,
        });

        expect(spec.minItems, 0);
        expect(spec.maxItems, isNull);
        expect(spec.addLabel, isNull);
      });
    }

    test('are ignored on a field that is not a group', () {
      final spec = FieldSpec.fromJson({
        'key': 'a',
        'type': 'text',
        'output': 'list',
        'minItems': 3,
        'addLabel': 'Add',
      });

      expect(spec.minItems, 0);
      expect(spec.addLabel, isNull);
    });
  });

  group('FieldSpec children', () {
    test('are parsed for a group, whatever its output', () {
      for (final output in GroupOutput.values) {
        expect(_group({'output': output.name}).children.single.key, 'a');
      }
    });

    test('are not parsed for a field that is not a group', () {
      final spec = FieldSpec.fromJson({
        'key': 'a',
        'type': 'text',
        'fields': [
          {'key': 'b', 'type': 'text'},
        ],
      });

      expect(spec.children, isEmpty);
    });

    test('a group without fields has none', () {
      expect(
        FieldSpec.fromJson({'key': 'g', 'type': 'group'}).children,
        isEmpty,
      );
    });

    test('fields that is not a list is a FormatException', () {
      expect(
        () => FieldSpec.fromJson({'key': 'g', 'type': 'group', 'fields': 'x'}),
        throwsA(formatExceptionWith('"fields" must be a list')),
      );
    });

    test('a child that is not an object is a FormatException', () {
      expect(
        () => FieldSpec.fromJson({
          'key': 'g',
          'type': 'group',
          'fields': ['text'],
        }),
        throwsA(formatExceptionWith('Each field must be a JSON object')),
      );
    });

    test('nest through groups of different outputs', () {
      final spec = FieldSpec.fromJson({
        'key': 'outer',
        'type': 'group',
        'output': 'object',
        'fields': [
          {
            'key': 'inner',
            'type': 'group',
            'output': 'list',
            'fields': [
              {'key': 'leaf', 'type': 'text'},
            ],
          },
        ],
      });

      final inner = spec.children.single;
      expect(spec.output, GroupOutput.object);
      expect(inner.output, GroupOutput.list);
      expect(inner.children.single.key, 'leaf');
    });
  });

  group('FieldSpec type checks', () {
    FieldSpec text(Map<String, dynamic> extra) =>
        FieldSpec.fromJson({'key': 'a', 'type': 'text', ...extra});

    test('a label must be a string', () {
      expect(
        () => text({'label': 42}),
        throwsA(formatExceptionWith('"label" of "a" must be a string: 42')),
      );
    });

    test('required must be a boolean', () {
      expect(
        () => text({'required': 'yes'}),
        throwsA(formatExceptionWith(
          '"required" of "a" must be true or false: yes',
        )),
      );
    });

    test('a null label or required counts as absent', () {
      final spec = text({'label': null, 'required': null});

      expect(spec.label, isNull);
      expect(spec.required, isFalse);
    });

    test('a valid label and required are kept', () {
      final spec = text({'label': 'Name', 'required': true});

      expect(spec.label, 'Name');
      expect(spec.required, isTrue);
    });
  });
}
