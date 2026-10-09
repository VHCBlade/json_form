import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_form/json_form.dart';

import '../../helpers/form_test_helpers.dart';

FieldSpec _spec([Map<String, dynamic> extra = const {}]) =>
    FieldSpec.fromJson({'key': 'age', 'type': 'integer', ...extra});

void main() {
  const input = JsonFormIntegerFieldInput();

  group('type', () {
    test('handles the "integer" schema type', () {
      expect(input.type, 'integer');
    });

    test('is one of the default inputs', () {
      expect(
        JsonForm.defaultInputs.map((i) => i.type),
        contains('integer'),
      );
    });
  });

  group('normalizeInitialValue', () {
    test('keeps an int', () {
      expect(input.normalizeInitialValue(42), 42);
      expect(input.normalizeInitialValue(-7), -7);
      expect(input.normalizeInitialValue(0), 0);
    });

    test('turns a whole-valued double into an int', () {
      final value = input.normalizeInitialValue(5.0);

      expect(value, 5);
      expect(value, isA<int>());
      expect(input.normalizeInitialValue(-3.0), -3);
    });

    test('rejects a fractional number', () {
      expect(input.normalizeInitialValue(5.5), isNull);
    });

    test('rejects non-finite numbers', () {
      expect(input.normalizeInitialValue(double.infinity), isNull);
      expect(input.normalizeInitialValue(double.nan), isNull);
    });

    test('does not coerce strings or booleans', () {
      expect(input.normalizeInitialValue('5'), isNull);
      expect(input.normalizeInitialValue(true), isNull);
    });

    test('passes null through', () {
      expect(input.normalizeInitialValue(null), isNull);
    });
  });

  group('validate', () {
    test('accepts a spec with no bounds', () {
      expect(() => input.validate(_spec()), returnsNormally);
    });

    test('accepts one bound or both', () {
      expect(() => input.validate(_spec({'min': 0})), returnsNormally);
      expect(() => input.validate(_spec({'max': 10})), returnsNormally);
      expect(
        () => input.validate(_spec({'min': 0, 'max': 10})),
        returnsNormally,
      );
    });

    test('accepts equal bounds', () {
      expect(
        () => input.validate(_spec({'min': 5, 'max': 5})),
        returnsNormally,
      );
    });

    test('accepts negative bounds', () {
      expect(
        () => input.validate(_spec({'min': -10, 'max': -1})),
        returnsNormally,
      );
    });

    test('accepts whole-valued double bounds', () {
      expect(
        () => input.validate(_spec({'min': 1.0, 'max': 5.0})),
        returnsNormally,
      );
    });

    test('treats an explicit null bound as absent', () {
      expect(
        () => input.validate(_spec({'min': null, 'max': null})),
        returnsNormally,
      );
    });

    test('rejects min above max', () {
      expect(
        () => input.validate(_spec({'min': 50, 'max': 10})),
        throwsA(formatExceptionWith('"age" has min 50 greater than max 10')),
      );
    });

    test('rejects a fractional bound', () {
      expect(
        () => input.validate(_spec({'min': 1.5})),
        throwsA(formatExceptionWith('"min" of "age" must be a whole number')),
      );
      expect(
        () => input.validate(_spec({'max': 9.9})),
        throwsA(formatExceptionWith('"max" of "age" must be a whole number')),
      );
    });

    test('rejects a bound that is not a number', () {
      expect(
        () => input.validate(_spec({'max': '5'})),
        throwsA(formatExceptionWith('must be a whole number: 5')),
      );
      expect(
        () => input.validate(_spec({'min': true})),
        throwsA(formatExceptionWith('must be a whole number: true')),
      );
    });
  });

  group('schema errors at build', () {
    testWidgets('min above max', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('age', min: 50, max: 10)]),
      );

      expect(
        tester.takeException(),
        formatExceptionWith('has min 50 greater than max 10'),
      );
    });

    testWidgets('a fractional bound', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          {'key': 'age', 'type': 'integer', 'min': 1.5},
        ]),
      );

      expect(tester.takeException(), formatExceptionWith('whole number'));
    });
  });

  group('clamping', () {
    final ranged = formSchema([integerSpec('age', min: 18, max: 120)]);

    testWidgets('a value below the minimum becomes the minimum on blur',
        (tester) async {
      await pumpForm(tester, schema: ranged);

      await tester.enterText(textField('age'), '5');
      await blur(tester);

      expect(fieldText(tester, 'age'), '18');
    });

    testWidgets('a value above the maximum becomes the maximum on blur',
        (tester) async {
      await pumpForm(tester, schema: ranged);

      await tester.enterText(textField('age'), '500');
      await blur(tester);

      expect(fieldText(tester, 'age'), '120');
    });

    testWidgets('a value inside the range is left alone', (tester) async {
      await pumpForm(tester, schema: ranged);

      await tester.enterText(textField('age'), '30');
      await blur(tester);

      expect(fieldText(tester, 'age'), '30');
    });

    testWidgets('both bounds are inclusive', (tester) async {
      await pumpForm(tester, schema: ranged);

      await tester.enterText(textField('age'), '18');
      await blur(tester);
      expect(fieldText(tester, 'age'), '18');

      await tester.enterText(textField('age'), '120');
      await blur(tester);
      expect(fieldText(tester, 'age'), '120');
    });

    testWidgets('typing is not clamped before the field loses focus',
        (tester) async {
      await pumpForm(tester, schema: ranged);

      await tester.enterText(textField('age'), '5');

      expect(fieldText(tester, 'age'), '5');
    });

    testWidgets('with only a maximum, negatives are allowed and unclamped',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('qty', max: 10)]),
      );

      await tester.enterText(textField('qty'), '-500');
      await blur(tester);
      expect(fieldText(tester, 'qty'), '-500');

      await tester.enterText(textField('qty'), '50');
      await blur(tester);
      expect(fieldText(tester, 'qty'), '10');
    });

    testWidgets('with only a minimum, large values are unclamped',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('qty', min: 1)]),
      );

      await tester.enterText(textField('qty'), '0');
      await blur(tester);
      expect(fieldText(tester, 'qty'), '1');

      await tester.enterText(textField('qty'), '5000');
      await blur(tester);
      expect(fieldText(tester, 'qty'), '5000');
    });

    testWidgets('with no bounds nothing is clamped', (tester) async {
      await pumpForm(tester, schema: formSchema([integerSpec('n')]));

      await tester.enterText(textField('n'), '-123456');
      await blur(tester);

      expect(fieldText(tester, 'n'), '-123456');
    });

    testWidgets('a negative range clamps negative values', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('temp', min: -20, max: -5)]),
      );

      await tester.enterText(textField('temp'), '-50');
      await blur(tester);
      expect(fieldText(tester, 'temp'), '-20');

      await tester.enterText(textField('temp'), '-1');
      await blur(tester);
      expect(fieldText(tester, 'temp'), '-5');
    });

    testWidgets('whole-valued double bounds work', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          {'key': 'n', 'type': 'integer', 'min': 1.0, 'max': 5.0},
        ]),
      );

      await tester.enterText(textField('n'), '9');
      await blur(tester);

      expect(fieldText(tester, 'n'), '5');
    });

    testWidgets('digits too long for an int clamp to the bound',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('n', min: -5, max: 120)]),
      );

      await tester.enterText(textField('n'), '99999999999999999999');
      await blur(tester);
      expect(fieldText(tester, 'n'), '120');

      await tester.enterText(textField('n'), '-99999999999999999999');
      await blur(tester);
      expect(fieldText(tester, 'n'), '-5');
    });

    testWidgets('leading zeros are tidied on blur', (tester) async {
      await pumpForm(tester, schema: ranged);

      await tester.enterText(textField('age'), '0030');
      await blur(tester);

      expect(fieldText(tester, 'age'), '30');
    });

    testWidgets('negative zero becomes zero', (tester) async {
      await pumpForm(tester, schema: formSchema([integerSpec('n')]));

      await tester.enterText(textField('n'), '-0');
      await blur(tester);

      expect(fieldText(tester, 'n'), '0');
    });

    testWidgets('an empty field stays empty on blur', (tester) async {
      await pumpForm(tester, schema: ranged);

      await tester.enterText(textField('age'), '');
      await blur(tester);

      expect(fieldText(tester, 'age'), '');
    });
  });

  group('typing', () {
    testWidgets('letters are rejected', (tester) async {
      await pumpForm(tester, schema: formSchema([integerSpec('n')]));

      await tester.enterText(textField('n'), '12');
      await tester.enterText(textField('n'), '12a');

      expect(fieldText(tester, 'n'), '12');
    });

    testWidgets('a decimal point is rejected', (tester) async {
      await pumpForm(tester, schema: formSchema([integerSpec('n')]));

      await tester.enterText(textField('n'), '1.5');

      expect(fieldText(tester, 'n'), '');
    });

    testWidgets('spaces are rejected', (tester) async {
      await pumpForm(tester, schema: formSchema([integerSpec('n')]));

      await tester.enterText(textField('n'), '1 2');

      expect(fieldText(tester, 'n'), '');
    });

    testWidgets('a leading minus is accepted when there is no minimum',
        (tester) async {
      await pumpForm(tester, schema: formSchema([integerSpec('n')]));

      await tester.enterText(textField('n'), '-5');

      expect(fieldText(tester, 'n'), '-5');
    });

    testWidgets('a leading minus is accepted when the minimum is negative',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('n', min: -10)]),
      );

      await tester.enterText(textField('n'), '-5');

      expect(fieldText(tester, 'n'), '-5');
    });

    testWidgets('a minus is rejected when the minimum is zero or more',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('n', min: 0)]),
      );

      await tester.enterText(textField('n'), '-5');

      expect(fieldText(tester, 'n'), '');
    });

    testWidgets('a minus anywhere but the start is rejected', (tester) async {
      await pumpForm(tester, schema: formSchema([integerSpec('n')]));

      await tester.enterText(textField('n'), '5-');
      expect(fieldText(tester, 'n'), '');

      await tester.enterText(textField('n'), '--5');
      expect(fieldText(tester, 'n'), '');
    });
  });

  group('output', () {
    testWidgets('submits an int', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('age')]),
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(textField('age'), '42');
      await submit(tester);

      expect(submitted, {'age': 42});
      expect(submitted!['age'], isA<int>());
    });

    testWidgets('submits the clamped value', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('age', min: 18, max: 120)]),
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(textField('age'), '5');
      await submit(tester);

      expect(submitted, {'age': 18});
    });

    testWidgets('an empty optional field submits null', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('age')]),
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {'age': null});
    });

    testWidgets('a required empty field blocks submit', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('age', required: true)]),
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, isNull);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('a required field submits once filled', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('age', required: true)]),
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(textField('age'), '7');
      await submit(tester);

      expect(submitted, {'age': 7});
    });

    testWidgets('a lone minus is reported as invalid and blocks submit',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('age')]),
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(textField('age'), '-');
      await blur(tester);
      await submit(tester);

      expect(fieldText(tester, 'age'), '-');
      expect(submitted, isNull);
      expect(find.text('Enter a whole number'), findsOneWidget);
    });

    testWidgets('the controller reports the clamped value before any blur',
        (tester) async {
      final controller = JsonFormController();
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('age', min: 18, max: 120)]),
        controller: controller,
      );

      await tester.enterText(textField('age'), '500');

      expect(controller.collectValues(), {'age': 120});
      // The box is only tidied when it loses focus.
      expect(fieldText(tester, 'age'), '500');
    });
  });

  group('initial values', () {
    final ranged = formSchema([integerSpec('age', min: 18, max: 120)]);

    testWidgets('prefills from an int', (tester) async {
      await pumpForm(tester, schema: ranged, initialValues: {'age': 30});

      expect(fieldText(tester, 'age'), '30');
    });

    testWidgets('prefills from a JSON string', (tester) async {
      await pumpForm(tester, schema: ranged, initialValues: '{"age": 30}');

      expect(fieldText(tester, 'age'), '30');
    });

    testWidgets('a whole-valued double is shown as an int', (tester) async {
      await pumpForm(tester, schema: ranged, initialValues: {'age': 30.0});

      expect(fieldText(tester, 'age'), '30');
    });

    testWidgets('an out-of-range prefill is clamped', (tester) async {
      await pumpForm(tester, schema: ranged, initialValues: {'age': 200});
      expect(fieldText(tester, 'age'), '120');

      await pumpForm(
        tester,
        schema: ranged,
        initialValues: {'age': 3},
        formKey: const ValueKey('second'),
      );
      expect(fieldText(tester, 'age'), '18');
    });

    testWidgets('a clamped prefill is what gets submitted', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: ranged,
        initialValues: {'age': 200},
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {'age': 120});
    });

    testWidgets('a string is not coerced', (tester) async {
      await pumpForm(tester, schema: ranged, initialValues: {'age': '30'});

      expect(fieldText(tester, 'age'), '');
    });

    testWidgets('a fractional number leaves the field empty', (tester) async {
      await pumpForm(tester, schema: ranged, initialValues: {'age': 30.5});

      expect(fieldText(tester, 'age'), '');
    });

    testWidgets('no value leaves the field empty', (tester) async {
      await pumpForm(tester, schema: ranged);

      expect(fieldText(tester, 'age'), '');
    });
  });

  group('helper text', () {
    testWidgets('shows the range when both bounds are set', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('age', min: 18, max: 120)]),
      );

      expect(find.text('18 to 120'), findsOneWidget);
    });

    testWidgets('shows a minimum alone', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('age', min: 18)]),
      );

      expect(find.text('Minimum 18'), findsOneWidget);
    });

    testWidgets('shows a maximum alone', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([integerSpec('qty', max: 10)]),
      );

      expect(find.text('Maximum 10'), findsOneWidget);
    });

    testWidgets('shows nothing without bounds', (tester) async {
      await pumpForm(tester, schema: formSchema([integerSpec('n')]));

      expect(find.textContaining('Minimum'), findsNothing);
      expect(find.textContaining('Maximum'), findsNothing);
      expect(find.textContaining(' to '), findsNothing);
    });
  });

  group('as a condition source', () {
    testWidgets('equals matches the number entered', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          integerSpec('qty'),
          textSpec('five', visibleWhen: {'field': 'qty', 'equals': 5}),
        ]),
      );

      expect(textField('five'), findsNothing);

      await tester.enterText(textField('qty'), '5');
      await tester.pump();
      expect(textField('five'), findsOneWidget);

      await tester.enterText(textField('qty'), '6');
      await tester.pump();
      expect(textField('five'), findsNothing);
    });

    testWidgets('conditions see the clamped value while typing',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          integerSpec('age', min: 18),
          textSpec('adult', visibleWhen: {'field': 'age', 'equals': 18}),
        ]),
      );

      await tester.enterText(textField('age'), '5');
      await tester.pump();

      // The box still says 5, but the value the form works with is 18.
      expect(fieldText(tester, 'age'), '5');
      expect(textField('adult'), findsOneWidget);
    });

    testWidgets('a clamped prefill reaches conditions one frame later',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          integerSpec('qty', max: 10),
          textSpec('atLimit', visibleWhen: {'field': 'qty', 'equals': 10}),
        ]),
        initialValues: {'qty': 50},
      );

      // The field shows 10 straight away, but the form is told afterwards.
      expect(fieldText(tester, 'qty'), '10');
      expect(textField('atLimit'), findsNothing);

      await tester.pump();

      expect(textField('atLimit'), findsOneWidget);
    });

    testWidgets('an empty field matches no number', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          integerSpec('qty'),
          textSpec('zero', visibleWhen: {'field': 'qty', 'equals': 0}),
        ]),
      );

      expect(textField('zero'), findsNothing);
    });
  });

  group('hiding and showing', () {
    testWidgets('a hidden integer keeps its value when shown again',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('gate'),
          integerSpec('n', visibleWhen: when('gate', true)),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await toggle(tester, 'gate');
      await tester.enterText(textField('n'), '7');
      await toggle(tester, 'gate');
      expect(textField('n'), findsNothing);

      await toggle(tester, 'gate');
      expect(fieldText(tester, 'n'), '7');

      await submit(tester);
      expect(submitted, {'gate': true, 'n': 7});
    });

    testWidgets('a hidden integer is absent from the output', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('gate'),
          integerSpec('n', required: true, visibleWhen: when('gate', true)),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {'gate': false});
    });
  });
}
