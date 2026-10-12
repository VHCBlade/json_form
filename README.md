# json_form

A Flutter package that turns a JSON description into a working form and hands
the answers back as JSON.

```
JSON schema  ->  JsonForm widget  ->  user fills it in  ->  JSON output
```

- Fields: text (single or multiline), integer with clamping, checkbox, dropdown.
- Groups that keep their fields flat, nest them as an object, or repeat them as
  a list the user adds to and removes from.
- Fields and groups that appear only when another field has a given value.
- Dropdown options from the schema itself or from a source you supply.
- Prefill from a previous result, as a decoded object or a JSON string.
- A controller to read the current values at any time, valid or not.
- Schema validation that runs without building any widgets.
- Your own field types, registered alongside the built-in ones.

> **Status:** pre-release. The API may still change.

## Contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [The schema](#the-schema)
- [Conditional visibility](#conditional-visibility)
- [The output](#the-output)
- [Prefilling](#prefilling)
- [Reading values without submitting](#reading-values-without-submitting)
- [Validating a schema](#validating-a-schema)
- [Extending](#extending)
- [Example app and sample schemas](#example-app-and-sample-schemas)
- [Tests](#tests)
- [Limits and things to know](#limits-and-things-to-know)
- [Source layout](#source-layout)

## Installation

The package is not published yet. Add it as a path or git dependency.

```yaml
dependencies:
  json_form:
    path: ../json_form
```

It uses Dart 3 features (records, sealed classes, pattern matching) and
Material 3 widgets, so it needs a recent Flutter. The dropdown passes
`initialValue` to `DropdownButtonFormField`, which older SDKs call `value`.

## Quick start

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:json_form/json_form.dart';

const schema = {
  'fields': [
    {'key': 'name', 'type': 'text', 'label': 'Name', 'required': true},
    {'key': 'age', 'type': 'integer', 'label': 'Age', 'min': 18, 'max': 120},
    {'key': 'newsletter', 'type': 'checkbox', 'label': 'Send me the newsletter'},
  ],
};

class SignUp extends StatelessWidget {
  const SignUp({super.key});

  @override
  Widget build(BuildContext context) {
    return JsonForm(
      schema: schema,
      onSubmit: (values) => debugPrint(jsonEncode(values)),
    );
  }
}
```

Pressing **Submit** validates the visible fields. If they are all valid,
`onSubmit` receives a map such as
`{"name": "Ada", "age": 36, "newsletter": true}`.

A schema often arrives as text. Decode it first:

```dart
final schema = jsonDecode(text) as Map<String, dynamic>;
```

## The schema

A schema is an object with a `fields` list. Every field has these properties:

| Property | Type | Meaning |
| --- | --- | --- |
| `key` | string, required | Names the field in the output. |
| `type` | string, required | `text`, `integer`, `checkbox`, `dropdown`, `group`, or a type you register. |
| `label` | string | Shown with the field. Defaults to the key. |
| `required` | boolean | See each type below, since "required" means something different for a checkbox. |
| `visibleWhen` | object | Shows the field only under a condition. See [Conditional visibility](#conditional-visibility). |

A `label` or `required` of the wrong type is an error, not something that is
quietly ignored. Properties the package does not know are ignored, so a
misspelled option fails silently. Run the schema through
[validation](#validating-a-schema) when it comes from outside your code.

### text

```json
{ "key": "notes", "type": "text", "label": "Notes", "minLines": 3, "maxLines": 8 }
```

`required` means the value is not empty after trimming whitespace.

`minLines` and `maxLines` are positive whole numbers that behave like
`TextField`'s:

| Schema | Result |
| --- | --- |
| neither | One line. |
| `maxLines: n` | Starts one line tall, grows to `n` lines, then scrolls. |
| `minLines: m`, `maxLines: n` | Starts `m` lines tall, grows to `n`. |
| `minLines: m` alone | Starts `m` lines tall and grows without limit. |
| `minLines: n`, `maxLines: n` | A fixed `n`-line box. |

`TextField` would reject `minLines` alone against its default `maxLines` of 1.
Here it means no upper limit. A field that can grow past one line is a text
area, so Enter inserts a newline. `minLines` cannot exceed `maxLines`.

Output: a string, `""` if the field was left empty.

### integer

```json
{ "key": "age", "type": "integer", "label": "Age", "min": 18, "max": 120, "required": true }
```

`min` and `max` are optional whole numbers (whole-valued doubles such as `5.0`
are accepted). Anything outside the range is clamped to the nearest bound.

- **Clamping happens when the field loses focus**, not while typing. Clamping
  each keystroke would make a minimum unusable: with `min: 18`, the "2" of
  "25" would jump to 18 before you could type the "5".
- **The value the form reports and saves is always clamped**, even before the
  text has been tidied. Conditions also see the clamped value.
- Typing is limited to digits, plus a leading minus when `min` is absent or
  negative.
- A range hint ("18 to 120", "Minimum 18", "Maximum 10") appears under the
  field.
- Leading zeros are tidied on blur: `0030` becomes `30`.

Output: an `int`, or `null` if empty. A required empty field shows "Required".
A lone `-` shows "Enter a whole number".

### checkbox

```json
{ "key": "terms", "type": "checkbox", "label": "I accept the terms", "required": true }
```

Output: a `bool`. An untouched checkbox is `false`. **`required` means the box
must be ticked**, so use it for agreements only.

### dropdown

```json
{ "key": "size", "type": "dropdown", "label": "Size", "options": ["Small", "Medium", "Large"] }

{ "key": "role", "type": "dropdown", "label": "Role",
  "options": [ { "value": "adm", "label": "Administrator" }, { "value": "usr", "label": "User" } ] }

{ "key": "country", "type": "dropdown", "label": "Country", "optionsSource": "countries" }
```

An option is a string or number (used as both value and label) or an object
with a `value` and an optional `label`. Either `options` or `optionsSource`
is required. If both are present, the source wins.

`optionsSource` names a source you register. See
[Options sources](#options-sources).

- The field is disabled while options load. If loading fails it shows
  "Failed to load options" and stays disabled.
- Options are loaded once per field, however often the form rebuilds.
- A prefilled value is applied after the options arrive. A value that is not
  among the options is ignored.

Output: the selected option's `value`, or `null`.

### group

A group holds other fields. What it does to the output depends on `output`.

```json
{ "key": "address", "type": "group", "output": "object",
  "fields": [ { "key": "street", "type": "text" }, { "key": "city", "type": "text" } ] }

{ "key": "pets", "type": "group", "output": "list", "label": "Pets",
  "addLabel": "Add a pet", "minItems": 1, "maxItems": 5,
  "fields": [ { "key": "name", "type": "text" }, { "key": "vaccinated", "type": "checkbox" } ] }
```

| `output` | The group's fields appear in the output as |
| --- | --- |
| `flat` (the default) | Siblings of the group, as if it were not there. Useful for showing or hiding several fields with one condition. |
| `object` | An object stored under the group's key. |
| `list` | A list stored under the group's key, with one object per entry the user adds. |

For list groups:

| Property | Meaning |
| --- | --- |
| `minItems` | Fewest entries. The form starts with at least this many. Default 0. |
| `maxItems` | Most entries, if any. Must be at least 1. |
| `addLabel` | Text of the add button. Default "Add". |
| `label` | A title above the entries. |

Each entry is a card with its own fields and a Remove button. The Add button is
disabled at `maxItems` and Remove is disabled at `minItems`. A list that
starts at zero entries submits `[]`.

Groups nest freely, in any combination.

**Scopes.** Keys must be unique within one output object. A flat group shares
the scope around it. An object group, and each list entry, starts a new one,
so `name` can appear at the root and inside every pet. Duplicate keys within
a scope are an error.

## Conditional visibility

```json
{ "key": "hasPet", "type": "checkbox", "label": "I have a pet" },
{ "key": "petName", "type": "text", "label": "Pet name", "required": true,
  "visibleWhen": { "field": "hasPet", "equals": true } },
{ "key": "wantsPet", "type": "text", "label": "Would you like one?",
  "visibleWhen": { "field": "hasPet", "equals": false } }
```

Any field or group can carry `visibleWhen`. The only condition so far is
`equals`, which compares with Dart's `==`:

- `1` equals `1.0`, so a number that went through JSON still matches.
- A missing or hidden field matches nothing except `null`. In particular it
  does not match `false`.
- Lists and maps are compared by identity, so they never match.

**Rules**

- A condition can read a field declared earlier in its own scope or in an
  enclosing one. The nearest scope wins if the key exists in several.
- It cannot read into an object group or a list entry from outside.
- A condition on a field declared later is an error, which also rules out
  cycles.

**Behavior**

- A hidden field is not built, so it is skipped by validation and absent from
  the output. A hidden required field never blocks submit.
- A hidden field counts as absent to every later condition, so hiding
  cascades: if B depends on A and C depends on B, hiding A hides both.
- What the user entered is kept while a field or group is hidden, and comes
  back when it is shown again.
- A hidden object group is absent from the output. A visible one is always
  present, as `{}` if all its fields are hidden.

Conditions on a dropdown are unreliable. See
[Limits](#limits-and-things-to-know).

## The output

`onSubmit` receives a `Map<String, dynamic>` that `jsonEncode` accepts. It is
unmodifiable all the way down.

| Source | Value |
| --- | --- |
| text | `String` (`""` if empty) |
| integer | `int`, or `null` |
| checkbox | `bool` |
| dropdown | the option's `value`, or `null` |
| flat group | its fields, merged into the parent |
| object group | `{...}` |
| list group | `[{...}, {...}]` |

Hidden fields and groups are absent. Every visible field is present, even
when empty, so the shape does not depend on what the user touched.

## Prefilling

```dart
JsonForm(schema: schema, initialValues: previousResult, onSubmit: save);
JsonForm(schema: schema, initialValues: '{"name": "Ada"}', onSubmit: save);
```

`initialValues` is a decoded object or a JSON string. It has the shape of the
output: an object group reads an object and a list group reads a list of
objects. A submitted result can be fed straight back in.

- Keys and entries that match nothing are ignored.
- Values are not coerced. A string `"5"` leaves an integer field empty and
  `"true"` leaves a checkbox unticked. A whole-valued double (`5.0`) is
  accepted as an integer.
- An out-of-range integer is clamped.
- A nested value of the wrong shape counts as absent: a string where an object
  group expects an object, or a list element that is not an object (which
  becomes an empty entry).
- A list is padded with empty entries up to `minItems`. One longer than
  `maxItems` keeps every entry and disables Add.
- Invalid JSON text, or valid JSON that is not an object, throws a
  `FormatException`.

## Reading values without submitting

`JsonFormController` returns the current values without validating, which suits
saving a draft.

```dart
final controller = JsonFormController();

JsonForm(controller: controller, schema: schema, onSubmit: submit);

final draft = controller.collectValues(); // valid or not
```

The result has the same shape as the output, with hidden fields left out.
Calling it with no form attached throws a `StateError`. A required field that
is empty simply comes back empty.

## Validating a schema

Schema errors throw a `FormatException` when the form first builds. To check a
schema without building a widget, for instance before accepting it from a
user:

```dart
try {
  JsonForm.validateSchema(schema);
} on FormatException catch (e) {
  print(e.message);
}
```

Pass `inputs:` if you registered your own types or sources, since validation
uses the same registry as the form.

It checks that the schema has a `fields` list of objects; that `key`, `type`,
`label` and `required` are well-formed; that the type is registered; that keys
are unique within a scope; that conditions are supported and read only fields
they are allowed to; that groups have fields and valid `output`, `minItems`,
`maxItems` and `addLabel`; and whatever each input checks for itself (integer
bounds, text line counts, a dropdown's options or source).

It loads no options and does not look at `initialValues`.

Typical messages:

```
Duplicate key: "email"
"details" is conditional on hasDetails, which must be declared earlier
No input registered for type: slider
Group "address" has no "fields"
"age" has min 50 greater than max 10
Unknown options source: planets
Dropdown "size" needs "options" or "optionsSource"
"output" of group "pets" must be "flat", "object" or "list": tree
```

## Extending

### Custom inputs

A field type is a subclass of `JsonFormFieldInput`. Register it by passing an
`inputs` list:

```dart
class RatingInput extends JsonFormFieldInput {
  const RatingInput();

  @override
  String get type => 'rating';

  /// Turns the raw value from the JSON into what the field starts with.
  @override
  Object? normalizeInitialValue(Object? raw) => raw is int ? raw : 0;

  /// Optional. Throw a FormatException for a bad spec.
  @override
  void validate(FieldSpec spec) {}

  @override
  Widget build(
    BuildContext context,
    FieldSpec spec, {
    required Object? initialValue,
    required void Function(dynamic value) onChanged,
    required void Function(dynamic value) onSaved,
  }) {
    return FormField<int>(
      initialValue: initialValue as int,
      onSaved: onSaved,
      builder: (state) => Row(
        children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              icon: Icon(i <= (state.value ?? 0) ? Icons.star : Icons.star_border),
              onPressed: () {
                state.didChange(i);
                onChanged(i);
              },
            ),
        ],
      ),
    );
  }
}

JsonForm(
  schema: schema,
  inputs: const [...JsonForm.defaultInputs, RatingInput()],
  onSubmit: save,
);
```

What an input must do:

- Call `onSaved` with the field's value when the form saves. That value goes
  into the output.
- Call `onChanged` whenever the user changes the value. If it never does, a
  condition that reads the field will not update.
- Use `initialValue`. It is the field's current value when it is shown again
  after being hidden, not only the prefill.

Passing `inputs` replaces the defaults, so include `JsonForm.defaultInputs` to
keep the built-in types. If two inputs share a type, the later one wins, which
lets you override a built-in.

### Options sources

A source supplies a dropdown's options from somewhere other than the schema:

```dart
class CountriesSource extends JsonFormOptionsSource {
  const CountriesSource();

  @override
  Future<List<JsonFormOption>> load(FieldSpec spec) async {
    final rows = await fetchCountries();
    return [for (final c in rows) JsonFormOption(value: c.code, label: c.name)];
  }
}

JsonForm(
  schema: schema,
  inputs: [
    ...JsonForm.defaultInputs,
    const JsonFormDropdownFieldInput(sources: {'countries': CountriesSource()}),
  ],
  onSubmit: save,
);
```

The schema refers to it as `"optionsSource": "countries"`. The configured
dropdown input comes after the default one, so it overrides it.

## Example app and sample schemas

`example/` is a Flutter app for trying things out:

```
cd example
flutter run -d chrome
```

- A **Preset** dropdown with a preset for each feature.
- **Custom JSON** opens an editor for your own schema. It is checked with
  `JsonForm.validateSchema` first, and errors appear in the dialog. A schema
  that passes is added to the presets for the session.
- **Save** keeps the current entries in memory without validating them.
  **Load saved** refills the form from them as a decoded object.
  **Load sample** refills from a JSON string. **Clear** empties the form.
- Tabs show the input JSON, the validated **Submitted** result, and the
  **Saved** data.

`example/samples/` holds ready-made schemas to paste into Custom JSON: 14 valid
ones, each showing a different feature, and 16 invalid ones that should be
rejected with a specific message. See
[`example/samples/README.md`](example/samples/README.md) for the full list.
Two samples use a `countries` source that only the example registers.

## Tests

```
flutter test                     # the package
cd example && flutter test       # the example app and the sample files
```

Shared helpers are in `test/helpers/form_test_helpers.dart`.

## Limits and things to know

- **The schema, `initialValues`, `inputs` and `controller` are read once.**
  Changing them on a live `JsonForm` does nothing. To load a different schema
  or different values, give the widget a new key: `JsonForm(key: ValueKey(id), ...)`.
- **A dropdown is an unreliable condition source.** Until the user changes it,
  its value for conditions is the raw prefill, even if that value is not among
  the loaded options and the field shows empty. Conditions on checkboxes and
  integers are exact.
- **Only `equals` exists** as a condition, and a condition reads one field.
- **List bounds are enforced by the buttons alone.** Nothing checks the entry
  count on submit, so a prefill can exceed `maxItems`.
- **A failed options load has no retry.**
- **Groups have almost no visuals.** Flat and object groups add none, and list
  groups show a title, cards and buttons. There is no styling, spacing or
  layout option, and the Submit button is fixed.
- **Integers are whole numbers only**, with no step.
- **Unknown schema properties are ignored** rather than reported.
- **Wrong-shaped prefill is ignored** rather than reported.

## Source layout

```
lib/
  json_form.dart                  the one file to import
  field_spec.dart                 FieldSpec, GroupOutput
  condition/                      JsonFormCondition, equals, parseCondition
  form/json_form.dart             JsonForm, JsonFormController, validateSchema
  form_type/                      the field inputs
    form_field.dart               JsonFormFieldInput, the base class
    text_field.dart  integer_field.dart  checkbox_field.dart  dropdown_field.dart
    options/                      JsonFormOption, JsonFormOptionsSource, inline source
example/                          the demo app, with samples/
test/
```

## License

Check the LICENSE file