import 'package:flutter_test/flutter_test.dart';

import 'package:json_form/json_form.dart';

import '../../helpers/form_test_helpers.dart';

FieldSpec _spec(Map<String, dynamic> extra) =>
    FieldSpec.fromJson({'key': 'when', 'type': 'date', ...extra});

/// A bound, today's date, and the date the bound should resolve to.
typedef _Case = (DateTime today, String bound, String expected);

DateTime _d(int y, int m, int d) => DateTime(y, m, d);

/// Bounds used as `min`. The date field shows the resolved bound as "From x".
final List<_Case> _asMin = [
  (_d(2026, 10, 12), 'today', '2026-10-12'),
  (_d(2026, 10, 12), 'today+30d', '2026-11-11'),
  (_d(2026, 10, 12), 'today-30d', '2026-09-12'),
  (_d(2026, 10, 12), 'today + 2w', '2026-10-26'),
  (_d(2026, 10, 12), 'today-1w', '2026-10-05'),
  (_d(2026, 10, 12), 'today+0d', '2026-10-12'),
  (_d(2026, 10, 12), 'today+1m', '2026-11-12'),
  (_d(2026, 10, 12), 'today+1y', '2027-10-12'),
  (_d(2026, 10, 12), 'today-120y', '1906-10-12'),
  (_d(2026, 10, 12), 'today+1y-1d', '2027-10-11'),
  (_d(2026, 10, 12), 'thisMonth', '2026-10-01'),
  (_d(2026, 10, 12), 'thisMonth+1m', '2026-11-01'),
  (_d(2026, 10, 12), 'thisMonth-1m', '2026-09-01'),
  (_d(2026, 10, 12), 'thisMonth+1y', '2027-10-01'),
  (_d(2026, 10, 12), 'thisYear', '2026-01-01'),
  (_d(2026, 10, 12), 'thisYear-1y', '2025-01-01'),
  (_d(2026, 10, 12), 'thisYear+6m', '2026-07-01'),
  // A month or year shift keeps to the last day of a shorter month.
  (_d(2026, 1, 31), 'today+1m', '2026-02-28'),
  (_d(2028, 1, 31), 'today+1m', '2028-02-29'),
  (_d(2026, 3, 31), 'today-1m', '2026-02-28'),
  (_d(2028, 2, 29), 'today+1y', '2029-02-28'),
  (_d(2028, 2, 29), 'today-1y', '2027-02-28'),
  // Shifts cross year boundaries in both directions.
  (_d(2026, 12, 5), 'today+1m', '2027-01-05'),
  (_d(2026, 1, 15), 'today-2m', '2025-11-15'),
  (_d(2026, 12, 31), 'today+1d', '2027-01-01'),
  (_d(2026, 1, 1), 'today-1d', '2025-12-31'),
];

/// Bounds used as `max`. The date field shows the resolved bound as "Until x".
final List<_Case> _asMax = [
  (_d(2026, 10, 12), 'today', '2026-10-12'),
  (_d(2026, 10, 12), 'today-18y', '2008-10-12'),
  (_d(2026, 10, 12), 'today+1y-1d', '2027-10-11'),
  (_d(2026, 10, 12), 'thisMonth', '2026-10-31'),
  (_d(2026, 2, 10), 'thisMonth', '2026-02-28'),
  (_d(2028, 2, 10), 'thisMonth', '2028-02-29'),
  (_d(2026, 10, 12), 'thisMonth-1m', '2026-09-30'),
  // A month shift moves the whole month, so this is the end of next month.
  (_d(2026, 10, 12), 'thisMonth+1m', '2026-11-30'),
  (_d(2026, 12, 5), 'thisMonth+1m', '2027-01-31'),
  // Days apply to the resolved date, after the month has been settled.
  (_d(2026, 10, 12), 'thisMonth+1m+3d', '2026-12-03'),
  (_d(2026, 10, 12), 'thisYear', '2026-12-31'),
  (_d(2026, 10, 12), 'thisYear-1y', '2025-12-31'),
  (_d(2026, 10, 12), 'thisYear+1y', '2027-12-31'),
  // A month offset on a year applies to its end, not to the whole year.
  (_d(2026, 10, 12), 'thisYear+6m', '2027-06-30'),
  (_d(2026, 10, 12), 'thisYear+1d', '2027-01-01'),
];

const List<String> _malformed = [
  'today+',
  'today-',
  'today+30',
  'today+30x',
  'today+3q',
  'today30d',
  'today++1d',
  'today+-1d',
  'today+1d1d',
  'today+d',
  'today+1.5d',
  'today+123456d',
  'tomorrow',
  'thisweek',
  'Today',
  'THISYEAR',
  '+30d',
  '30d',
  '-1y',
  'now',
  '',
];

