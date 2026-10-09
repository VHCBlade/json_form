import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:json_form/json_form.dart';

import '../../helpers/form_test_helpers.dart';

/// A source that records whether anything tried to load it.
class _CountingSource extends JsonFormOptionsSource {
  _CountingSource();

  int loads = 0;

  @override
  Future<List<JsonFormOption>> load(FieldSpec spec) {
    loads++;
    return Future.value(const []);
  }
}

/// An input that records which fields it was asked to validate.
class _RecordingInput extends JsonFormFieldInput {
  _RecordingInput(this.type, {this.failWith});

  @override
  final String type;
  final String? failWith;
  final List<String> validated = [];

  @override
  void validate(FieldSpec spec) {
    validated.add(spec.key);
    if (failWith != null) throw FormatException(failWith!);
  }

  @override
  Widget build(
    BuildContext context,
    FieldSpec spec, {
    required Object? initialValue,
    required void Function(dynamic value) onChanged,
    required void Function(dynamic value) onSaved,
  }) =>
      const SizedBox();
}

/// Schemas the form can build, none needing a custom input or source.
final Map<String, Map<String, dynamic>> _valid = {
  'every built-in type': formSchema([
    textSpec('name', required: true),
    dropdownSpec('size', options: ['S', 'M', 'L']),
    checkboxSpec('terms'),
    integerSpec('age', min: 0, max: 120),
  ]),
  'an empty field list': formSchema([]),
  'map-style dropdown options': formSchema([
    dropdownSpec('role', options: [
      {'value': 'adm', 'label': 'Administrator'},
    ]),
  ]),
  'conditions on earlier fields': formSchema([
    checkboxSpec('hasPet'),
    textSpec('petName', visibleWhen: when('hasPet', true)),
    textSpec('wantsPet', visibleWhen: when('hasPet', false)),
  ]),
  'nested groups with conditions': formSchema([
    checkboxSpec('hasPet'),
    groupSpec(
      'pet',
      [
        textSpec('petName'),
        groupSpec('medical', [
          checkboxSpec('insured'),
          textSpec('insurer', visibleWhen: when('insured', true)),
        ]),
      ],
      visibleWhen: when('hasPet', true),
    ),
  ]),
  'whole-valued double bounds': formSchema([
    {'key': 'n', 'type': 'integer', 'min': 1.0, 'max': 5.0},
  ]),
};

/// Schemas that must be rejected, with the message each should produce.
final Map<String, ({Map<String, dynamic> schema, String message})> _invalid = {
  'a missing fields list': (
    schema: {'form': []},
    message: 'Schema needs a "fields" list',
  ),
  'a fields value that is not a list': (
    schema: {'fields': 'nope'},
    message: 'Schema needs a "fields" list',
  ),
  'a field that is not an object': (
    schema: {
      'fields': ['text'],
    },
    message: 'Each field must be a JSON object',
  ),
  'duplicate keys': (
    schema:
        formSchema([textSpec('email'), textSpec('name'), textSpec('email')]),
    message: 'Duplicate key: "email"',
  ),
  'a field reusing a group key': (
    schema: formSchema([
      groupSpec('pet', [textSpec('petName')]),
      textSpec('pet'),
    ]),
    message: 'Duplicate key: "pet"',
  ),
  'a condition on a later field': (
    schema: formSchema([
      textSpec('details', visibleWhen: when('hasDetails', true)),
      checkboxSpec('hasDetails'),
    ]),
    message: '"details" is conditional on hasDetails, '
        'which must be declared earlier',
  ),
  'a condition on an unknown field': (
    schema: formSchema([
      textSpec('details', visibleWhen: when('nowhere', true)),
    ]),
    message: 'must be declared earlier',
  ),
  'an unsupported condition': (
    schema: formSchema([
      checkboxSpec('a'),
      textSpec('b', visibleWhen: {'field': 'a', 'greaterThan': 1}),
    ]),
    message: 'Unsupported condition',
  ),
  'an empty group': (
    schema: formSchema([groupSpec('address', [])]),
    message: 'Group "address" has no "fields"',
  ),
  'a group without a fields list': (
    schema: {
      'fields': [
        {'key': 'g', 'type': 'group'},
      ],
    },
    message: 'Group "g" has no "fields"',
  ),
  'an unknown field type': (
    schema: {
      'fields': [
        {'key': 'volume', 'type': 'slider'},
      ],
    },
    message: 'No input registered for type: slider',
  ),
  'an unknown options source': (
    schema: formSchema([dropdownSpec('planet', optionsSource: 'planets')]),
    message: 'Unknown options source: planets',
  ),
  'a dropdown without options': (
    schema: formSchema([dropdownSpec('size')]),
    message: 'Dropdown "size" needs "options" or "optionsSource"',
  ),
  'a dropdown whose options are not a list': (
    schema: {
      'fields': [
        {'key': 'size', 'type': 'dropdown', 'options': 'S,M,L'},
      ],
    },
    message: 'needs "options" or "optionsSource"',
  ),
  'an integer with min above max': (
    schema: formSchema([integerSpec('age', min: 50, max: 10)]),
    message: '"age" has min 50 greater than max 10',
  ),
  'an integer bound that is not whole': (
    schema: {
      'fields': [
        {'key': 'age', 'type': 'integer', 'min': 1.5},
      ],
    },
    message: 'must be a whole number',
  ),
};

