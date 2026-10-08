import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:json_form/json_form.dart';

import '../../helpers/form_test_helpers.dart';

/// A source whose result the test releases by hand.
class _ManualSource extends JsonFormOptionsSource {
  _ManualSource();

  final Completer<List<JsonFormOption>> completer = Completer();
  int loads = 0;

  @override
  Future<List<JsonFormOption>> load(FieldSpec spec) {
    loads++;
    return completer.future;
  }
}

const _countries = [
  JsonFormOption(value: 'JP', label: 'Japan'),
  JsonFormOption(value: 'KE', label: 'Kenya'),
];

void main() {
  group('inline options', () {
    final sizes = formSchema([
      dropdownSpec('size', options: ['Small', 'Medium', 'Large']),
    ]);

    testWidgets('selecting an option saves its value', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(tester, schema: sizes, onSubmit: (v) => submitted = v);
      await tester.pumpAndSettle();

      await choose(tester, 'Medium');
      await submit(tester);

      expect(submitted, {'size': 'Medium'});
    });

    testWidgets('a map option shows its label and saves its value',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          dropdownSpec('role', options: [
            {'value': 'adm', 'label': 'Administrator'},
            {'value': 'usr', 'label': 'User'},
          ]),
        ]),
        onSubmit: (v) => submitted = v,
      );
      await tester.pumpAndSettle();

      await choose(tester, 'User');
      await submit(tester);

      expect(submitted, {'role': 'usr'});
    });

    testWidgets('an untouched optional dropdown submits null', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(tester, schema: sizes, onSubmit: (v) => submitted = v);
      await tester.pumpAndSettle();

      await submit(tester);

      expect(submitted, {'size': null});
    });

    testWidgets('a required dropdown blocks submit until chosen',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          dropdownSpec('size', options: ['Small', 'Large'], required: true),
        ]),
        onSubmit: (v) => submitted = v,
      );
      await tester.pumpAndSettle();

      await submit(tester);
      expect(submitted, isNull);
      expect(find.text('Required'), findsOneWidget);

      await choose(tester, 'Large');
      await submit(tester);
      expect(submitted, {'size': 'Large'});
    });

    testWidgets('prefills a matching value', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: sizes,
        initialValues: {'size': 'Medium'},
        onSubmit: (v) => submitted = v,
      );
      await tester.pumpAndSettle();

      expect(find.text('Medium'), findsOneWidget);
      await submit(tester);
      expect(submitted, {'size': 'Medium'});
    });

    testWidgets('prefills by value and displays the label', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dropdownSpec('role', options: [
            {'value': 'usr', 'label': 'User'},
          ]),
        ]),
        initialValues: {'role': 'usr'},
      );
      await tester.pumpAndSettle();

      expect(find.text('User'), findsOneWidget);
    });

    testWidgets('a prefill that is not among the options is ignored',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: sizes,
        initialValues: {'size': 'Huge'},
        onSubmit: (v) => submitted = v,
      );
      await tester.pumpAndSettle();

      expect(find.text('Huge'), findsNothing);
      await submit(tester);
      expect(submitted, {'size': null});
    });
  });

  group('schema errors', () {
    testWidgets('an unknown options source', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([dropdownSpec('country', optionsSource: 'nope')]),
      );

      expect(
        tester.takeException(),
        formatExceptionWith('Unknown options source: nope'),
      );
    });

    testWidgets('neither options nor a source', (tester) async {
      await pumpForm(tester, schema: formSchema([dropdownSpec('country')]));

      expect(
        tester.takeException(),
        formatExceptionWith('needs "options" or "optionsSource"'),
      );
    });

    testWidgets('a source wins when both are given', (tester) async {
      final source = _ManualSource();
      await pumpForm(
        tester,
        schema: formSchema([
          dropdownSpec(
            'country',
            options: ['Ignored'],
            optionsSource: 'countries',
          ),
        ]),
        inputs: [
          ...JsonForm.defaultInputs,
          JsonFormDropdownFieldInput(sources: {'countries': source}),
        ],
      );

      expect(source.loads, 1);
    });
  });

  group('async source', () {
    final countrySchema = formSchema([
      dropdownSpec('country', optionsSource: 'countries'),
    ]);

    List<JsonFormFieldInput> inputsWith(_ManualSource source) => [
          ...JsonForm.defaultInputs,
          JsonFormDropdownFieldInput(sources: {'countries': source}),
        ];

    DropdownButtonFormField<Object> field(WidgetTester tester) =>
        tester.widget<DropdownButtonFormField<Object>>(dropdownField);

    testWidgets('is disabled until the options arrive', (tester) async {
      final source = _ManualSource();
      await pumpForm(
        tester,
        schema: countrySchema,
        inputs: inputsWith(source),
      );

      expect(field(tester).onChanged, isNull);

      source.completer.complete(_countries);
      await tester.pumpAndSettle();

      expect(field(tester).onChanged, isNotNull);
    });

    testWidgets('a prefill is applied once the options arrive', (tester) async {
      Map<String, dynamic>? submitted;
      final source = _ManualSource();
      await pumpForm(
        tester,
        schema: countrySchema,
        inputs: inputsWith(source),
        initialValues: {'country': 'JP'},
        onSubmit: (v) => submitted = v,
      );

      expect(find.text('Japan'), findsNothing);

      source.completer.complete(_countries);
      await tester.pumpAndSettle();

      expect(find.text('Japan'), findsOneWidget);
      await submit(tester);
      expect(submitted, {'country': 'JP'});
    });

    testWidgets('a value can be chosen after loading', (tester) async {
      Map<String, dynamic>? submitted;
      final source = _ManualSource();
      await pumpForm(
        tester,
        schema: countrySchema,
        inputs: inputsWith(source),
        onSubmit: (v) => submitted = v,
      );

      source.completer.complete(_countries);
      await tester.pumpAndSettle();
      await choose(tester, 'Kenya');
      await submit(tester);

      expect(submitted, {'country': 'KE'});
    });

    testWidgets('a failed load shows an error and saves null', (tester) async {
      Map<String, dynamic>? submitted;
      final source = _ManualSource();
      await pumpForm(
        tester,
        schema: countrySchema,
        inputs: inputsWith(source),
        onSubmit: (v) => submitted = v,
      );

      source.completer.completeError(Exception('network down'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load options'), findsOneWidget);
      expect(field(tester).onChanged, isNull);
      await submit(tester);
      expect(submitted, {'country': null});
    });

    testWidgets('the source is loaded once, however often the form rebuilds',
        (tester) async {
      final source = _ManualSource();
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('gate'),
          dropdownSpec('country', optionsSource: 'countries'),
          textSpec('extra', visibleWhen: when('gate', true)),
        ]),
        inputs: inputsWith(source),
      );

      await toggle(tester, 'gate');
      await toggle(tester, 'gate');
      await toggle(tester, 'gate');

      expect(source.loads, 1);
    });
  });
}
