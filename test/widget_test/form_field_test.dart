import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:json_form/json_form.dart';

import '../helpers/form_test_helpers.dart';

void main() {
  group('rendering and submit', () {
    testWidgets('renders a field per spec, using the label or the key',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          {'key': 'name', 'type': 'text', 'label': 'Full name'},
          {'key': 'email', 'type': 'text'},
        ]),
      );

      expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'email'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('submits what was entered', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name'), textSpec('notes')]),
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(textField('name'), 'Ada');
      await submit(tester);

      expect(submitted, {'name': 'Ada', 'notes': ''});
    });

    testWidgets('the submitted map is unmodifiable', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name')]),
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(() => submitted!['other'] = 1, throwsUnsupportedError);
    });

    testWidgets('a required text field blocks submit and shows an error',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name', required: true)]),
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, isNull);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('whitespace does not satisfy a required text field',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name', required: true)]),
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(textField('name'), '   ');
      await submit(tester);

      expect(submitted, isNull);
    });

    testWidgets('a required text field submits once filled', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name', required: true)]),
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(textField('name'), 'Ada');
      await submit(tester);

      expect(submitted, {'name': 'Ada'});
    });

    testWidgets('an untouched checkbox submits false, a ticked one true',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([checkboxSpec('terms')]),
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);
      expect(submitted, {'terms': false});

      await toggle(tester, 'terms');
      await submit(tester);
      expect(submitted, {'terms': true});
    });

    testWidgets('a required checkbox must be ticked', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([checkboxSpec('terms', required: true)]),
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);
      expect(submitted, isNull);
      expect(find.text('Required'), findsOneWidget);

      await toggle(tester, 'terms');
      await submit(tester);
      expect(submitted, {'terms': true});
    });
  });

  group('schema errors', () {
    testWidgets('duplicate keys', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name'), textSpec('name')]),
      );

      expect(tester.takeException(), formatExceptionWith('Duplicate key'));
    });

    testWidgets('a field cannot reuse a group key', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec('pet', [textSpec('petName')]),
          textSpec('pet'),
        ]),
      );

      expect(tester.takeException(), formatExceptionWith('Duplicate key'));
    });

    testWidgets('a condition on a field declared later', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          textSpec('b', visibleWhen: when('a', true)),
          checkboxSpec('a'),
        ]),
      );

      expect(
        tester.takeException(),
        formatExceptionWith('must be declared earlier'),
      );
    });

    testWidgets('a condition on an unknown field', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          textSpec('b', visibleWhen: when('nowhere', true)),
        ]),
      );

      expect(
        tester.takeException(),
        formatExceptionWith('must be declared earlier'),
      );
    });

    testWidgets('an empty group', (tester) async {
      await pumpForm(tester, schema: formSchema([groupSpec('g', [])]));

      expect(tester.takeException(), formatExceptionWith('has no "fields"'));
    });

    testWidgets('an unknown field type', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          {'key': 'x', 'type': 'nope'},
        ]),
      );

      expect(
        tester.takeException(),
        formatExceptionWith('No input registered for type: nope'),
      );
    });

    testWidgets('passing inputs replaces the defaults, it does not extend them',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name')]),
        inputs: const [],
      );

      expect(
        tester.takeException(),
        formatExceptionWith('No input registered for type: text'),
      );
    });
  });

  group('initialValues', () {
    testWidgets('prefills from a decoded object', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name'), checkboxSpec('terms')]),
        initialValues: {'name': 'Ada', 'terms': true},
      );

      expect(find.text('Ada'), findsOneWidget);
      expect(isChecked(tester, 'terms'), isTrue);
    });

    testWidgets('prefills from a JSON string', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name'), checkboxSpec('terms')]),
        initialValues: '{"name": "Ada", "terms": true}',
      );

      expect(find.text('Ada'), findsOneWidget);
      expect(isChecked(tester, 'terms'), isTrue);
    });

    testWidgets('a submitted result can be fed straight back in',
        (tester) async {
      Map<String, dynamic>? submitted;
      final schema = formSchema([textSpec('name'), checkboxSpec('terms')]);
      await pumpForm(
        tester,
        schema: schema,
        initialValues: {'name': 'Ada', 'terms': true},
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {'name': 'Ada', 'terms': true});
    });

    testWidgets('keys that match no field are ignored and not output',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name')]),
        initialValues: {'name': 'Ada', 'stale': 1},
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {'name': 'Ada'});
    });

    testWidgets('non-string values are shown as text', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([textSpec('age')]),
        initialValues: {'age': 42},
      );

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('a non-boolean value leaves a checkbox unticked',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([checkboxSpec('terms')]),
        initialValues: {'terms': 'true'},
      );

      expect(isChecked(tester, 'terms'), isFalse);
    });

    testWidgets('invalid JSON text fails with a FormatException',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name')]),
        initialValues: '{not json',
      );

      expect(tester.takeException(), isA<FormatException>());
    });

    testWidgets('valid JSON that is not an object fails', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name')]),
        initialValues: '[1, 2]',
      );

      expect(
        tester.takeException(),
        formatExceptionWith('must be a JSON object'),
      );
    });

    testWidgets('the value of a hidden field is held until it is shown',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('hasPet'),
          textSpec('petName', visibleWhen: when('hasPet', true)),
        ]),
        initialValues: {'hasPet': false, 'petName': 'Biscuit'},
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);
      expect(submitted, {'hasPet': false});

      await toggle(tester, 'hasPet');
      expect(find.text('Biscuit'), findsOneWidget);
    });
  });

  group('visibility', () {
    final pets = formSchema([
      checkboxSpec('hasPet'),
      textSpec('petName', visibleWhen: when('hasPet', true)),
      textSpec('wantsPet', visibleWhen: when('hasPet', false)),
    ]);

    testWidgets(
        'equals true is hidden and equals false is shown on a fresh '
        'form', (tester) async {
      await pumpForm(tester, schema: pets);

      expect(textField('petName'), findsNothing);
      expect(textField('wantsPet'), findsOneWidget);
    });

    testWidgets('toggling the checkbox swaps the dependent fields',
        (tester) async {
      await pumpForm(tester, schema: pets);

      await toggle(tester, 'hasPet');
      expect(textField('petName'), findsOneWidget);
      expect(textField('wantsPet'), findsNothing);

      await toggle(tester, 'hasPet');
      expect(textField('petName'), findsNothing);
      expect(textField('wantsPet'), findsOneWidget);
    });

    testWidgets('a hidden required field does not block submit',
        (tester) async {
      Map<String, dynamic>? submitted;
      final schema = formSchema([
        checkboxSpec('hasPet'),
        textSpec('petName', required: true, visibleWhen: when('hasPet', true)),
      ]);
      await pumpForm(tester, schema: schema, onSubmit: (v) => submitted = v);

      await submit(tester);
      expect(submitted, {'hasPet': false});

      submitted = null;
      await toggle(tester, 'hasPet');
      await submit(tester);
      expect(submitted, isNull);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('hidden fields are absent from the output even after typing',
        (tester) async {
      Map<String, dynamic>? submitted;
      final schema = formSchema([
        checkboxSpec('hasPet'),
        textSpec('petName', visibleWhen: when('hasPet', true)),
      ]);
      await pumpForm(tester, schema: schema, onSubmit: (v) => submitted = v);

      await toggle(tester, 'hasPet');
      await tester.enterText(textField('petName'), 'Biscuit');
      await toggle(tester, 'hasPet');
      await submit(tester);

      expect(submitted, {'hasPet': false});
    });

    testWidgets('a field keeps what was typed across hide and show',
        (tester) async {
      Map<String, dynamic>? submitted;
      final schema = formSchema([
        checkboxSpec('hasPet'),
        textSpec('petName', visibleWhen: when('hasPet', true)),
      ]);
      await pumpForm(tester, schema: schema, onSubmit: (v) => submitted = v);

      await toggle(tester, 'hasPet');
      await tester.enterText(textField('petName'), 'Biscuit');
      await toggle(tester, 'hasPet');
      await toggle(tester, 'hasPet');

      expect(find.text('Biscuit'), findsOneWidget);
      await submit(tester);
      expect(submitted, {'hasPet': true, 'petName': 'Biscuit'});
    });

    testWidgets('fields below a removed one keep their own state',
        (tester) async {
      final schema = formSchema([
        checkboxSpec('gate'),
        textSpec('first', visibleWhen: when('gate', true)),
        textSpec('second'),
      ]);
      await pumpForm(tester, schema: schema);

      await tester.enterText(textField('second'), 'kept');
      await toggle(tester, 'gate');
      expect(find.text('kept'), findsOneWidget);

      await toggle(tester, 'gate');
      expect(find.text('kept'), findsOneWidget);
    });

    testWidgets('typing in an unwatched field does not hide anything',
        (tester) async {
      await pumpForm(tester, schema: pets);

      await tester.enterText(textField('wantsPet'), 'maybe');
      await tester.pump();

      expect(textField('wantsPet'), findsOneWidget);
      expect(find.text('maybe'), findsOneWidget);
    });
  });

  group('groups', () {
    testWidgets('group children appear flat in the output, without the key',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec('pet', [textSpec('petName'), textSpec('petAge')]),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(textField('petName'), 'Biscuit');
      await tester.enterText(textField('petAge'), '3');
      await submit(tester);

      expect(submitted, {'petName': 'Biscuit', 'petAge': '3'});
    });

    testWidgets('a hidden group is excluded from output and validation',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('hasPet'),
          groupSpec(
            'pet',
            [textSpec('petName', required: true)],
            visibleWhen: when('hasPet', true),
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );

      expect(textField('petName'), findsNothing);
      await submit(tester);

      expect(submitted, {'hasPet': false});
    });

    testWidgets('a visible group validates its children', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('hasPet'),
          groupSpec(
            'pet',
            [textSpec('petName', required: true)],
            visibleWhen: when('hasPet', true),
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await toggle(tester, 'hasPet');
      await submit(tester);

      expect(submitted, isNull);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('nested groups render and flatten', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec('outer', [
            groupSpec('inner', [textSpec('leaf')]),
          ]),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(textField('leaf'), 'x');
      await submit(tester);

      expect(submitted, {'leaf': 'x'});
    });

    final nested = formSchema([
      checkboxSpec('hasPet'),
      groupSpec(
        'pet',
        [
          textSpec('petName'),
          checkboxSpec('petInsured'),
          textSpec('insurer', visibleWhen: when('petInsured', true)),
        ],
        visibleWhen: when('hasPet', true),
      ),
    ]);

    testWidgets('hiding a group hides everything in it and restores it later',
        (tester) async {
      await pumpForm(tester, schema: nested);

      await toggle(tester, 'hasPet');
      await toggle(tester, 'petInsured');
      expect(textField('insurer'), findsOneWidget);

      await toggle(tester, 'hasPet');
      expect(find.byType(TextFormField), findsNothing);
      expect(checkboxTile('petInsured'), findsNothing);

      await toggle(tester, 'hasPet');
      expect(isChecked(tester, 'petInsured'), isTrue);
      expect(textField('insurer'), findsOneWidget);
    });

    testWidgets('a field outside a hidden group cannot see its children',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('hasPet'),
          groupSpec(
            'pet',
            [checkboxSpec('petInsured')],
            visibleWhen: when('hasPet', true),
          ),
          textSpec('paperwork', visibleWhen: when('petInsured', true)),
        ]),
      );

      await toggle(tester, 'hasPet');
      await toggle(tester, 'petInsured');
      expect(textField('paperwork'), findsOneWidget);

      // petInsured is still ticked internally, but hidden fields count as
      // absent, so the condition on it must fail.
      await toggle(tester, 'hasPet');
      expect(textField('paperwork'), findsNothing);
    });
  });

  group('JsonFormController', () {
    final schema = formSchema([
      textSpec('name', required: true),
      checkboxSpec('hasPet'),
      textSpec('petName', visibleWhen: when('hasPet', true)),
    ]);

    test('an unattached controller throws a StateError', () {
      expect(JsonFormController().collectValues, throwsStateError);
    });

    testWidgets('collects values without validating', (tester) async {
      final controller = JsonFormController();
      await pumpForm(tester, schema: schema, controller: controller);

      expect(controller.collectValues(), {'name': '', 'hasPet': false});
      await tester.pump();
      expect(find.text('Required'), findsNothing);
    });

    testWidgets('collects exactly what is currently entered', (tester) async {
      final controller = JsonFormController();
      await pumpForm(tester, schema: schema, controller: controller);

      await tester.enterText(textField('name'), 'Ada');
      await toggle(tester, 'hasPet');
      await tester.enterText(textField('petName'), 'Biscuit');

      expect(
        controller.collectValues(),
        {'name': 'Ada', 'hasPet': true, 'petName': 'Biscuit'},
      );
    });

    testWidgets('leaves out hidden fields', (tester) async {
      final controller = JsonFormController();
      await pumpForm(tester, schema: schema, controller: controller);

      await toggle(tester, 'hasPet');
      await tester.enterText(textField('petName'), 'Biscuit');
      await toggle(tester, 'hasPet');

      expect(controller.collectValues(), {'name': '', 'hasPet': false});
    });

    testWidgets('keeps working after the form is rebuilt under a new key',
        (tester) async {
      final controller = JsonFormController();
      await pumpForm(
        tester,
        schema: schema,
        controller: controller,
        formKey: const ValueKey(1),
      );
      await pumpForm(
        tester,
        schema: schema,
        controller: controller,
        formKey: const ValueKey(2),
      );

      await tester.enterText(textField('name'), 'Ada');

      expect(controller.collectValues()['name'], 'Ada');
    });

    testWidgets('detaches when the form is removed', (tester) async {
      final controller = JsonFormController();
      await pumpForm(tester, schema: schema, controller: controller);

      await tester.pumpWidget(const SizedBox());

      expect(controller.collectValues, throwsStateError);
    });
  });

  group('custom inputs', () {
    testWidgets('a registered input is used for its type', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          {'key': 'code', 'type': 'shout'},
        ]),
        inputs: const [...JsonForm.defaultInputs, _ShoutInput()],
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(find.byType(TextFormField), 'abc');
      await submit(tester);

      expect(submitted, {'code': 'ABC'});
    });

    testWidgets('a later input for the same type overrides an earlier one',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([textSpec('name')]),
        inputs: const [...JsonForm.defaultInputs, _OverridingTextInput()],
        onSubmit: (v) => submitted = v,
      );

      expect(find.byKey(const Key('override')), findsOneWidget);
      await submit(tester);

      expect(submitted, {'name': 'overridden'});
    });

    testWidgets('an input that reports changes can drive a condition',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          {'key': 'flag', 'type': 'switch'},
          textSpec('detail', visibleWhen: when('flag', true)),
        ]),
        inputs: const [...JsonForm.defaultInputs, _SwitchInput()],
      );

      expect(textField('detail'), findsNothing);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      expect(textField('detail'), findsOneWidget);
    });
  });
}

