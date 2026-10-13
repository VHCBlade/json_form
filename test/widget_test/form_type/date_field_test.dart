import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:json_form/json_form.dart';

import '../../helpers/form_test_helpers.dart';

/// What the clock says in these tests, unless a test says otherwise.
final _today = DateTime(2026, 10, 12);

FieldSpec _spec([Map<String, dynamic> extra = const {}]) =>
    FieldSpec.fromJson({'key': 'when', 'type': 'date', ...extra});

JsonFormDateFieldInput _inputAt(DateTime today) =>
    JsonFormDateFieldInput(clock: () => today);

void main() {
  const input = JsonFormDateFieldInput();

  group('type and clock', () {
    test('handles the "date" schema type', () {
      expect(input.type, 'date');
    });

    test('is one of the default inputs', () {
      expect(JsonForm.defaultInputs.map((i) => i.type), contains('date'));
    });

    test('uses the system clock unless given one', () {
      final before = DateTime.now();
      final now = input.clock();
      final after = DateTime.now();

      expect(now.isBefore(before), isFalse);
      expect(now.isAfter(after), isFalse);
    });
  });

  group('normalizeInitialValue', () {
    test('keeps an ISO date string', () {
      expect(input.normalizeInitialValue('2026-10-10'), '2026-10-10');
    });

    test('ignores a time after the date', () {
      expect(input.normalizeInitialValue('2026-10-10T23:59:00Z'), '2026-10-10');
      expect(input.normalizeInitialValue('2026-10-10 08:00'), '2026-10-10');
    });

    test('ignores surrounding whitespace', () {
      expect(input.normalizeInitialValue(' 2026-10-10 '), '2026-10-10');
    });

    test('formats a DateTime as a date', () {
      expect(
        input.normalizeInitialValue(DateTime(2026, 3, 5, 14, 30)),
        '2026-03-05',
      );
    });

    test('pads short years', () {
      expect(input.normalizeInitialValue('0999-01-01'), '0999-01-01');
    });

    test('accepts 29 February only in a leap year', () {
      expect(input.normalizeInitialValue('2028-02-29'), '2028-02-29');
      expect(input.normalizeInitialValue('2026-02-29'), isNull);
    });

    test('rejects a date that does not exist rather than rolling it over', () {
      expect(input.normalizeInitialValue('2026-02-30'), isNull);
      expect(input.normalizeInitialValue('2026-04-31'), isNull);
      expect(input.normalizeInitialValue('2026-13-01'), isNull);
      expect(input.normalizeInitialValue('2026-00-10'), isNull);
      expect(input.normalizeInitialValue('2026-10-00'), isNull);
    });

    test('rejects other formats', () {
      for (final text in [
        '10/10/2026',
        '20261010',
        '2026-1-1',
        '2026-10-1',
        'abcd-ef-gh',
        '2026-10-10X12:00',
        '2026/10/10',
        'today',
        '',
      ]) {
        expect(input.normalizeInitialValue(text), isNull, reason: text);
      }
    });

    test('rejects values that are not strings or dates', () {
      expect(input.normalizeInitialValue(20261010), isNull);
      expect(input.normalizeInitialValue(true), isNull);
      expect(input.normalizeInitialValue(null), isNull);
    });
  });

  group('validate', () {
    test('accepts a spec with no bounds', () {
      expect(() => input.validate(_spec()), returnsNormally);
    });

    test('accepts fixed bounds, one or both', () {
      expect(
          () => input.validate(_spec({'min': '2026-01-01'})), returnsNormally);
      expect(
          () => input.validate(_spec({'max': '2026-12-31'})), returnsNormally);
      expect(
        () => input.validate(_spec({'min': '2026-01-01', 'max': '2026-12-31'})),
        returnsNormally,
      );
    });

    test('accepts equal bounds', () {
      expect(
        () => input.validate(_spec({'min': '2026-05-05', 'max': '2026-05-05'})),
        returnsNormally,
      );
    });

    test('accepts a bound written with a time', () {
      expect(
        () => input.validate(_spec({'min': '2026-05-05T09:00:00'})),
        returnsNormally,
      );
    });

    test('accepts the words, with and without offsets', () {
      for (final bound in [
        'today',
        'thisMonth',
        'thisYear',
        'today+30d',
        'today-18y',
        'today + 2w',
        'thisMonth+1m',
        'thisYear-1y+6m',
      ]) {
        expect(
          () => input.validate(_spec({'min': bound})),
          returnsNormally,
          reason: bound,
        );
        expect(
          () => input.validate(_spec({'max': bound})),
          returnsNormally,
          reason: bound,
        );
      }
    });

    test('treats an explicit null bound as absent', () {
      expect(
        () => input.validate(_spec({'min': null, 'max': null})),
        returnsNormally,
      );
    });

    test('rejects min after max', () {
      expect(
        () => input.validate(_spec({'min': '2026-12-31', 'max': '2026-01-01'})),
        throwsA(formatExceptionWith(
          '"when" has min 2026-12-31 later than max 2026-01-01',
        )),
      );
    });

    test('rejects a bound that is not a date', () {
      for (final bound in ['next week', '2026-02-30', '10/10/2026', 5, true]) {
        expect(
          () => input.validate(_spec({'min': bound})),
          throwsA(formatExceptionWith(
            '"min" of "when" must be a date like 2026-10-10',
          )),
          reason: '$bound',
        );
      }
    });

    test('names the bound and the value in the message', () {
      expect(
        () => input.validate(_spec({'max': 'tomorrow'})),
        throwsA(formatExceptionWith('"max" of "when"')),
      );
      expect(
        () => input.validate(_spec({'max': 'tomorrow'})),
        throwsA(formatExceptionWith(': tomorrow')),
      );
    });

    test('mentions the words and offsets in the message', () {
      expect(
        () => input.validate(_spec({'min': 'x'})),
        throwsA(formatExceptionWith(
          'one of today, thisMonth, thisYear optionally followed by an offset '
          'such as +30d, -1y, +2w or +3m',
        )),
      );
    });

    test('judges relative bounds against the clock', () {
      final spec = _spec({'min': 'today', 'max': '2026-10-01'});

      expect(
        () => _inputAt(DateTime(2026, 10, 12)).validate(spec),
        throwsA(formatExceptionWith(
          '"when" has min 2026-10-12 later than max 2026-10-01',
        )),
      );
      expect(
        () => _inputAt(DateTime(2026, 9, 1)).validate(spec),
        returnsNormally,
      );
    });
  });

  group('the picker', () {
    testTall('starts empty, with a calendar icon and no clear button',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when')]),
        inputs: clockInputs(() => _today),
      );

      expect(fieldText(tester, 'when'), '');
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testTall('choosing a day sets the field and the output', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when')]),
        inputs: clockInputs(() => _today),
        onSubmit: (v) => submitted = v,
      );

      await pickDay(tester, 'when', 20);
      expect(fieldText(tester, 'when'), '2026-10-20');

      await submit(tester);
      expect(submitted, {'when': '2026-10-20'});
    });

    testTall('the picker opens on the month the clock is in', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when')]),
        inputs: clockInputs(() => DateTime(2027, 2, 14)),
      );

      await pickDay(tester, 'when', 20);

      expect(fieldText(tester, 'when'), '2027-02-20');
    });

    testTall('cancelling leaves the field as it was', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when')]),
        inputs: clockInputs(() => _today),
      );

      await tester.tap(textField('when'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fieldText(tester, 'when'), '');
    });

    testTall('the clear button empties the field and the output',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when')]),
        inputs: clockInputs(() => _today),
        onSubmit: (v) => submitted = v,
      );
      await pickDay(tester, 'when', 20);
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(fieldText(tester, 'when'), '');
      expect(find.byIcon(Icons.clear), findsNothing);
      await submit(tester);
      expect(submitted, {'when': null});
    });

    testTall('an untouched optional field submits null', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when')]),
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {'when': null});
    });

    testTall('a required field blocks submit until a date is chosen',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when', required: true)]),
        inputs: clockInputs(() => _today),
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);
      expect(submitted, isNull);
      expect(find.text('Required'), findsOneWidget);

      await pickDay(tester, 'when', 20);
      await submit(tester);
      expect(submitted, {'when': '2026-10-20'});
    });

    testTall('days outside min are not selectable, so the nearest is used',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when', min: '2026-10-15')]),
        inputs: clockInputs(() => _today),
      );

      // The 10th is before the minimum, so tapping it changes nothing, and
      // the picker started on the first allowed day.
      await pickDay(tester, 'when', 10);

      expect(fieldText(tester, 'when'), '2026-10-15');
    });

    testTall('days outside max are not selectable, so the nearest is used',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when', max: '2026-10-05')]),
        inputs: clockInputs(() => _today),
      );

      await pickDay(tester, 'when', 20);

      expect(fieldText(tester, 'when'), '2026-10-05');
    });

    testTall('a day inside the bounds can be chosen', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('when', min: '2026-10-15', max: '2026-10-25'),
        ]),
        inputs: clockInputs(() => _today),
      );

      await pickDay(tester, 'when', 20);

      expect(fieldText(tester, 'when'), '2026-10-20');
    });
  });

  group('helper text', () {
    Future<void> pumpBounded(WidgetTester tester, Map<String, dynamic> field) {
      return pumpForm(
        tester,
        schema: formSchema([field]),
        inputs: clockInputs(() => _today),
      );
    }

    testTall('shows both bounds', (tester) async {
      await pumpBounded(
        tester,
        dateSpec('when', min: '2026-10-15', max: '2026-10-20'),
      );

      expect(helperText(tester), '2026-10-15 to 2026-10-20');
    });

    testTall('shows a minimum alone', (tester) async {
      await pumpBounded(tester, dateSpec('when', min: '2026-10-15'));

      expect(helperText(tester), 'From 2026-10-15');
    });

    testTall('shows a maximum alone', (tester) async {
      await pumpBounded(tester, dateSpec('when', max: '2026-10-20'));

      expect(helperText(tester), 'Until 2026-10-20');
    });

    testTall('shows nothing without bounds', (tester) async {
      await pumpBounded(tester, dateSpec('when'));

      expect(helperText(tester), isNull);
    });
  });

  group('initial values', () {
    testTall('prefills from an ISO string', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when')]),
        initialValues: {'when': '2026-03-05'},
      );

      expect(fieldText(tester, 'when'), '2026-03-05');
    });

    testTall('prefills from a JSON string', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when')]),
        initialValues: '{"when": "2026-03-05"}',
      );

      expect(fieldText(tester, 'when'), '2026-03-05');
    });

    testTall('drops a time, and accepts a DateTime', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('a'), dateSpec('b')]),
        initialValues: {
          'a': '2026-03-05T14:30:00',
          'b': DateTime(2026, 4, 6, 9),
        },
      );

      expect(fieldText(tester, 'a'), '2026-03-05');
      expect(fieldText(tester, 'b'), '2026-04-06');
    });

    testTall('a value that is not a date leaves the field empty',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when')]),
        initialValues: {'when': '2026-02-30'},
      );

      expect(fieldText(tester, 'when'), '');
    });

    testTall('a prefilled date is submitted as it was', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when')]),
        initialValues: {'when': '2026-03-05'},
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {'when': '2026-03-05'});
    });

    testTall('a prefill outside min or max is clamped', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('early', min: '2026-10-15'),
          dateSpec('late', max: '2026-10-20'),
        ]),
        inputs: clockInputs(() => _today),
        initialValues: {'early': '2000-01-01', 'late': '2999-01-01'},
      );

      expect(fieldText(tester, 'early'), '2026-10-15');
      expect(fieldText(tester, 'late'), '2026-10-20');
    });

    testTall('a clamped prefill is what gets submitted', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when', min: '2026-10-15')]),
        inputs: clockInputs(() => _today),
        initialValues: {'when': '2000-01-01'},
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {'when': '2026-10-15'});
    });

    testTall('a clamped prefill reaches conditions one frame later',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('when', min: '2026-10-15'),
          textSpec(
            'atMin',
            visibleWhen: {'field': 'when', 'equals': '2026-10-15'},
          ),
        ]),
        inputs: clockInputs(() => _today),
        initialValues: {'when': '2000-01-01'},
      );

      expect(textField('atMin'), findsNothing);

      await tester.pump();

      expect(textField('atMin'), findsOneWidget);
    });
  });

  group('as a condition source', () {
    testTall('equals compares the ISO string', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('when'),
          textSpec(
            'note',
            visibleWhen: {'field': 'when', 'equals': '2026-10-20'},
          ),
        ]),
        inputs: clockInputs(() => _today),
      );
      expect(textField('note'), findsNothing);

      await pickDay(tester, 'when', 20);
      expect(textField('note'), findsOneWidget);

      await pickDay(tester, 'when', 21);
      expect(textField('note'), findsNothing);
    });

    testTall('clearing the date hides what depended on it', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('when'),
          textSpec(
            'note',
            visibleWhen: {'field': 'when', 'equals': '2026-10-20'},
          ),
        ]),
        inputs: clockInputs(() => _today),
      );
      await pickDay(tester, 'when', 20);
      expect(textField('note'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(textField('note'), findsNothing);
    });
  });

  group('hiding and showing', () {
    testTall('a hidden date keeps its value when shown again', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('gate'),
          dateSpec('when', visibleWhen: when('gate', true)),
        ]),
        inputs: clockInputs(() => _today),
        onSubmit: (v) => submitted = v,
      );

      await toggle(tester, 'gate');
      await pickDay(tester, 'when', 20);
      await toggle(tester, 'gate');
      expect(textField('when'), findsNothing);

      await toggle(tester, 'gate');
      expect(fieldText(tester, 'when'), '2026-10-20');
      await submit(tester);
      expect(submitted, {'gate': true, 'when': '2026-10-20'});
    });

    testTall('a hidden required date does not block submit', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('gate'),
          dateSpec('when', required: true, visibleWhen: when('gate', true)),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {'gate': false});
    });
  });

  group('schema errors at build', () {
    testWidgets('a bound that is not a date', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when', min: 'next week')]),
      );

      expect(
        tester.takeException(),
        formatExceptionWith('"min" of "when" must be a date like 2026-10-10'),
      );
    });

    testWidgets('min after max', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('when', min: '2026-12-31', max: '2026-01-01'),
        ]),
      );

      expect(tester.takeException(), formatExceptionWith('later than max'));
    });
  });
}
