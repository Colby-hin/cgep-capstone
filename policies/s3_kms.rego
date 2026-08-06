package main

import rego.v1

s3_kms_metadata := {
	"framework": "HIPAA Security Rule",
	"control_id": "164.312(a)(2)(iv)",
	"gap": "GAP-01",
	"severity": "high",
	"remediation": "Configure the uploads bucket for aws:kms encryption using the capstone customer-managed KMS key.",
}

s3_kms_algorithm_configured if {
	after := resource_after("aws_s3_bucket_server_side_encryption_configuration.uploads")

	some rule in object.get(after, "rule", [])
	some encryption_default in object.get(
		rule,
		"apply_server_side_encryption_by_default",
		[],
	)

	object.get(encryption_default, "sse_algorithm", "") == "aws:kms"
}

s3_kms_key_known if {
	after := resource_after("aws_s3_bucket_server_side_encryption_configuration.uploads")

	some rule in object.get(after, "rule", [])
	some encryption_default in object.get(
		rule,
		"apply_server_side_encryption_by_default",
		[],
	)

	object.get(encryption_default, "kms_master_key_id", "") != ""
}

s3_kms_key_unknown_but_configured if {
	after_unknown := resource_after_unknown("aws_s3_bucket_server_side_encryption_configuration.uploads")

	some rule in object.get(after_unknown, "rule", [])
	some encryption_default in object.get(
		rule,
		"apply_server_side_encryption_by_default",
		[],
	)

	object.get(encryption_default, "kms_master_key_id", false) == true
}

s3_kms_compliant if {
	s3_kms_algorithm_configured
	s3_kms_key_known
}

s3_kms_compliant if {
	s3_kms_algorithm_configured
	s3_kms_key_unknown_but_configured
}

s3_kms_deny contains message if {
	not s3_kms_compliant

	message := sprintf(
		"[%s %s][%s][severity=%s] Uploads bucket must use a customer-managed KMS key. Remediation: %s",
		[
			s3_kms_metadata.framework,
			s3_kms_metadata.control_id,
			s3_kms_metadata.gap,
			s3_kms_metadata.severity,
			s3_kms_metadata.remediation,
		],
	)
}

deny contains message if {
	message := s3_kms_deny[_]
}
