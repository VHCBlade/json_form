import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:json_form/json_form.dart';

// ---------------------------------------------------------------------------
// Schema builders. Every field's label is its key, so a finder can look a
// field up by the same string used to declare it.
// ---------------------------------------------------------------------------

Map<String, dynamic> formSchema(List<Map<String, dynamic>> fields) =>
    {'fields': fields};

Map<String, dynamic> when(String field, bool equals) =>
    {'field': field, 'equals': equals};

Map<String, dynamic> textSpec(
  String key, {
  bool required = false,
  Map<String, dynamic>? visibleWhen,
}) =>
    {
      'key': key,
      'type': 'text',
      'label': key,
      if (required) 'required': true,
      if (visibleWhen != null) 'visibleWhen': visibleWhen,
    };

Map<String, dynamic> checkboxSpec(
  String key, {
  bool required = false,
  Map<String, dynamic>? visibleWhen,
}) =>
    {
      'key': key,
      'type': 'checkbox',
      'label': key,
      if (required) 'required': true,
      if (visibleWhen != null) 'visibleWhen': visibleWhen,
    };

Map<String, dynamic> dropdownSpec(
  String key, {
  List<Object>? options,
  String? optionsSource,
  bool required = false,
  Map<String, dynamic>? visibleWhen,
}) =>
    {
      'key': key,
      'type': 'dropdown',
      'label': key,
      if (options != null) 'options': options,
      if (optionsSource != null) 'optionsSource': optionsSource,
      if (required) 'required': true,
      if (visibleWhen != null) 'visibleWhen': visibleWhen,
    };

Map<String, dynamic> groupSpec(
  String key,
  List<Map<String, dynamic>> fields, {
  Map<String, dynamic>? visibleWhen,
  String? output,
  String? label,
  int? minItems,
  int? maxItems,
  String? addLabel,
}) =>
    {
      'key': key,
      'type': 'group',
      if (output != null) 'output': output,
      if (label != null) 'label': label,
      if (minItems != null) 'minItems': minItems,
      if (maxItems != null) 'maxItems': maxItems,
      if (addLabel != null) 'addLabel': addLabel,
      if (visibleWhen != null) 'visibleWhen': visibleWhen,
      'fields': fields,
    };

// ---------------------------------------------------------------------------
// Pumping and interaction.
// ---------------------------------------------------------------------------

/// Pumps a [JsonForm] inside a scrollable, so tall forms never overflow the
/// test viewport.
Future<void> pumpForm(
  WidgetTester tester, {
  required Map<String, dynamic> schema,
  void Function(Map<String, dynamic> values)? onSubmit,
  Object? initialValues,
  List<JsonFormFieldInput> inputs = JsonForm.defaultInputs,
  JsonFormController? controller,
  Key? formKey,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: JsonForm(
            key: formKey,
            schema: schema,
            inputs: inputs,
            initialValues: initialValues,
            controller: controller,
            onSubmit: onSubmit ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

Finder textField(String key) => find.widgetWithText(TextFormField, key);

Finder checkboxTile(String key) => find.widgetWithText(CheckboxListTile, key);

bool isChecked(WidgetTester tester, String key) =>
    tester.widget<CheckboxListTile>(checkboxTile(key)).value ?? false;

Future<void> toggle(WidgetTester tester, String key) async {
  await tester.tap(checkboxTile(key));
  await tester.pump();
}

Future<void> submit(WidgetTester tester) async {
  await tester.tap(find.text('Submit'));
  await tester.pump();
}

final Finder dropdownField = find.byType(DropdownButtonFormField<Object>);

/// Opens the (single) dropdown and picks the item labelled [label].
Future<void> choose(WidgetTester tester, String label) async {
  await tester.tap(dropdownField);
  await tester.pumpAndSettle();
  // The open menu is later in the tree than the field's own copy of the
  // selected label, so .last is the menu entry.
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// A [FormatException] whose message contains [part].
Matcher formatExceptionWith(String part) =>
    isA<FormatException>().having((e) => e.message, 'message', contains(part));

Map<String, dynamic> integerSpec(
  String key, {
  int? min,
  int? max,
  bool required = false,
  Map<String, dynamic>? visibleWhen,
}) =>
    {
      'key': key,
      'type': 'integer',
      'label': key,
      if (min != null) 'min': min,
      if (max != null) 'max': max,
      if (required) 'required': true,
      if (visibleWhen != null) 'visibleWhen': visibleWhen,
    };

/// Moves focus away from whatever has it, as tapping elsewhere would.
Future<void> blur(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

/// The text currently in the text field labelled [key].
String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(textField(key)).controller!.text;

// ---------------------------------------------------------------------------
// List groups.
// ---------------------------------------------------------------------------

Future<void> addEntry(WidgetTester tester, [String label = 'Add']) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

Future<void> removeEntry(WidgetTester tester, int index) async {
  await tester.tap(find.text('Remove').at(index));
  await tester.pump();
}

/// The [index]th text field labelled [key], for keys used in several entries.
Finder textFieldAt(String key, int index) => textField(key).at(index);

Finder checkboxTileAt(String key, int index) => checkboxTile(key).at(index);

Future<void> toggleAt(WidgetTester tester, String key, int index) async {
  await tester.tap(checkboxTileAt(key, index));
  await tester.pump();
}

/// Whether the [index]th button labelled [label] is disabled.
bool buttonDisabled(WidgetTester tester, String label, {int index = 0}) {
  final button = find.ancestor(
    of: find.text(label).at(index),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  return tester.widget<ButtonStyleButton>(button.first).onPressed == null;
}

/// Makes the test screen tall, so forms with several entries need no
/// scrolling before something can be tapped.
void useTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 3000);
  addTearDown(tester.view.reset);
}
