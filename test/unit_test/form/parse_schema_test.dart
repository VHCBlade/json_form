import 'package:flutter_test/flutter_test.dart';

import 'package:json_form/json_form.dart';

final List<JsonFormFieldInput> _inputs = [
  ...JsonForm.defaultInputs,
];

Matcher _formatExceptionWith(String part) =>
    isA<FormatException>().having((e) => e.message, 'message', contains(part));

Map<String, dynamic> parseSchema(String text, List<JsonFormFieldInput> inputs) {
  return JsonSchemaParser.parseSchema(text, inputs);
}

void main() {
  group('parseSchema', () {
    test('returns the decoded schema when it is valid', () {
      final schema = parseSchema(
        '{"fields": [{"key": "a", "type": "text"}]}',
        _inputs,
      );

      expect(schema['fields'], hasLength(1));
    });

    test('accepts surrounding whitespace', () {
      expect(
        () => parseSchema('\n  {"fields": []}  \n', _inputs),
        returnsNormally,
      );
    });

    test('rejects text that is not JSON', () {
      expect(
        () => parseSchema('{"fields": [,]}', _inputs),
        throwsA(_formatExceptionWith('Not valid JSON')),
      );
    });

    test('rejects empty text', () {
      expect(
        () => parseSchema('', _inputs),
        throwsA(_formatExceptionWith('Not valid JSON')),
      );
    });

    test('rejects JSON that is not an object', () {
      for (final text in ['[]', '42', '"text"', 'null', 'true']) {
        expect(
          () => parseSchema(text, _inputs),
          throwsA(_formatExceptionWith('top level must be a JSON object')),
          reason: text,
        );
      }
    });

    test('rejects an object with no fields list', () {
      expect(
        () => parseSchema('{"form": []}', _inputs),
        throwsA(_formatExceptionWith('Schema needs a "fields" list')),
      );
    });

    test('passes the schema checks through, message intact', () {
      expect(
        () => parseSchema(
          '{"fields": [{"key": "a", "type": "text"}, '
          '{"key": "a", "type": "text"}]}',
          _inputs,
        ),
        throwsA(_formatExceptionWith('Duplicate key: "a"')),
      );
    });

    test('turns a wrong-typed value into a FormatException', () {
      expect(
        () => parseSchema(
          '{"fields": [{"key": "a", "type": "text", "label": 42}]}',
          _inputs,
        ),
        throwsFormatException,
      );
    });
  });
}
