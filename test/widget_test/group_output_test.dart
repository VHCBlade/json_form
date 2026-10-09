import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_form/json_form.dart';

import '../helpers/form_test_helpers.dart';

/// A widget test on a tall screen, so nothing needs scrolling to be tapped.
void testTall(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    useTallView(tester);
    await body(tester);
  });
}

final _pets = formSchema([
  groupSpec(
    'pets',
    [textSpec('name')],
    output: 'list',
    label: 'Pets',
    addLabel: 'Add a pet',
  ),
]);

final _address = formSchema([
  groupSpec(
    'address',
    [textSpec('street'), textSpec('city')],
    output: 'object',
  ),
]);

void main() {
  group('object groups', () {
    testTall('nest their fields under the group key', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          textSpec('name'),
          groupSpec(
            'address',
            [textSpec('street'), textSpec('city')],
            output: 'object',
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(textField('name'), 'Ada');
      await tester.enterText(textField('street'), '1 Main');
      await tester.enterText(textField('city'), 'Springfield');
      await submit(tester);

      expect(submitted, {
        'name': 'Ada',
        'address': {'street': '1 Main', 'city': 'Springfield'},
      });
    });

    testTall('a flat group inside one nests into the object', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec(
            'address',
            [
              groupSpec('lines', [textSpec('street')]),
              textSpec('city'),
            ],
            output: 'object',
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(textField('street'), '1 Main');
      await tester.enterText(textField('city'), 'Springfield');
      await submit(tester);

      expect(submitted, {
        'address': {'street': '1 Main', 'city': 'Springfield'},
      });
    });

    testTall('a hidden one is absent from the output', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('gate'),
          groupSpec(
            'g',
            [textSpec('a')],
            output: 'object',
            visibleWhen: when('gate', true),
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {'gate': false});
    });

    testTall('a visible one with every field hidden is an empty object',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('gate'),
          groupSpec(
            'g',
            [textSpec('a', visibleWhen: when('gate', true))],
            output: 'object',
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {'gate': false, 'g': <String, dynamic>{}});
    });

    testTall('keeps what was typed across hide and show', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('gate'),
          groupSpec(
            'address',
            [textSpec('street')],
            output: 'object',
            visibleWhen: when('gate', true),
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await toggle(tester, 'gate');
      await tester.enterText(textField('street'), '1 Main');
      await toggle(tester, 'gate');
      expect(textField('street'), findsNothing);

      await toggle(tester, 'gate');
      expect(find.text('1 Main'), findsOneWidget);

      await submit(tester);
      expect(submitted, {
        'gate': true,
        'address': {'street': '1 Main'},
      });
    });

    testTall('a field inside can be conditional on one outside',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('extra'),
          groupSpec(
            'g',
            [textSpec('a'), textSpec('b', visibleWhen: when('extra', true))],
            output: 'object',
          ),
        ]),
      );

      expect(textField('b'), findsNothing);

      await toggle(tester, 'extra');
      expect(textField('b'), findsOneWidget);
    });

    testTall('the same key at the root and inside is kept apart',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          textSpec('name'),
          groupSpec('owner', [textSpec('name')], output: 'object'),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await tester.enterText(textFieldAt('name', 0), 'Ada');
      await tester.enterText(textFieldAt('name', 1), 'Grace');
      await submit(tester);

      expect(submitted, {
        'name': 'Ada',
        'owner': {'name': 'Grace'},
      });
    });

    testTall('an inner key shadows an outer one in conditions', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('flag'),
          groupSpec(
            'g',
            [
              checkboxSpec('flag'),
              textSpec('detail', visibleWhen: when('flag', true)),
            ],
            output: 'object',
          ),
        ]),
      );

      await toggleAt(tester, 'flag', 0);
      expect(textField('detail'), findsNothing);

      await toggleAt(tester, 'flag', 1);
      expect(textField('detail'), findsOneWidget);
    });
  });

  group('list groups', () {
    testTall('start empty, with a title and an add button', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(tester, schema: _pets, onSubmit: (v) => submitted = v);

      expect(find.text('Pets'), findsOneWidget);
      expect(find.text('Add a pet'), findsOneWidget);
      expect(find.text('Remove'), findsNothing);
      expect(textField('name'), findsNothing);

      await submit(tester);
      expect(submitted, {'pets': <Object?>[]});
    });

    testTall('the add button says "Add" unless told otherwise', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec('pets', [textSpec('name')], output: 'list'),
        ]),
      );

      expect(find.text('Add'), findsOneWidget);
    });

    testTall('submit one object per entry, in order', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(tester, schema: _pets, onSubmit: (v) => submitted = v);

      await addEntry(tester, 'Add a pet');
      await addEntry(tester, 'Add a pet');
      await tester.enterText(textFieldAt('name', 0), 'Biscuit');
      await tester.enterText(textFieldAt('name', 1), 'Miso');
      await submit(tester);

      expect(submitted, {
        'pets': [
          {'name': 'Biscuit'},
          {'name': 'Miso'},
        ],
      });
    });

    testTall('entries are independent', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(tester, schema: _pets, onSubmit: (v) => submitted = v);

      await addEntry(tester, 'Add a pet');
      await addEntry(tester, 'Add a pet');
      await tester.enterText(textFieldAt('name', 0), 'Biscuit');
      await submit(tester);

      expect(submitted, {
        'pets': [
          {'name': 'Biscuit'},
          {'name': ''},
        ],
      });
    });

    testTall('removing an entry removes that one', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(tester, schema: _pets, onSubmit: (v) => submitted = v);
      for (var i = 0; i < 3; i++) {
        await addEntry(tester, 'Add a pet');
      }
      await tester.enterText(textFieldAt('name', 0), 'A');
      await tester.enterText(textFieldAt('name', 1), 'B');
      await tester.enterText(textFieldAt('name', 2), 'C');

      await removeEntry(tester, 1);

      expect(find.text('B'), findsNothing);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      await submit(tester);
      expect(submitted, {
        'pets': [
          {'name': 'A'},
          {'name': 'C'},
        ],
      });
    });

    testTall('removing the first entry leaves the others\' text alone',
        (tester) async {
      await pumpForm(tester, schema: _pets);
      for (var i = 0; i < 3; i++) {
        await addEntry(tester, 'Add a pet');
      }
      await tester.enterText(textFieldAt('name', 0), 'A');
      await tester.enterText(textFieldAt('name', 1), 'B');
      await tester.enterText(textFieldAt('name', 2), 'C');

      await removeEntry(tester, 0);

      expect(find.text('A'), findsNothing);
      expect(textFieldAt('name', 0), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testTall('removing every entry leaves an empty list', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(tester, schema: _pets, onSubmit: (v) => submitted = v);
      await addEntry(tester, 'Add a pet');
      await addEntry(tester, 'Add a pet');

      await removeEntry(tester, 0);
      await removeEntry(tester, 0);
      await submit(tester);

      expect(submitted, {'pets': <Object?>[]});
    });

    testTall('a required field in an entry blocks submit for that entry',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec(
            'pets',
            [textSpec('name', required: true)],
            output: 'list',
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );
      await addEntry(tester);
      await addEntry(tester);
      await tester.enterText(textFieldAt('name', 0), 'Biscuit');

      await submit(tester);
      expect(submitted, isNull);
      expect(find.text('Required'), findsOneWidget);

      await removeEntry(tester, 1);
      await submit(tester);
      expect(submitted, {
        'pets': [
          {'name': 'Biscuit'},
        ],
      });
    });

    testTall('a hidden list group is absent and keeps its entries',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('gate'),
          groupSpec(
            'pets',
            [textSpec('name')],
            output: 'list',
            visibleWhen: when('gate', true),
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );

      await toggle(tester, 'gate');
      await addEntry(tester);
      await addEntry(tester);
      await tester.enterText(textFieldAt('name', 0), 'A');
      await tester.enterText(textFieldAt('name', 1), 'B');

      await toggle(tester, 'gate');
      expect(textField('name'), findsNothing);
      await submit(tester);
      expect(submitted, {'gate': false});

      await toggle(tester, 'gate');
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testTall('each entry has its own conditions', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec(
            'pets',
            [
              checkboxSpec('vaccinated'),
              textSpec('vaccineDate', visibleWhen: when('vaccinated', true)),
            ],
            output: 'list',
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );
      await addEntry(tester);
      await addEntry(tester);
      expect(textField('vaccineDate'), findsNothing);

      await toggleAt(tester, 'vaccinated', 0);
      expect(textField('vaccineDate'), findsNWidgets(1));

      await toggleAt(tester, 'vaccinated', 1);
      expect(textField('vaccineDate'), findsNWidgets(2));

      await toggleAt(tester, 'vaccinated', 0);
      expect(textField('vaccineDate'), findsNWidgets(1));

      await tester.enterText(textField('vaccineDate'), '2026-01-10');
      await submit(tester);
      expect(submitted, {
        'pets': [
          {'vaccinated': false},
          {'vaccinated': true, 'vaccineDate': '2026-01-10'},
        ],
      });
    });

    testTall('a condition can read the scope around the list', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('giftOrder'),
          groupSpec(
            'lines',
            [
              textSpec('sku'),
              checkboxSpec('giftWrap', visibleWhen: when('giftOrder', true)),
            ],
            output: 'list',
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );
      await addEntry(tester);
      await addEntry(tester);
      expect(checkboxTile('giftWrap'), findsNothing);

      await toggle(tester, 'giftOrder');
      expect(checkboxTile('giftWrap'), findsNWidgets(2));

      await toggleAt(tester, 'giftWrap', 1);
      await submit(tester);
      expect(submitted, {
        'giftOrder': true,
        'lines': [
          {'sku': '', 'giftWrap': false},
          {'sku': '', 'giftWrap': true},
        ],
      });
    });

    testTall('an entry\'s key shadows an outer one in conditions',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('flag'),
          groupSpec(
            'items',
            [
              checkboxSpec('flag'),
              textSpec('detail', visibleWhen: when('flag', true)),
            ],
            output: 'list',
          ),
        ]),
      );
      await addEntry(tester);

      await toggleAt(tester, 'flag', 0);
      expect(textField('detail'), findsNothing);

      await toggleAt(tester, 'flag', 1);
      expect(textField('detail'), findsOneWidget);
    });

    testTall('the same key at the root and in an entry is kept apart',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          textSpec('name'),
          groupSpec('pets', [textSpec('name')], output: 'list'),
        ]),
        onSubmit: (v) => submitted = v,
      );
      await addEntry(tester);

      await tester.enterText(textFieldAt('name', 0), 'Ada');
      await tester.enterText(textFieldAt('name', 1), 'Biscuit');
      await submit(tester);

      expect(submitted, {
        'name': 'Ada',
        'pets': [
          {'name': 'Biscuit'},
        ],
      });
    });

    testTall('an object inside an entry nests in that entry', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec(
            'pets',
            [
              textSpec('name'),
              groupSpec('vet', [textSpec('clinic')], output: 'object'),
            ],
            output: 'list',
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );
      await addEntry(tester);
      await addEntry(tester);

      await tester.enterText(textFieldAt('name', 0), 'Biscuit');
      await tester.enterText(textFieldAt('clinic', 0), 'North');
      await tester.enterText(textFieldAt('name', 1), 'Miso');
      await tester.enterText(textFieldAt('clinic', 1), 'South');
      await submit(tester);

      expect(submitted, {
        'pets': [
          {
            'name': 'Biscuit',
            'vet': {'clinic': 'North'},
          },
          {
            'name': 'Miso',
            'vet': {'clinic': 'South'},
          },
        ],
      });
    });

    testTall('a list inside an object nests in the object', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec(
            'household',
            [
              textSpec('surname'),
              groupSpec(
                'members',
                [textSpec('name')],
                output: 'list',
                addLabel: 'Add member',
              ),
            ],
            output: 'object',
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );
      await addEntry(tester, 'Add member');

      await tester.enterText(textField('surname'), 'Lovelace');
      await tester.enterText(textField('name'), 'Ada');
      await submit(tester);

      expect(submitted, {
        'household': {
          'surname': 'Lovelace',
          'members': [
            {'name': 'Ada'},
          ],
        },
      });
    });

    testTall('a list inside a list keeps each entry\'s own entries',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec(
            'orders',
            [
              textSpec('id'),
              groupSpec(
                'lines',
                [textSpec('sku')],
                output: 'list',
                addLabel: 'Add line',
              ),
            ],
            output: 'list',
            addLabel: 'Add order',
          ),
        ]),
        onSubmit: (v) => submitted = v,
      );
      await addEntry(tester, 'Add order');
      await addEntry(tester, 'Add order');
      await tester.tap(find.text('Add line').at(0));
      await tester.pump();

      await tester.enterText(textFieldAt('id', 0), '1');
      await tester.enterText(textFieldAt('id', 1), '2');
      await tester.enterText(textField('sku'), 'a');
      await submit(tester);

      expect(submitted, {
        'orders': [
          {
            'id': '1',
            'lines': [
              {'sku': 'a'},
            ],
          },
          {'id': '2', 'lines': <Object?>[]},
        ],
      });
    });
  });

  group('list bounds', () {
    final bounded = formSchema([
      groupSpec(
        'pets',
        [textSpec('name')],
        output: 'list',
        minItems: 2,
        maxItems: 3,
      ),
    ]);

    testTall('start with minItems entries', (tester) async {
      await pumpForm(tester, schema: bounded);

      expect(textField('name'), findsNWidgets(2));
    });

    testTall('remove is disabled at the minimum and enabled above it',
        (tester) async {
      await pumpForm(tester, schema: bounded);
      expect(buttonDisabled(tester, 'Remove', index: 0), isTrue);
      expect(buttonDisabled(tester, 'Remove', index: 1), isTrue);

      await addEntry(tester);

      expect(buttonDisabled(tester, 'Remove', index: 0), isFalse);
      expect(buttonDisabled(tester, 'Remove', index: 2), isFalse);
    });

    testTall('removing at the minimum does nothing', (tester) async {
      await pumpForm(tester, schema: bounded);

      await removeEntry(tester, 0);

      expect(textField('name'), findsNWidgets(2));
    });

    testTall('add is disabled at the maximum and returns after a removal',
        (tester) async {
      await pumpForm(tester, schema: bounded);
      expect(buttonDisabled(tester, 'Add'), isFalse);

      await addEntry(tester);
      expect(textField('name'), findsNWidgets(3));
      expect(buttonDisabled(tester, 'Add'), isTrue);

      await removeEntry(tester, 0);
      expect(buttonDisabled(tester, 'Add'), isFalse);
    });

    testTall('adding at the maximum does nothing', (tester) async {
      await pumpForm(tester, schema: bounded);
      await addEntry(tester);

      await addEntry(tester);

      expect(textField('name'), findsNWidgets(3));
    });

    testTall('with no bounds, add and remove are always enabled',
        (tester) async {
      await pumpForm(tester, schema: _pets);
      await addEntry(tester, 'Add a pet');

      expect(buttonDisabled(tester, 'Add a pet'), isFalse);
      expect(buttonDisabled(tester, 'Remove'), isFalse);
    });
  });

  group('initial values', () {
    testTall('an object group reads an object', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: _address,
        initialValues: {
          'address': {'street': '1 Main', 'city': 'Springfield'},
        },
        onSubmit: (v) => submitted = v,
      );

      expect(find.text('1 Main'), findsOneWidget);
      expect(find.text('Springfield'), findsOneWidget);
      await submit(tester);
      expect(submitted, {
        'address': {'street': '1 Main', 'city': 'Springfield'},
      });
    });

    testTall('a list group creates an entry per element', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: _pets,
        initialValues: {
          'pets': [
            {'name': 'Biscuit'},
            {'name': 'Miso'},
          ],
        },
        onSubmit: (v) => submitted = v,
      );

      expect(textField('name'), findsNWidgets(2));
      expect(find.text('Biscuit'), findsOneWidget);
      expect(find.text('Miso'), findsOneWidget);
      await submit(tester);
      expect(submitted, {
        'pets': [
          {'name': 'Biscuit'},
          {'name': 'Miso'},
        ],
      });
    });

    testTall('a JSON string works for nested values too', (tester) async {
      await pumpForm(
        tester,
        schema: _pets,
        initialValues: '{"pets": [{"name": "Biscuit"}]}',
      );

      expect(find.text('Biscuit'), findsOneWidget);
    });

    testTall('a flat group inside an object group reads from the object',
        (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec(
            'address',
            [
              groupSpec('lines', [textSpec('street')]),
              textSpec('city'),
            ],
            output: 'object',
          ),
        ]),
        initialValues: {
          'address': {'street': '1 Main', 'city': 'Springfield'},
        },
      );

      expect(find.text('1 Main'), findsOneWidget);
      expect(find.text('Springfield'), findsOneWidget);
    });

    testTall('an object inside an entry reads from that entry', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec(
            'pets',
            [
              textSpec('name'),
              groupSpec('vet', [textSpec('clinic')], output: 'object'),
            ],
            output: 'list',
          ),
        ]),
        initialValues: {
          'pets': [
            {
              'name': 'Biscuit',
              'vet': {'clinic': 'North'},
            },
          ],
        },
      );

      expect(find.text('Biscuit'), findsOneWidget);
      expect(find.text('North'), findsOneWidget);
    });

    testTall('a submitted result can be fed straight back in', (tester) async {
      final schema = formSchema([
        textSpec('owner'),
        groupSpec(
          'address',
          [textSpec('street'), textSpec('city')],
          output: 'object',
        ),
        groupSpec(
          'pets',
          [
            textSpec('name'),
            groupSpec('vet', [textSpec('clinic')], output: 'object'),
          ],
          output: 'list',
        ),
      ]);
      const initial = {
        'owner': 'Ada',
        'address': {'street': '1 Main', 'city': 'Springfield'},
        'pets': [
          {
            'name': 'Biscuit',
            'vet': {'clinic': 'North'},
          },
          {
            'name': 'Miso',
            'vet': {'clinic': 'South'},
          },
        ],
      };
      Map<String, dynamic>? first;
      Map<String, dynamic>? second;

      await pumpForm(
        tester,
        schema: schema,
        initialValues: initial,
        onSubmit: (v) => first = v,
      );
      await submit(tester);
      await pumpForm(
        tester,
        schema: schema,
        initialValues: first,
        formKey: const ValueKey('again'),
        onSubmit: (v) => second = v,
      );
      await submit(tester);

      expect(first, initial);
      expect(second, first);
    });

    testTall('a list is padded with empty entries up to minItems',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec('pets', [textSpec('name')], output: 'list', minItems: 2),
        ]),
        initialValues: {
          'pets': [
            {'name': 'A'},
          ],
        },
        onSubmit: (v) => submitted = v,
      );

      expect(textField('name'), findsNWidgets(2));
      await submit(tester);
      expect(submitted, {
        'pets': [
          {'name': 'A'},
          {'name': ''},
        ],
      });
    });

    testTall('a list longer than maxItems keeps every entry', (tester) async {
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec('pets', [textSpec('name')], output: 'list', maxItems: 2),
        ]),
        initialValues: {
          'pets': [
            {'name': 'A'},
            {'name': 'B'},
            {'name': 'C'},
          ],
        },
      );

      expect(textField('name'), findsNWidgets(3));
      expect(buttonDisabled(tester, 'Add'), isTrue);
    });

    testTall('keys that match no field are ignored inside objects and entries',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec('address', [textSpec('street')], output: 'object'),
          groupSpec('pets', [textSpec('name')], output: 'list'),
        ]),
        initialValues: {
          'address': {'street': '1 Main', 'stale': true},
          'pets': [
            {'name': 'A', 'stale': 1},
          ],
        },
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {
        'address': {'street': '1 Main'},
        'pets': [
          {'name': 'A'},
        ],
      });
    });

    testTall('an object group given a non-object counts as empty',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: _address,
        initialValues: {'address': 'nope'},
        onSubmit: (v) => submitted = v,
      );

      expect(tester.takeException(), isNull);
      await submit(tester);
      expect(submitted, {
        'address': {'street': '', 'city': ''},
      });
    });

    testTall('a list group given a non-list has no entries', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: _pets,
        initialValues: {'pets': 'nope'},
        onSubmit: (v) => submitted = v,
      );

      expect(tester.takeException(), isNull);
      await submit(tester);
      expect(submitted, {'pets': <Object?>[]});
    });

    testTall('a list element that is not an object becomes an empty entry',
        (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: _pets,
        initialValues: {
          'pets': [
            'x',
            {'name': 'A'},
          ],
        },
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      expect(submitted, {
        'pets': [
          {'name': ''},
          {'name': 'A'},
        ],
      });
    });
  });

  group('output', () {
    testTall('is unmodifiable all the way down', (tester) async {
      Map<String, dynamic>? submitted;
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec('address', [textSpec('street')], output: 'object'),
          groupSpec('pets', [textSpec('name')], output: 'list'),
        ]),
        initialValues: {
          'pets': [
            {'name': 'A'},
          ],
        },
        onSubmit: (v) => submitted = v,
      );

      await submit(tester);

      final address = submitted!['address'] as Map<String, dynamic>;
      final pets = submitted!['pets'] as List;
      final entry = pets.first as Map<String, dynamic>;
      expect(() => submitted!['x'] = 1, throwsUnsupportedError);
      expect(() => address['x'] = 1, throwsUnsupportedError);
      expect(() => pets.add(1), throwsUnsupportedError);
      expect(() => entry['x'] = 1, throwsUnsupportedError);
    });
  });

  group('JsonFormController with groups', () {
    testTall('collects the nested structure without validating',
        (tester) async {
      final controller = JsonFormController();
      await pumpForm(
        tester,
        schema: formSchema([
          groupSpec('address', [textSpec('street')], output: 'object'),
          groupSpec(
            'pets',
            [textSpec('name', required: true)],
            output: 'list',
          ),
        ]),
        controller: controller,
      );
      await addEntry(tester);

      expect(controller.collectValues(), {
        'address': {'street': ''},
        'pets': [
          {'name': ''},
        ],
      });
      await tester.pump();
      expect(find.text('Required'), findsNothing);
    });

    testTall('reflects changes made between calls', (tester) async {
      final controller = JsonFormController();
      await pumpForm(tester, schema: _pets, controller: controller);
      await addEntry(tester, 'Add a pet');

      await tester.enterText(textField('name'), 'A');
      expect(controller.collectValues(), {
        'pets': [
          {'name': 'A'},
        ],
      });

      await tester.enterText(textField('name'), 'B');
      await addEntry(tester, 'Add a pet');
      expect(controller.collectValues(), {
        'pets': [
          {'name': 'B'},
          {'name': ''},
        ],
      });
    });

    testTall('leaves out hidden groups', (tester) async {
      final controller = JsonFormController();
      await pumpForm(
        tester,
        schema: formSchema([
          checkboxSpec('gate'),
          groupSpec(
            'pets',
            [textSpec('name')],
            output: 'list',
            visibleWhen: when('gate', true),
          ),
        ]),
        controller: controller,
      );

      expect(controller.collectValues(), {'gate': false});
    });
  });
}
