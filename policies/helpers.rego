package main

import rego.v1

# Return a non-deleted Terraform resource change by its exact address.
resource_change(address) := rc if {
	some rc in object.get(input, "resource_changes", [])
	rc.address == address

	actions := object.get(object.get(rc, "change", {}), "actions", [])
	not "delete" in actions
}

resource_after(address) := after if {
	rc := resource_change(address)
	after := object.get(object.get(rc, "change", {}), "after", {})
}

resource_after_unknown(address) := after_unknown if {
	rc := resource_change(address)

	after_unknown := object.get(
		object.get(rc, "change", {}),
		"after_unknown",
		{},
	)
}

# Decode a Terraform JSON-encoded IAM or S3 bucket policy.
json_policy(address) := policy if {
	after := resource_after(address)
	raw := object.get(after, "policy", "")

	is_string(raw)
	raw != ""

	policy := json.unmarshal(raw)
}

value_contains(value, expected) if {
	is_string(value)
	value == expected
}

value_contains(value, expected) if {
	is_array(value)
	expected in value
}

# Convert either a Terraform string or array value into a Rego set.
string_or_array_set(value) := result if {
	is_array(value)
	result := {item | some item in value}
}

string_or_array_set(value) := result if {
	is_string(value)
	result := {value}
}

statement_actions(statement) := actions if {
	raw := object.get(statement, "Action", [])
	actions := string_or_array_set(raw)
}

statement_resources(statement) := resources if {
	raw := object.get(statement, "Resource", [])
	resources := string_or_array_set(raw)
}