void main() {
  group('JsonForm.validateSchema accepts', () {
    _valid.forEach((name, schema) {
      test(name, () {
        expect(() => JsonForm.validateSchema(schema), returnsNormally);
      });
    });
  });

  group('JsonForm.validateSchema rejects', () {
    _invalid.forEach((name, rejected) {
      test('$name with a FormatException', () {
        expect(
          () => JsonForm.validateSchema(rejected.schema),
          throwsA(formatExceptionWith(rejected.message)),
        );
      });
    });

    test(
      'a label of the wrong type with a FormatException',
      () {
        expect(
          () => JsonForm.validateSchema(
            formSchema([
              {'key': 'a', 'type': 'text', 'label': 42},
            ]),
          ),
          throwsFormatException,
        );
      },
    );
  });

  group('JsonForm.validateSchema and inputs', () {
    final shout = formSchema([
      {'key': 'code', 'type': 'shout'},
    ]);

    test('a custom type fails with the default inputs', () {
      expect(
        () => JsonForm.validateSchema(shout),
        throwsA(formatExceptionWith('No input registered for type: shout')),
      );
    });

    test('a custom type passes once its input is supplied', () {
      expect(
        () => JsonForm.validateSchema(
          shout,
          inputs: [...JsonForm.defaultInputs, _RecordingInput('shout')],
        ),
        returnsNormally,
      );
    });

    test('supplying inputs replaces the defaults', () {
      expect(
        () => JsonForm.validateSchema(
          formSchema([textSpec('name')]),
          inputs: const [],
        ),
        throwsA(formatExceptionWith('No input registered for type: text')),
      );
    });

    test('an empty field list needs no inputs at all', () {
      expect(
        () => JsonForm.validateSchema(formSchema([]), inputs: const []),
        returnsNormally,
      );
    });

    test('a known source passes where an unknown one failed', () {
      final schema = formSchema([
        dropdownSpec('country', optionsSource: 'countries'),
      ]);

      expect(
        () => JsonForm.validateSchema(schema),
        throwsA(formatExceptionWith('Unknown options source: countries')),
      );
      expect(
        () => JsonForm.validateSchema(
          schema,
          inputs: [
            ...JsonForm.defaultInputs,
            JsonFormDropdownFieldInput(
                sources: {'countries': _CountingSource()}),
          ],
        ),
        returnsNormally,
      );
    });

    test('it does not load any options', () {
      final source = _CountingSource();

      JsonForm.validateSchema(
        formSchema([dropdownSpec('country', optionsSource: 'countries')]),
        inputs: [
          ...JsonForm.defaultInputs,
          JsonFormDropdownFieldInput(sources: {'countries': source}),
        ],
      );

      expect(source.loads, 0);
    });

    test('it does not modify the schema', () {
      final schema = formSchema([
        checkboxSpec('hasPet'),
        groupSpec(
          'pet',
          [textSpec('petName'), integerSpec('age', min: 0, max: 40)],
          visibleWhen: when('hasPet', true),
        ),
      ]);
      final before = jsonEncode(schema);

      JsonForm.validateSchema(schema);

      expect(jsonEncode(schema), before);
    });
  });

  group('JsonFormFieldInput.validate', () {
    FieldSpec spec(Map<String, dynamic> json) => FieldSpec.fromJson(json);

    test('accepts everything by default', () {
      final custom = _RecordingInput('x');

      expect(
        () => const JsonFormTextFieldInput()
            .validate(spec({'key': 'a', 'type': 'text'})),
        returnsNormally,
      );
      expect(
        () => const JsonFormCheckboxFieldInput()
            .validate(spec({'key': 'a', 'type': 'checkbox'})),
        returnsNormally,
      );
      expect(custom.validated, isEmpty);
    });

    test('is called once per field, in order, and never for groups', () {
      final recorder = _RecordingInput('rec');

      JsonForm.validateSchema(
        formSchema([
          {'key': 'one', 'type': 'rec'},
          groupSpec('box', [
            {'key': 'two', 'type': 'rec'},
          ]),
          {'key': 'three', 'type': 'rec'},
        ]),
        inputs: [recorder],
      );

      expect(recorder.validated, ['one', 'two', 'three']);
    });

    test('is only called on the input that owns the type', () {
      final recorder = _RecordingInput('rec');

      JsonForm.validateSchema(
        formSchema([
          textSpec('name'),
          {'key': 'x', 'type': 'rec'},
        ]),
        inputs: [...JsonForm.defaultInputs, recorder],
      );

      expect(recorder.validated, ['x']);
    });

    test('an exception from it reaches the caller unchanged', () {
      expect(
        () => JsonForm.validateSchema(
          formSchema([
            {'key': 'x', 'type': 'rec'},
          ]),
          inputs: [_RecordingInput('rec', failWith: 'boom')],
        ),
        throwsA(formatExceptionWith('boom')),
      );
    });

    group('dropdown', () {
      const dropdown = JsonFormDropdownFieldInput();

      test('accepts inline options', () {
        expect(
          () => dropdown.validate(spec({
            'key': 'd',
            'type': 'dropdown',
            'options': ['a', 'b'],
          })),
          returnsNormally,
        );
      });

      test('accepts a registered source', () {
        final withSource = JsonFormDropdownFieldInput(
          sources: {'countries': _CountingSource()},
        );

        expect(
          () => withSource.validate(spec({
            'key': 'd',
            'type': 'dropdown',
            'optionsSource': 'countries',
          })),
          returnsNormally,
        );
      });

      test('rejects an unregistered source', () {
        expect(
          () => dropdown.validate(spec({
            'key': 'd',
            'type': 'dropdown',
            'optionsSource': 'nope',
          })),
          throwsA(formatExceptionWith('Unknown options source: nope')),
        );
      });

      test('rejects a spec with neither options nor a source', () {
        expect(
          () => dropdown.validate(spec({'key': 'd', 'type': 'dropdown'})),
          throwsA(formatExceptionWith('needs "options" or "optionsSource"')),
        );
      });

      test('a source takes precedence over inline options', () {
        expect(
          () => dropdown.validate(spec({
            'key': 'd',
            'type': 'dropdown',
            'options': ['a'],
            'optionsSource': 'nope',
          })),
          throwsA(formatExceptionWith('Unknown options source: nope')),
        );
      });
    });
  });

  group('validateSchema and the form agree', () {
    _valid.forEach((name, schema) {
      testWidgets('the form builds $name', (tester) async {
        await pumpForm(tester, schema: schema);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });

    _invalid.forEach((name, rejected) {
      testWidgets('the form fails to build $name, with the same message',
          (tester) async {
        await pumpForm(tester, schema: rejected.schema);

        expect(
          tester.takeException(),
          formatExceptionWith(rejected.message),
        );
      });
    });
  });
}