void main() {
  const input = JsonFormDateFieldInput();

  group('a bound as min', () {
    for (final c in _asMin) {
      testTall(
          '"${c.$2}" on ${c.$1.toIso8601String().substring(0, 10)} is '
          '${c.$3}', (tester) async {
        await pumpForm(
          tester,
          schema: formSchema([dateSpec('when', min: c.$2)]),
          inputs: clockInputs(() => c.$1),
        );

        expect(helperText(tester), 'From ${c.$3}');
      });
    }
  });

  group('a bound as max', () {
    for (final c in _asMax) {
      testTall(
          '"${c.$2}" on ${c.$1.toIso8601String().substring(0, 10)} is '
          '${c.$3}', (tester) async {
        await pumpForm(
          tester,
          schema: formSchema([dateSpec('when', max: c.$2)]),
          inputs: clockInputs(() => c.$1),
        );

        expect(helperText(tester), 'Until ${c.$3}');
      });
    }
  });

  group('both bounds together', () {
    testTall('the same word gives the whole month', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('when', min: 'thisMonth', max: 'thisMonth'),
        ]),
        inputs: clockInputs(() => DateTime(2026, 10, 12)),
      );

      expect(helperText(tester), '2026-10-01 to 2026-10-31');
    });

    testTall('the same word gives the whole year', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('when', min: 'thisYear', max: 'thisYear'),
        ]),
        inputs: clockInputs(() => DateTime(2026, 10, 12)),
      );

      expect(helperText(tester), '2026-01-01 to 2026-12-31');
    });

    testTall('an age window, in years ago', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('when', min: 'today-120y', max: 'today-18y'),
        ]),
        inputs: clockInputs(() => DateTime(2026, 10, 12)),
      );

      expect(helperText(tester), '1906-10-12 to 2008-10-12');
    });

    testTall('a fixed date can sit beside a relative one', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('when', min: '2026-01-01', max: 'today+30d'),
        ]),
        inputs: clockInputs(() => DateTime(2026, 10, 12)),
      );

      expect(helperText(tester), '2026-01-01 to 2026-11-11');
    });

    testTall('last year as both bounds', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('when', min: 'thisYear-1y', max: 'thisYear-1y'),
        ]),
        inputs: clockInputs(() => DateTime(2026, 10, 12)),
      );

      expect(helperText(tester), '2025-01-01 to 2025-12-31');
    });
  });

  group('malformed bounds', () {
    for (final bound in _malformed) {
      test('"$bound" as min is a FormatException', () {
        expect(
          () => input.validate(_spec({'min': bound})),
          throwsA(formatExceptionWith('"min" of "when" must be a date')),
        );
      });
    }

    test('"today+30" says what an offset looks like', () {
      expect(
        () => input.validate(_spec({'max': 'today+30'})),
        throwsA(formatExceptionWith('optionally followed by an offset')),
      );
    });

    test('an unknown unit is a FormatException', () {
      expect(
        () => input.validate(_spec({'max': 'today+3q'})),
        throwsFormatException,
      );
    });
  });

  group('words and offsets are exact', () {
    test('five digits are allowed and six are not', () {
      expect(
        () => input.validate(_spec({'max': 'today+99999d'})),
        returnsNormally,
      );
      expect(
        () => input.validate(_spec({'max': 'today+100000d'})),
        throwsFormatException,
      );
    });

    test('spaces anywhere are ignored', () {
      expect(
        () => input.validate(_spec({'max': ' today + 1 y - 2 d '})),
        returnsNormally,
      );
    });

    test('a fixed date is not mistaken for a word', () {
      expect(
        () => input.validate(_spec({'min': '2026-10-10'})),
        returnsNormally,
      );
    });
  });

  group('the clock', () {
    testTall('is read each time the bounds are used', (tester) async {
      var now = DateTime(2026, 10, 12);
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('gate'),
          dateSpec('when', min: 'today'),
          textSpec('x', visibleWhen: when('gate', true)),
        ]),
        inputs: clockInputs(() => now),
      );
      expect(helperText(tester), 'From 2026-10-12');

      now = DateTime(2026, 10, 13);
      await toggle(tester, 'gate');

      expect(helperText(tester), 'From 2026-10-13');
    });

    testTall('a time of day does not shift the date', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([dateSpec('when', min: 'today')]),
        inputs: clockInputs(() => DateTime(2026, 10, 12, 23, 59, 59)),
      );

      expect(helperText(tester), 'From 2026-10-12');
    });

    testTall('min after max is judged against the clock', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('when', min: 'today+1y', max: 'today'),
        ]),
        inputs: clockInputs(() => DateTime(2026, 10, 12)),
      );

      expect(
        tester.takeException(),
        formatExceptionWith(
          '"when" has min 2027-10-12 later than max 2026-10-12',
        ),
      );
    });

    testTall('a prefill is clamped to a relative bound', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          dateSpec('born', min: 'today-120y', max: 'today-18y'),
        ]),
        inputs: clockInputs(() => DateTime(2026, 10, 12)),
        initialValues: {'born': '2999-01-01'},
      );

      expect(fieldText(tester, 'born'), '2008-10-12');
    });
  });
}