/// Upper-cases whatever is typed when the form is saved.
class _ShoutInput extends JsonFormFieldInput {
  const _ShoutInput();

  @override
  String get type => 'shout';

  @override
  Widget build(
    BuildContext context,
    FieldSpec spec, {
    required Object? initialValue,
    required void Function(dynamic value) onChanged,
    required void Function(dynamic value) onSaved,
  }) {
    return TextFormField(
      decoration: InputDecoration(labelText: spec.key),
      onSaved: (v) => onSaved(v?.toUpperCase()),
    );
  }
}

/// Replaces the built-in text input.
class _OverridingTextInput extends JsonFormFieldInput {
  const _OverridingTextInput();

  @override
  String get type => 'text';

  @override
  Widget build(
    BuildContext context,
    FieldSpec spec, {
    required Object? initialValue,
    required void Function(dynamic value) onChanged,
    required void Function(dynamic value) onSaved,
  }) {
    return TextFormField(
      key: const Key('override'),
      onSaved: (_) => onSaved('overridden'),
    );
  }
}

/// A boolean input that reports changes, as a condition source must.
class _SwitchInput extends JsonFormFieldInput {
  const _SwitchInput();

  @override
  String get type => 'switch';

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
      initialValue: initialValue == true,
      onSaved: onSaved,
      builder: (state) => SwitchListTile(
        title: Text(spec.key),
        value: state.value ?? false,
        onChanged: (v) {
          state.didChange(v);
          onChanged(v);
        },
      ),
    );
  }
}
