package main

import rego.v1

dynamodb_kms_metadata := {
	"framework": "HIPAA Security Rule",
	"control_id": "164.312(a)(2)(iv)",
	"gap": "GAP-02",
	"severity": "high",
	"remediation": "Enable DynamoDB server-side encryption using the capstone customer-managed KMS key.",
}

dynamodb_encryption_enabled if {
	after := resource_after("aws_dynamodb_table.intake")

	some encryption in object.get(after, "server_side_encryption", [])
	object.get(encryption, "enabled", false) == true
}

dynamodb_kms_key_known if {
	after := resource_after("aws_dynamodb_table.intake")

	some encryption in object.get(after, "server_side_encryption", [])
	object.get(encryption, "kms_key_arn", "") != ""
}

dynamodb_kms_key_unknown_but_configured if {
	after_unknown := resource_after_unknown("aws_dynamodb_table.intake")

	some encryption in object.get(
		after_unknown,
		"server_side_encryption",
		[],
	)

	object.get(encryption, "kms_key_arn", false) == true
}

dynamodb_kms_compliant if {
	dynamodb_encryption_enabled
	dynamodb_kms_key_known
}

dynamodb_kms_compliant if {
	dynamodb_encryption_enabled
	dynamodb_kms_key_unknown_but_configured
}

dynamodb_kms_deny contains message if {
	not dynamodb_kms_compliant

	message := sprintf(
		"[%s %s][%s][severity=%s] DynamoDB intake table must use a customer-managed KMS key. Remediation: %s",
		[
			dynamodb_kms_metadata.framework,
			dynamodb_kms_metadata.control_id,
			dynamodb_kms_metadata.gap,
			dynamodb_kms_metadata.severity,
			dynamodb_kms_metadata.remediation,
		],
	)
}

deny contains message if {
	message := dynamodb_kms_deny[_]
}
