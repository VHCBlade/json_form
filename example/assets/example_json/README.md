# Sample schemas

Each file is a complete schema for the example app.

**To try one:** run the example, press **Custom JSON**, replace the editor's
contents with the file's contents, give it a name, and press **Add preset**.

Two samples use `"optionsSource": "countries"`, which only exists because the
example registers a `countries` source. They will be rejected anywhere else.

## Valid samples

| File | What it shows |
| --- | --- |
| `01_contact_form.json` | Plain text fields, some required |
| `02_customer_survey.json` | Dropdown, integer with a range, checkbox |
| `03_newsletter_signup.json` | `equals: true` and `equals: false` on one checkbox |
| `04_pet_registration.json` | Groups, a condition inside a group, groups for both states of a checkbox |
| `05_order_form.json` | Integer clamped to 1-99, map-style dropdown options, gift message shown on a checkbox |
| `06_shipping_and_billing.json` | Two groups, the second shown only when billing differs, remote country source |
| `07_job_application.json` | A group shown by a checkbox, with a conditional field and integers inside it |
| `08_event_registration.json` | Integer clamped to 0-5, several checkbox-driven notes fields |
| `09_notification_settings.json` | A group shown by a master switch, with dependent fields inside |
| `10_bug_report.json` | Integer clamped to 1-100 shown when a checkbox is unticked |
| `11_kitchen_sink.json` | Every field type, a nested group, and conditions at every level |
| `12_support_ticket.json` | Text areas sized with `minLines` and `maxLines`, one shown by a checkbox |
| `13_household_registration.json` | An object group, and a list group of pets (add, remove, 1 to 5 entries) with a per-entry condition; `name` is used in both scopes |
| `14_order_line_items.json` | A list group of line items with integer clamping per entry, and a condition on a root checkbox read from inside each entry |

Things worth trying: untick a checkbox that controls a group and tick it again
(typed values come back); enter 200 in a field with `max: 99` and tab away (it
becomes 99); submit with a required field hidden (it does not block); use
**Save**, then **Load saved**.

A required checkbox must be ticked, which is why it is only used for
agreement fields.

## Invalid samples, for the dialog's checks

Each should be rejected, and the dialog should stay open with the message shown.

| File | Expected message |
| --- | --- |
| `invalid/not_json.json` | `Not valid JSON: ...` (trailing commas) |
| `invalid/no_fields_list.json` | `Schema needs a "fields" list` |
| `invalid/duplicate_keys.json` | `Duplicate key: "email"` |
| `invalid/condition_on_later_field.json` | `"details" is conditional on hasDetails, which must be declared earlier` |
| `invalid/unknown_field_type.json` | `No input registered for type: slider` |
| `invalid/empty_group.json` | `Group "address" has no "fields"` |
| `invalid/integer_min_above_max.json` | `"age" has min 50 greater than max 10` |
| `invalid/unknown_options_source.json` | `Unknown options source: planets` |
| `invalid/dropdown_without_options.json` | `Dropdown "size" needs "options" or "optionsSource"` |
| `invalid/missing_key.json` | `Field needs a string "key": ...` |
| `invalid/min_lines_above_max_lines.json` | `"notes" has minLines 5 greater than maxLines 3` |
| `invalid/lines_not_positive.json` | `"minLines" of "notes" must be a positive whole number: 0` |
| `invalid/label_wrong_type.json` | `"label" of "age" must be a string: 42` |
| `invalid/unknown_group_output.json` | `"output" of group "pets" must be "flat", "object" or "list": tree` |
| `invalid/min_items_above_max_items.json` | `Group "items" has minItems 5 greater than maxItems 2` |
| `invalid/condition_into_object_group.json` | `"paperwork" is conditional on petInsured, which must be declared earlier` (a condition cannot read into an object or list group) |
