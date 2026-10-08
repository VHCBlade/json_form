import 'package:flutter_test/flutter_test.dart';

import 'package:json_form/json_form.dart';

FieldSpec _dropdown(List<Object> options) => FieldSpec.fromJson({
      'key': 'size',
      'type': 'dropdown',
      'options': options,
    });

void main() {
  group('JsonFormInlineOptionsSource', () {
    const source = JsonFormInlineOptionsSource();

    test('loads string options in order', () async {
      final options =
          await source.load(_dropdown(['Small', 'Medium', 'Large']));

      expect(options.map((o) => o.value), ['Small', 'Medium', 'Large']);
      expect(options.map((o) => o.label), ['Small', 'Medium', 'Large']);
    });

    test('loads a mix of strings, numbers and maps', () async {
      final options = await source.load(
        _dropdown([
          'Small',
          {'value': 'usr', 'label': 'User'},
          3,
        ]),
      );

      expect(options.map((o) => o.value), ['Small', 'usr', 3]);
      expect(options.map((o) => o.label), ['Small', 'User', '3']);
    });

    test('an empty list yields no options', () async {
      expect(await source.load(_dropdown([])), isEmpty);
    });

    test('reads only the options of the spec it is given', () async {
      final first = await source.load(_dropdown(['a']));
      final second = await source.load(_dropdown(['b', 'c']));

      expect(first.map((o) => o.value), ['a']);
      expect(second.map((o) => o.value), ['b', 'c']);
    });

    test('returns a list that completes as a Future', () {
      expect(
        source.load(_dropdown(['a'])),
        completion(isA<List<JsonFormOption>>()),
      );
    });
  });
}
